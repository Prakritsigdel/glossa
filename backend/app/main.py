from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select, func
from sqlalchemy.orm import Session, selectinload
import jwt

from app.config import settings
from app.database import SessionLocal
from app.models import Attempt, Exercise, Lesson, User
from app.schemas import AnswerIn, AttemptIn, AuthOut, Credentials, LeaderboardEntryOut, ProfileUpdate, Registration, UserOut
from app.security import create_token, hash_password, verify_password

app = FastAPI(title="Glossa API", version="1.0.0")
origins = [item.strip() for item in settings.cors_origins.split(",") if item.strip()]
app.add_middleware(CORSMiddleware, allow_origins=origins or ["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
bearer = HTTPBearer(auto_error=False)


def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer), db: Session = Depends(db_session)) -> User:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        payload = jwt.decode(credentials.credentials, settings.jwt_secret, algorithms=["HS256"])
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid or expired access token")
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="Account not found")
    return user


def xp_to_next(user: User) -> int:
    return user.level * 150 if user.level > 1 else 100


def current_streak(user: User) -> int:
    if user.last_activity_date is None:
        return 0
    today = datetime.now(timezone.utc).date()
    if user.last_activity_date < today - timedelta(days=1):
        return 0
    return user.streak


def user_output(user: User) -> UserOut:
    return UserOut(id=user.id, name=user.name, email=user.email, hero_index=user.hero_index,
                   hero_class_name=user.hero_class_name, language_id=user.language_id, xp=user.xp,
                   xp_to_next_level=xp_to_next(user), level=user.level, streak=current_streak(user),
                   words_found=user.words_found, lessons_completed=user.lessons_completed)


def auth_output(user: User) -> AuthOut:
    return AuthOut(access_token=create_token(user.id), user=user_output(user))


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/v1/auth/register", response_model=AuthOut, status_code=201)
def register(payload: Registration, db: Session = Depends(db_session)):
    if db.scalar(select(User).where(User.email == payload.email.lower())):
        raise HTTPException(status_code=409, detail="An account with this email already exists")
    user = User(name=payload.name.strip(), email=payload.email.lower(), password_hash=hash_password(payload.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return auth_output(user)


@app.post("/api/v1/auth/login", response_model=AuthOut)
def login(payload: Credentials, db: Session = Depends(db_session)):
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email or password is incorrect")
    return auth_output(user)


@app.get("/api/v1/me", response_model=UserOut)
def get_me(user: User = Depends(current_user)):
    return user_output(user)


@app.patch("/api/v1/me", response_model=UserOut)
def update_me(payload: ProfileUpdate, db: Session = Depends(db_session), user: User = Depends(current_user)):
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, key, value)
    db.commit()
    db.refresh(user)
    return user_output(user)


def lesson_statuses(db: Session, user: User) -> dict[str, str]:
    lessons = list(db.scalars(select(Lesson).order_by(Lesson.id)).all())
    cleared = set(db.scalars(select(Attempt.lesson_id).where(Attempt.user_id == user.id)).all())
    result = {}
    previous_cleared = True
    for lesson in lessons:
        if lesson.id in cleared:
            result[lesson.id] = "cleared"
            previous_cleared = True
        elif previous_cleared:
            result[lesson.id] = "current"
            previous_cleared = False
        else:
            result[lesson.id] = "locked"
            previous_cleared = False
    return result


@app.get("/api/v1/lessons")
def get_lessons(db: Session = Depends(db_session), user: User = Depends(current_user)):
    statuses = lesson_statuses(db, user)
    lessons = db.scalars(select(Lesson).order_by(Lesson.id)).all()
    return [{"id": l.id, "title": l.title, "subtitle": l.subtitle, "exercise_type": l.exercise_type,
             "status": statuses[l.id], "xp_reward": l.xp_reward, "word_count": l.word_count,
             "required_level": l.required_level} for l in lessons]


@app.get("/api/v1/lessons/{lesson_id}/exercises")
def get_exercises(lesson_id: str, db: Session = Depends(db_session), user: User = Depends(current_user)):
    lesson = db.scalar(select(Lesson).where(Lesson.id == lesson_id).options(selectinload(Lesson.exercises)))
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    return [{"id": e.id, "type": e.exercise_type, "instruction": e.instruction, "prompt": e.prompt,
             "prompt_hint": e.prompt_hint, "image_key": e.image_key, "options": e.options}
            for e in sorted(lesson.exercises, key=lambda x: x.id)]


@app.post("/api/v1/lessons/{lesson_id}/attempts")
def submit_attempt(lesson_id: str, payload: AttemptIn, db: Session = Depends(db_session), user: User = Depends(current_user)):
    user = db.scalar(
        select(User)
        .where(User.id == user.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    lesson = db.scalar(select(Lesson).where(Lesson.id == lesson_id).options(selectinload(Lesson.exercises)))
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    existing = db.scalar(select(Attempt).where(Attempt.user_id == user.id, Attempt.lesson_id == lesson_id))
    if existing:
        return {"completed": True, "already_completed": True, "correct_answers": existing.correct_answers,
                "total_questions": existing.total_questions, "xp_earned": existing.xp_earned, "user": user_output(user)}
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    exercises = {e.id: e for e in lesson.exercises}
    submitted = {answer.exercise_id: answer for answer in payload.answers}
    if len(submitted) != len(payload.answers) or set(submitted) != set(exercises):
        raise HTTPException(status_code=422, detail="Submit exactly one answer for every exercise")
    correct = 0
    for exercise_id, exercise in exercises.items():
        answer = submitted[exercise_id]
        if exercise.pairs is not None:
            is_correct = answer.selected_pairs == exercise.pairs
        else:
            is_correct = answer.selected_option_id == exercise.answer_id
        if not is_correct:
            raise HTTPException(status_code=422, detail="Lesson answers are incomplete or incorrect")
        correct += 1
    xp_earned = lesson.xp_reward
    user.xp += xp_earned
    user.words_found += lesson.word_count
    user.lessons_completed += 1
    today = datetime.now(timezone.utc).date()
    if user.last_activity_date != today:
        yesterday = today - timedelta(days=1)
        user.streak = user.streak + 1 if user.last_activity_date == yesterday else 1
        user.last_activity_date = today
    while user.xp >= xp_to_next(user):
        user.level += 1
    levels = [(2, "Traveler"), (4, "Speaker"), (6, "Guardian")]
    user.hero_class_name = "Master" if user.level >= 7 else next((title for limit, title in levels if user.level <= limit), "Master")
    total_questions = sum(len(e.pairs) if e.pairs is not None else 1 for e in exercises.values())
    correct_count = sum(len(submitted[e.id].selected_pairs or {}) if e.pairs is not None
                        else int(submitted[e.id].selected_option_id == e.answer_id) for e in exercises.values())
    attempt = Attempt(user_id=user.id, lesson_id=lesson_id, correct_answers=correct_count,
                      total_questions=total_questions, xp_earned=xp_earned)
    db.add(attempt)
    db.commit()
    db.refresh(user)
    return {"completed": True, "already_completed": False, "correct_answers": correct_count,
            "total_questions": total_questions, "xp_earned": xp_earned, "user": user_output(user)}


@app.post("/api/v1/lessons/{lesson_id}/answer")
def check_answer(lesson_id: str, answer: AnswerIn, db: Session = Depends(db_session), user: User = Depends(current_user)):
    exercise = db.get(Exercise, answer.exercise_id)
    if exercise is None or exercise.lesson_id != lesson_id:
        raise HTTPException(status_code=404, detail="Exercise not found")
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    if exercise.pairs is not None:
        correct = bool(answer.selected_pairs) and all(exercise.pairs.get(key) == value for key, value in answer.selected_pairs.items())
    else:
        correct = answer.selected_option_id == exercise.answer_id
    return {"correct": correct}


@app.get("/api/v1/leaderboard", response_model=list[LeaderboardEntryOut])
def get_leaderboard(filter: str = "weekly", db: Session = Depends(db_session), user: User = Depends(current_user)):
    if filter not in {"weekly", "family", "alltime"}:
        raise HTTPException(status_code=422, detail="filter must be weekly, family, or alltime")
    if filter == "weekly":
        from datetime import datetime, timedelta, timezone
        start = datetime.now(timezone.utc) - timedelta(days=7)
        scores = dict(db.execute(select(Attempt.user_id, func.sum(Attempt.xp_earned)).where(Attempt.completed_at >= start).group_by(Attempt.user_id)).all())
        rows = db.scalars(select(User).where(User.id.in_(scores.keys())).order_by(User.name)).all() if scores else []
        rows.sort(key=lambda row: (-scores[row.id], row.name))
        score_for = lambda row: scores[row.id]
    else:
        rows = db.scalars(select(User).order_by(User.xp.desc(), User.name)).all()
        score_for = lambda row: row.xp
    return [LeaderboardEntryOut(rank=index, name=row.name, level=row.level, class_name=row.hero_class_name,
                                xp=score_for(row), hero_index=row.hero_index, is_current_user=row.id == user.id)
            for index, row in enumerate(rows[:100], start=1)]
