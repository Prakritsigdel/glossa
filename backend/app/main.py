from datetime import datetime, timedelta, timezone
import hashlib
import json
import logging
import uuid
from contextlib import asynccontextmanager
from copy import deepcopy

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select, func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload
import jwt

from app.config import (
    content_environment,
    development_content_enabled,
    settings,
)
from app.database import SessionLocal
from app.curriculum_blueprint import (
    ACTIVE_EXERCISE_TYPES,
    CURRICULUM_VERSION,
    SUPPORTED_ILLUSTRATION_KEYS,
    active_lessons_query,
    load_curriculum,
)
from app.models import (
    Attempt,
    Course,
    Exercise,
    ExerciseSubmission,
    Language,
    Lesson,
    LessonCompletion,
    LessonProgress,
    LessonRun,
    Unit,
    User,
)
from app.schemas import (
    AnswerIn, AttemptIn, AuthOut, CourseOut, CourseUpdate, Credentials,
    ExerciseAnswerIn, ExerciseOptionOut, ExerciseOut, ExerciseResultOut, LessonAttemptIn,
    LessonAttemptOut, LanguageOut, LeaderboardEntryOut, LessonOut,
    ProfileUpdate, Registration, UnitOut, UserOut,
    LessonRunStateOut,
)
from app.progression import (
    compute_hero_stats,
    credited_xp,
    hero_class,
    level_state,
    lesson_passed,
)
from app.security import create_token, hash_password, verify_password

logger = logging.getLogger("glossa.api")

# Shown by /health while GLOSSA_CONTENT_ENVIRONMENT=development so nobody
# mistakes the provisional pilot curriculum for verified production content.
DEVELOPMENT_CONTENT_NOTICE = (
    "Development content environment: the English->Newari curriculum is "
    "structurally complete but provisional and NOT verified by native "
    "speakers. Vocabulary, sentences, dialogues and illustrations are "
    "unverified; production publication safeguards stay active."
)


@asynccontextmanager
async def _lifespan(app: FastAPI):
    if development_content_enabled():
        logger.warning(
            "GLOSSA_CONTENT_ENVIRONMENT=development: serving the provisional "
            "unverified curriculum from an isolated development database."
        )
    else:
        logger.info("Content environment: production (publication safeguards active)")
    yield


app = FastAPI(title="Glossa API", version="2.0.0", lifespan=_lifespan)
origins = [item.strip() for item in settings.cors_origins.split(",") if item.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
bearer = HTTPBearer(auto_error=False)


def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(db_session),
) -> User:
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
    return 100 + 25 * (max(user.level, 1) - 1)


def current_streak(user: User) -> int:
    if user.last_activity_date is None:
        return 0
    today = datetime.now(timezone.utc).date()
    if user.last_activity_date < today - timedelta(days=1):
        return 0
    return user.streak


# ════════════════════════════════════════════════════════════════════
# Publication-readiness checks (Stage 3)
# ════════════════════════════════════════════════════════════════════

def is_exercise_payload_valid(exercise: Exercise) -> bool:
    if exercise.exercise_type not in ACTIVE_EXERCISE_TYPES or not exercise.instruction.strip():
        return False
    options = exercise.options or []
    option_ids = [item.get("id") for item in options if isinstance(item, dict)]
    if len(option_ids) != len(options) or len(option_ids) != len(set(option_ids)):
        return False
    if exercise.exercise_type == "matchWords":
        pairs = (exercise.correct_answer_config or {}).get("pairs", {})
        return (
            len(pairs) >= 2
            and all(key in option_ids and value in option_ids for key, value in pairs.items())
            and all(
                item.get("romanization")
                for item in options
                if item.get("is_devanagari")
            )
        )
    if len(options) < 2:
        return False
    correct_id = (exercise.correct_answer_config or {}).get("correct_option_id")
    if correct_id not in option_ids:
        return False
    if exercise.exercise_type in ("pictureToWord", "wordToPicture"):
        image_keys = (
            [exercise.image_key]
            if exercise.exercise_type == "pictureToWord"
            else [item.get("image_key") for item in options]
        )
        if any(key not in SUPPORTED_ILLUSTRATION_KEYS for key in image_keys):
            return False
    return all(
        not item.get("is_devanagari") or bool(item.get("romanization"))
        for item in options
    )


def is_lesson_structurally_ready(db: Session, lesson: Lesson) -> bool:
    expected_count = (lesson.content_data or {}).get("exercise_count")
    exercises = sorted(lesson.exercises or [], key=lambda item: item.sequence or 0)
    return bool(
        expected_count
        and len(exercises) == expected_count
        and all(is_exercise_payload_valid(exercise) for exercise in exercises)
    )


def _exercise_requires_domain(exercise: Exercise, domain: str) -> bool:
    return domain == "illustration" and exercise.exercise_type in (
        "pictureToWord",
        "wordToPicture",
    )


def is_lesson_publication_ready(db: Session, lesson: Lesson) -> bool:
    if not lesson.is_published or not is_lesson_structurally_ready(db, lesson):
        return False
    if not lesson.vocabulary_verified:
        return False
    return not any(
        _exercise_requires_domain(exercise, "illustration")
        for exercise in lesson.exercises
    ) or lesson.illustration_verified


def _is_active_curriculum_lesson(db: Session, lesson: Lesson) -> bool:
    unit = db.get(Unit, lesson.unit_id) if lesson.unit_id else None
    return bool(
        unit
        and unit.course_id == "en_new"
        and unit.curriculum_version == CURRICULUM_VERSION
    )


def lesson_is_playable(db: Session, lesson: Lesson) -> bool:
    if not _is_active_curriculum_lesson(db, lesson):
        return False
    if development_content_enabled():
        return is_lesson_structurally_ready(db, lesson)
    return is_lesson_publication_ready(db, lesson)


def _lesson_not_playable_detail() -> str:
    if development_content_enabled():
        return "Lesson is not available in this development environment."
    return "Lesson is not published and awaiting verification."


def lesson_publication_status(db: Session, lesson: Lesson) -> dict:
    blockers = []
    if not lesson.is_published:
        blockers.append("not_explicitly_published")
    if not is_lesson_structurally_ready(db, lesson):
        blockers.append("curriculum_structure_incomplete")
    if not lesson.vocabulary_verified:
        blockers.append("vocabulary_not_verified")
    if any(_exercise_requires_domain(exercise, "illustration") for exercise in lesson.exercises):
        if not lesson.illustration_verified:
            blockers.append("illustration_not_verified")
    return {
        "lesson_id": lesson.id,
        "is_published": lesson.is_published,
        "publication_ready": is_lesson_publication_ready(db, lesson),
        "content_environment": content_environment(),
        "blockers": blockers,
    }


def _completed_lesson_ids(db: Session, user_id: int) -> list[str]:
    return list(
        db.scalars(
            select(LessonProgress.lesson_id)
            .join(Lesson, Lesson.id == LessonProgress.lesson_id)
            .join(Unit, Unit.id == Lesson.unit_id)
            .where(
                LessonProgress.user_id == user_id,
                LessonProgress.completed_at.is_not(None),
                Unit.curriculum_version == CURRICULUM_VERSION,
            )
        ).all()
    )


def _user_progress_output(db: Session, user: User) -> tuple[dict[str, int], int, int]:
    completed_ids = _completed_lesson_ids(db, user.id)
    lessons = {
        lesson.id: lesson.content_data or {}
        for lesson in db.scalars(
            select(Lesson).where(Lesson.id.in_(completed_ids))
        ).all()
    } if completed_ids else {}
    words = {
        word_id
        for content in lessons.values()
        for word_id in content.get("new_word_ids", [])
    }
    return compute_hero_stats(completed_ids), len(words), len(completed_ids)


def user_output(user: User, db: Session) -> UserOut:
    level, xp_in_level, xp_required = level_state(user.xp)
    hero_stats, words_found, lessons_completed = _user_progress_output(db, user)
    return UserOut(
        id=user.id,
        name=user.name,
        email=user.email,
        hero_index=user.hero_index,
        hero_class_name=hero_class(level),
        language_id=user.language_id,
        active_course_id=user.active_course_id,
        xp=user.xp,
        xp_in_level=xp_in_level,
        xp_to_next_level=xp_required,
        level=level,
        streak=current_streak(user),
        words_found=words_found,
        lessons_completed=lessons_completed,
        hero_stats=hero_stats,
    )


def auth_output(user: User, db: Session) -> AuthOut:
    return AuthOut(access_token=create_token(user.id), user=user_output(user, db))


def _resolve_course_id(course_id: str | None, user: User) -> str:
    """Resolve which course to use: explicit param or user's active course.

    Glossa is English->Newari only; en_new is the single active course.
    """
    if course_id is not None:
        return course_id
    if user.active_course_id is not None:
        return user.active_course_id
    return "en_new"


def lesson_statuses(db: Session, user: User, course_id: str | None = None) -> dict[str, str]:
    """Return availability for each lesson in the active JSON curriculum."""
    cid = _resolve_course_id(course_id, user)
    if cid != "en_new":
        return {}
    lessons = list(db.scalars(active_lessons_query()).all())
    return {
        lesson.id: _lesson_availability(db, user, lesson, lessons)
        for lesson in lessons
    }
# ─── Health ────────────────────────────────────────────────────


@app.get("/health")
def health():
    environment = content_environment()
    payload = {
        "status": "ok",
        "content_environment": environment,
        "provisional_content": environment == "development",
    }
    if environment == "development":
        payload["notice"] = DEVELOPMENT_CONTENT_NOTICE
    return payload


# ─── Auth ──────────────────────────────────────────────────────


@app.post("/api/v1/auth/register", response_model=AuthOut, status_code=201)
def register(payload: Registration, db: Session = Depends(db_session)):
    if db.scalar(select(User).where(User.email == payload.email.lower())):
        raise HTTPException(status_code=409, detail="An account with this email already exists")
    # Glossa is English->Newari only; new users are assigned en_new.
    en_new_course = db.scalar(select(Course).where(Course.id == "en_new"))
    user = User(
        name=payload.name.strip(),
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        active_course_id="en_new" if en_new_course is not None else None,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="An account with this email already exists")
    db.refresh(user)
    return auth_output(user, db)


@app.post("/api/v1/auth/login", response_model=AuthOut)
def login(payload: Credentials, db: Session = Depends(db_session)):
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email or password is incorrect")
    return auth_output(user, db)


# ─── User profile ──────────────────────────────────────────────


@app.get("/api/v1/me", response_model=UserOut)
def get_me(user: User = Depends(current_user), db: Session = Depends(db_session)):
    return user_output(user, db)


@app.patch("/api/v1/me", response_model=UserOut)
def update_me(
    payload: ProfileUpdate,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, key, value)
    db.commit()
    db.refresh(user)
    return user_output(user, db)


@app.put("/api/v1/users/me/active-course", response_model=UserOut)
def update_active_course(
    payload: CourseUpdate,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    # Glossa is English->Newari only; en_new is the single active course.
    if payload.active_course_id != "en_new":
        raise HTTPException(status_code=403, detail="Only English->Newari is available")
    course = db.get(Course, payload.active_course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if not course.is_published:
        raise HTTPException(status_code=403, detail="Course is not available yet")
    if not course.is_active:
        raise HTTPException(status_code=403, detail="Course is not active")
    user.active_course_id = course.id
    db.commit()
    db.refresh(user)
    return user_output(user, db)


# ─── Languages ─────────────────────────────────────────────────


@app.get("/api/v1/languages", response_model=list[LanguageOut])
def get_languages(db: Session = Depends(db_session), user: User = Depends(current_user)):
    return list(db.scalars(select(Language).where(Language.is_active == True)).all())


# ─── Courses ───────────────────────────────────────────────────


@app.get("/api/v1/courses", response_model=list[CourseOut])
def get_courses(
    published_only: bool = Query(True),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    query = select(Course).options(
        selectinload(Course.source_language),
        selectinload(Course.target_language),
    )
    # Glossa is English->Newari only; only active courses are visible.
    query = query.where(Course.is_active == True)
    if published_only:
        # Keep the user's active course metadata available even while its
        # lessons are unpublished and awaiting content verification.
        query = query.where(
            or_(Course.is_published == True, Course.id == user.active_course_id)
        )
    return list(db.scalars(query).all())


# ─── Units ─────────────────────────────────────────────────────


@app.get("/api/v1/courses/{course_id}/units", response_model=list[UnitOut])
def get_units_for_course(
    course_id: str,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    if course_id != "en_new":
        raise HTTPException(status_code=403, detail="Only English->Newari is available")
    course = db.get(Course, course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")

    units = list(
        db.scalars(
            select(Unit)
            .where(
                Unit.course_id == course_id,
                Unit.curriculum_version == CURRICULUM_VERSION,
            )
            .order_by(Unit.sequence)
        ).all()
    )
    completed_ids = set(_completed_lesson_ids(db, user.id))

    result = []
    for unit in units:
        planned_ids = set(
            db.scalars(select(Lesson.id).where(Lesson.unit_id == unit.id)).all()
        )
        total_lessons = len(planned_ids)
        cleared_lessons = len(planned_ids & completed_ids)
        result.append(
            UnitOut(
                id=unit.id,
                course_id=unit.course_id,
                sequence=unit.sequence,
                title=unit.title,
                description=unit.description,
                total_lessons=total_lessons,
                cleared_lessons=cleared_lessons,
            )
        )
    return result


# ─── Lessons ──────────────────────────────────────────────────


@app.get("/api/v1/lessons")
def get_lessons(
    course_id: str | None = Query(None),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    # Glossa is English->Newari only; reject requests for retired courses.
    if course_id is not None and course_id != "en_new":
        raise HTTPException(status_code=403, detail="Only English->Newari is available")
    cid = _resolve_course_id(course_id, user)
    statuses = lesson_statuses(db, user, cid)
    lessons = list(db.scalars(active_lessons_query()).all()) if cid == "en_new" else []

    return [
        {
            "id": l.id,
            "unit_id": l.unit_id,
            "sequence": l.sequence,
            "title": l.title,
            "subtitle": l.subtitle,
            "exercise_type": l.exercise_type,
            "status": statuses.get(l.id, "unavailable"),
            "xp_reward": l.xp_reward,
            "word_count": l.word_count,
            "required_level": l.required_level,
            "is_published": l.is_published,
            "is_checkpoint": l.is_checkpoint,
            "is_capstone": bool(
                (l.content_data or {}).get("number")
                == len(load_curriculum()["lessons"])
            ),
            "passing_score": l.passing_score,
            "availability": _lesson_availability(db, user, l, lessons),
            "planned_exercise_count": (l.content_data or {}).get("exercise_count", 0),
            "populated_exercise_count": len(l.exercises) if l.exercises else 0,
            "content_environment": content_environment(),
            "provisional": not is_lesson_publication_ready(db, l),
        }
        for l in lessons
    ]


@app.get("/api/v1/courses/{course_id}/town-map")
def get_town_map(
    course_id: str,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    # Glossa is English->Newari only; reject requests for retired courses.
    if course_id != "en_new":
        raise HTTPException(status_code=403, detail="Only English->Newari is available")
    return _get_town_map(db, user, course_id)


@app.get("/api/v1/courses/{course_id}/progress")
def get_course_progress(
    course_id: str,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    if course_id != "en_new":
        raise HTTPException(status_code=403, detail="Only English->Newari is available")
    lesson_ids = set(
        db.scalars(select(Lesson.id).join(Unit).where(Unit.curriculum_version == CURRICULUM_VERSION)).all()
    )
    completed_ids = set(_completed_lesson_ids(db, user.id))
    completed = len(completed_ids)
    return {
        "course_id": course_id,
        "completed_lessons": completed,
        "total_lessons": len(lesson_ids),
        "is_complete": completed == len(lesson_ids),
    }


@app.get("/api/v1/lessons/{lesson_id}/exercises", response_model=list[ExerciseOut])
def get_exercises(
    lesson_id: str,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    lesson = db.scalar(
        select(Lesson).where(Lesson.id == lesson_id).options(selectinload(Lesson.exercises))
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    if not _is_active_curriculum_lesson(db, lesson):
        raise HTTPException(status_code=403, detail="Lesson is not available")
    availability = lesson_statuses(db, user).get(lesson_id)
    if availability == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    # Publication-readiness: unreviewed lessons remain unpublished and
    # their exercises are not served to learners. The development content
    # environment additionally serves structurally complete provisional
    # lessons from an isolated database.
    if availability == "unavailable" or not lesson_is_playable(db, lesson):
        raise HTTPException(
            status_code=403,
            detail=_lesson_not_playable_detail(),
        )
    exercises = []
    for e in sorted(lesson.exercises, key=lambda x: (x.sequence or 0, x.id)):
        # Build public option list (no correct-answer exposure)
        public_options = None
        if e.options:
            public_options = [
                ExerciseOptionOut(
                    id=opt["id"],
                    text=opt["text"],
                    is_devanagari=opt.get("is_devanagari", False),
                    image_key=opt.get("image_key"),
                    speaker=opt.get("speaker"),
                    romanization=opt.get("romanization"),
                )
                for opt in e.options
                if isinstance(opt, dict)
            ]
        public_word_tiles = None
        if e.word_tiles:
            public_word_tiles = [
                ExerciseOptionOut(
                    id=tile["id"],
                    text=tile["text"],
                    is_devanagari=tile.get("is_devanagari", False),
                    romanization=tile.get("romanization"),
                )
                for tile in e.word_tiles
                if isinstance(tile, dict)
            ]
        exercises.append(
            ExerciseOut(
                id=e.id,
                lesson_id=e.lesson_id,
                exercise_type=e.exercise_type,
                sequence=e.sequence,
                xp=e.xp,
                instruction=e.instruction,
                prompt=e.prompt,
                prompt_hint=e.prompt_hint,
                image_key=e.image_key,
                audio_key=e.audio_key,
                newari_script=(
                    e.newari_script
                    if e.exercise_type == "wordToPicture"
                    else None
                ),
                romanization=(
                    e.romanization
                    if e.exercise_type == "wordToPicture"
                    else None
                ),
                illustration_id=e.illustration_id,
                vocabulary_reference=None,
                options=public_options,
                word_tiles=public_word_tiles,
                dialogue_structure=e.dialogue_structure,
                layout=deepcopy((e.content_data or {}).get("layout")),
                variant=(e.content_data or {}).get("variant"),
                planned_type=(e.content_data or {}).get("planned_type"),
                phrase_target_en=(e.content_data or {}).get("phrase_target_en"),
            )
        )
    return exercises


def _review_state(submission: ExerciseSubmission) -> dict:
    value = (submission.result_payload or {}).get("_review_state", {})
    return value if isinstance(value, dict) else {}


def _lesson_run_state(
    db: Session,
    lesson: Lesson,
    run_id: str,
    user_id: int,
    *,
    resumed: bool,
) -> LessonRunStateOut:
    exercises = sorted(lesson.exercises, key=lambda exercise: exercise.sequence or 0)
    submissions = list(
        db.scalars(
            select(ExerciseSubmission).where(
                ExerciseSubmission.user_id == user_id,
                ExerciseSubmission.lesson_id == lesson.id,
                ExerciseSubmission.run_id == run_id,
            )
        ).all()
    )
    by_id = {submission.exercise_id: submission for submission in submissions}
    answered_ids = [
        exercise.id
        for exercise in exercises
        if (submission := by_id.get(exercise.id)) is not None
        and submission.is_final
    ]
    original_results = {
        exercise.id: submission.correct is True
        for exercise in exercises
        if (submission := by_id.get(exercise.id)) is not None
        and submission.is_final
    }
    review_queue = [
        exercise.id
        for exercise in exercises
        if (submission := by_id.get(exercise.id)) is not None
        and exercise.exercise_type != "matchWords"
        and submission.is_final
        and submission.correct is False
        and not _review_state(submission).get("corrected", False)
    ]
    corrected_ids = [
        exercise.id
        for exercise in exercises
        if (submission := by_id.get(exercise.id)) is not None
        and _review_state(submission).get("corrected", False)
    ]
    matched_pairs = {
        exercise.id: submission.matched_pairs
        for exercise in exercises
        if exercise.exercise_type == "matchWords"
        and (submission := by_id.get(exercise.id)) is not None
        and submission.matched_pairs
    }
    return LessonRunStateOut(
        run_id=run_id,
        answered_exercise_ids=answered_ids,
        original_results=original_results,
        review_queue=review_queue,
        corrected_exercise_ids=corrected_ids,
        matched_pairs_by_exercise=matched_pairs,
        needs_completion=(
            resumed
            and len(answered_ids) == len(exercises)
            and not review_queue
        ),
    )


def _require_owned_run(
    db: Session,
    user: User,
    lesson_id: str,
    run_id: str,
) -> LessonRun:
    run = db.get(LessonRun, run_id)
    if run is None or run.user_id != user.id or run.lesson_id != lesson_id:
        raise HTTPException(status_code=404, detail="Lesson run not found")
    return run


@app.post(
    "/api/v1/lessons/{lesson_id}/start",
    response_model=LessonRunStateOut,
)
def start_lesson_run(
    lesson_id: str,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    user = db.scalar(
        select(User)
        .where(User.id == user.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    lesson = db.scalar(
        select(Lesson)
        .where(Lesson.id == lesson_id)
        .options(selectinload(Lesson.exercises), selectinload(Lesson.unit))
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    if not _is_active_curriculum_lesson(db, lesson):
        raise HTTPException(status_code=403, detail="Lesson is not available")
    availability = lesson_statuses(db, user).get(lesson_id)
    if availability == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    if availability == "unavailable" or not lesson_is_playable(db, lesson):
        raise HTTPException(status_code=403, detail=_lesson_not_playable_detail())

    completed_runs = set(
        db.scalars(
            select(Attempt.idempotency_key).where(
                Attempt.user_id == user.id,
                Attempt.lesson_id == lesson_id,
                Attempt.idempotency_key.is_not(None),
            )
        ).all()
    )
    active_runs = list(
        db.scalars(
            select(LessonRun)
            .where(
                LessonRun.user_id == user.id,
                LessonRun.lesson_id == lesson_id,
            )
            .order_by(LessonRun.started_at.desc())
        ).all()
    )
    active_run = next(
        (run for run in active_runs if run.run_id not in completed_runs),
        None,
    )
    resumed = active_run is not None
    if active_run is None:
        active_run = LessonRun(
            run_id=uuid.uuid4().hex,
            user_id=user.id,
            lesson_id=lesson_id,
        )
        db.add(active_run)
        db.commit()
        db.refresh(active_run)
    run_id = active_run.run_id

    return _lesson_run_state(
        db, lesson, run_id, user.id, resumed=resumed
    )


@app.get("/api/v1/lessons/{lesson_id}/runs/{run_id}/review-queue")
def get_review_queue(
    lesson_id: str,
    run_id: str,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    lesson = db.scalar(
        select(Lesson)
        .where(Lesson.id == lesson_id)
        .options(selectinload(Lesson.exercises), selectinload(Lesson.unit))
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    if not _is_active_curriculum_lesson(db, lesson):
        raise HTTPException(status_code=403, detail="Lesson is not available")
    _require_owned_run(db, user, lesson_id, run_id)
    availability = lesson_statuses(db, user).get(lesson_id)
    if availability == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    if availability == "unavailable" or not lesson_is_playable(db, lesson):
        raise HTTPException(status_code=403, detail=_lesson_not_playable_detail())

    state = _lesson_run_state(db, lesson, run_id, user.id, resumed=True)
    return {
        "review_queue": state.review_queue,
        "corrected_exercise_ids": state.corrected_exercise_ids,
    }


@app.post("/api/v1/lessons/{lesson_id}/attempts", response_model=LessonAttemptOut)
def submit_attempt(
    lesson_id: str,
    payload: LessonAttemptIn,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    """Finalize a run after the server has recorded one answer per exercise."""
    user = db.scalar(
        select(User)
        .where(User.id == user.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    lesson = db.scalar(
        select(Lesson)
        .where(Lesson.id == lesson_id)
        .options(selectinload(Lesson.exercises), selectinload(Lesson.unit))
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    if not _is_active_curriculum_lesson(db, lesson):
        raise HTTPException(status_code=403, detail="Lesson is not available")
    _require_owned_run(db, user, lesson_id, payload.run_id)
    status_value = lesson_statuses(db, user).get(lesson_id)
    if status_value == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    if status_value == "unavailable" or not lesson_is_playable(db, lesson):
        raise HTTPException(
            status_code=403,
            detail=_lesson_not_playable_detail(),
        )

    exercises = sorted(lesson.exercises, key=lambda exercise: exercise.sequence or 0)
    if not exercises:
        raise HTTPException(status_code=422, detail="Lesson has no exercises")
    existing = db.scalar(
        select(Attempt).where(
            Attempt.user_id == user.id,
            Attempt.idempotency_key == payload.run_id,
        )
    )
    if existing is not None:
        if existing.lesson_id != lesson_id or not existing.result_payload:
            raise HTTPException(status_code=409, detail="Run id was already used")
        return LessonAttemptOut.model_validate(existing.result_payload)

    submissions = list(
        db.scalars(
            select(ExerciseSubmission).where(
                ExerciseSubmission.user_id == user.id,
                ExerciseSubmission.lesson_id == lesson_id,
                ExerciseSubmission.run_id == payload.run_id,
                ExerciseSubmission.is_final == True,  # noqa: E712
            )
        ).all()
    )
    submission_by_id = {submission.exercise_id: submission for submission in submissions}
    expected_ids = {exercise.id for exercise in exercises}
    if set(submission_by_id) != expected_ids:
        raise HTTPException(
            status_code=409,
            detail="Every exercise must be finalized before the lesson can be completed",
        )

    review_queue = [
        exercise.id
        for exercise in exercises
        if exercise.exercise_type != "matchWords"
        and submission_by_id[exercise.id].correct is False
        and not _review_state(submission_by_id[exercise.id]).get(
            "corrected", False
        )
    ]
    if review_queue:
        raise HTTPException(
            status_code=409,
            detail={
                "message": "Complete mistake review before finishing the lesson",
                "review_queue": review_queue,
            },
        )

    total_questions = len(exercises)
    correct_count = sum(submission.correct is True for submission in submissions)
    earned = sum(
        exercise.xp
        for exercise in exercises
        if submission_by_id[exercise.id].correct is True
    )
    lesson_data = lesson.content_data or {}
    passed = lesson_passed(lesson_data, correct_count, total_questions)
    progress = db.scalar(
        select(LessonProgress)
        .where(
            LessonProgress.user_id == user.id,
            LessonProgress.lesson_id == lesson_id,
        )
        .with_for_update()
    )
    if progress is None:
        progress = LessonProgress(user_id=user.id, lesson_id=lesson_id)
        db.add(progress)
        db.flush()
    completed_before = progress.completed_at is not None
    previous_best = progress.best_earned_xp
    credit = credited_xp(earned, previous_best, completed_before=completed_before)
    old_level = level_state(user.xp)[0]
    progress.attempt_count += 1
    progress.best_earned_xp = max(progress.best_earned_xp, earned)
    progress.best_correct_answers = max(progress.best_correct_answers, correct_count)
    newly_completed = passed and not completed_before
    if newly_completed:
        progress.completed_at = datetime.now(timezone.utc)
    user.xp += credit
    if user.last_activity_date != datetime.now(timezone.utc).date():
        today = datetime.now(timezone.utc).date()
        yesterday = today - timedelta(days=1)
        user.streak = user.streak + 1 if user.last_activity_date == yesterday else 1
        user.last_activity_date = today
    new_level, _, _ = level_state(user.xp)
    user.level = new_level
    user.hero_class_name = hero_class(new_level)

    if newly_completed:
        db.add(
            LessonCompletion(
                user_id=user.id,
                lesson_id=lesson_id,
                score=correct_count / total_questions,
                passed=True,
                xp_earned=credit,
                correct_answers=correct_count,
                total_questions=total_questions,
            )
        )

    exercise_results = []
    missed_ids = set()
    mistakes_corrected = 0
    mastered_exercises = 0
    for exercise in exercises:
        submission = submission_by_id[exercise.id]
        review_state = _review_state(submission)
        review_corrected = bool(review_state.get("corrected", False))
        review_attempts = int(review_state.get("attempts", 0))
        mastered = submission.correct is True or review_corrected
        mistakes_corrected += int(review_corrected)
        mastered_exercises += int(mastered)
        missed_ids.update(submission.missed_word_ids or [])
        exercise_results.append(
            ExerciseResultOut(
                exercise_id=exercise.id,
                exercise_type=exercise.exercise_type,
                correct=bool(submission.correct),
                correct_answer=(
                    _correct_answer(exercise)
                    if submission.correct is False
                    and exercise.exercise_type != "matchWords"
                    else None
                ),
                xp=exercise.xp,
                mistake_count=(submission.result_payload or {}).get(
                    "mistake_count", 0
                ),
                review_corrected=review_corrected,
                review_attempts=review_attempts,
                mastered=mastered,
            )
        )
    word_map = {word["id"]: word for word in load_curriculum()["words"]}
    missed_vocabulary = [
        {
            "id": word_id,
            "newari": word_map[word_id]["newari"],
            "romanization": word_map[word_id]["roman"],
            "english": word_map[word_id]["english"],
        }
        for word_id in sorted(missed_ids)
        if word_id in word_map
    ]
    stat_gains = dict(lesson_data.get("stat_gains", {})) if newly_completed else {}
    total_lesson_ids = _completed_lesson_ids(db, user.id)
    if newly_completed:
        total_lesson_ids.append(lesson_id)
    hero_stats = compute_hero_stats(total_lesson_ids)
    response = LessonAttemptOut(
        lesson_id=lesson_id,
        attempt_number=progress.attempt_count,
        is_correct=correct_count == total_questions,
        correct_answers=correct_count,
        total_questions=total_questions,
        mistakes_corrected=mistakes_corrected,
        mastered_exercises=mastered_exercises,
        xp_earned=credit,
        earned_xp=earned,
        xp_max=lesson.xp_reward,
        credited_xp=credit,
        score=correct_count / total_questions,
        passing_threshold=round(
            float(lesson_data.get("pass_threshold") or 0) * 100
        ),
        passed=passed,
        results=exercise_results,
        already_completed=completed_before,
        completed=completed_before or passed,
        missed_vocabulary=missed_vocabulary,
        stat_gains=stat_gains,
        hero_stats=hero_stats,
        old_level=old_level,
        new_level=new_level,
        level_up=new_level > old_level,
    )
    submission_hash = hashlib.sha256(
        json.dumps(
            {
                exercise_id: submission_by_id[exercise_id].selected_answer
                for exercise_id in sorted(submission_by_id)
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()
    db.add(
        Attempt(
            user_id=user.id,
            lesson_id=lesson_id,
            attempt_number=progress.attempt_count,
            idempotency_key=payload.run_id,
            submission_hash=submission_hash,
            is_correct=correct_count == total_questions,
            passing_threshold=response.passing_threshold,
            correct_answers=correct_count,
            total_questions=total_questions,
            xp_earned=credit,
            earned_xp=earned,
            result_payload=response.model_dump(),
        )
    )
    db.commit()
    return response


@app.post("/api/v1/lessons/{lesson_id}/answer")
def check_answer(
    lesson_id: str,
    answer: AnswerIn,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    """Validate an original answer, review answer, or one matching pair."""
    user = db.scalar(
        select(User)
        .where(User.id == user.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    exercise = db.get(Exercise, answer.exercise_id)
    if exercise is None or exercise.lesson_id != lesson_id:
        raise HTTPException(status_code=404, detail="Exercise not found")
    lesson = db.scalar(
        select(Lesson)
        .where(Lesson.id == lesson_id)
        .options(selectinload(Lesson.exercises), selectinload(Lesson.unit))
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    if not _is_active_curriculum_lesson(db, lesson):
        raise HTTPException(status_code=403, detail="Lesson is not available")
    availability = lesson_statuses(db, user).get(lesson_id)
    if availability == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    if availability == "unavailable" or not lesson_is_playable(db, lesson):
        raise HTTPException(
            status_code=403,
            detail=_lesson_not_playable_detail(),
        )
    if answer.run_id != answer.run_id.strip():
        raise HTTPException(status_code=422, detail="Invalid run id")

    run = db.get(LessonRun, answer.run_id)
    if run is not None:
        _require_owned_run(db, user, lesson_id, answer.run_id)
    else:
        run = LessonRun(
            run_id=answer.run_id,
            user_id=user.id,
            lesson_id=lesson_id,
        )
        db.add(run)
        try:
            db.flush()
        except IntegrityError:
            db.rollback()
            _require_owned_run(db, user, lesson_id, answer.run_id)

    completed_run = db.scalar(
        select(Attempt.id).where(
            Attempt.user_id == user.id,
            Attempt.idempotency_key == answer.run_id,
        )
    )
    if completed_run is not None:
        raise HTTPException(status_code=409, detail="Lesson run is already complete")

    existing = db.scalar(
        select(ExerciseSubmission)
        .where(
            ExerciseSubmission.user_id == user.id,
            ExerciseSubmission.lesson_id == lesson_id,
            ExerciseSubmission.run_id == answer.run_id,
            ExerciseSubmission.exercise_id == exercise.id,
        )
        .with_for_update()
    )
    if answer.phase == "review" and existing is None:
        raise HTTPException(
            status_code=409,
            detail="This exercise has no original answer to review",
        )
    selected = answer.model_dump(
        exclude_none=True,
        exclude={"run_id", "exercise_id", "submission_id", "phase"},
    )
    request_answer = {"phase": answer.phase, **selected}
    request_history = {}
    if existing is not None:
        stored_answer = existing.selected_answer or {}
        if isinstance(stored_answer, dict):
            stored_history = stored_answer.get("_submission_requests", {})
            if isinstance(stored_history, dict):
                request_history = dict(stored_history)
        if answer.submission_id and answer.submission_id in request_history:
            previous = request_history[answer.submission_id]
            if previous.get("answer") != request_answer:
                raise HTTPException(
                    status_code=409,
                    detail="Submission id was already used for a different answer",
                )
            return previous["response"]
        if answer.phase == "review":
            if answer.submission_id is None:
                raise HTTPException(
                    status_code=422,
                    detail="A review submission id is required",
                )
            if exercise.exercise_type == "matchWords":
                raise HTTPException(
                    status_code=409,
                    detail="Matching exercises are corrected during the original lesson",
                )
            if not existing.is_final or existing.correct is not False:
                raise HTTPException(
                    status_code=409,
                    detail="Only an originally incorrect exercise can be reviewed",
                )
            review_state = _review_state(existing)
            if review_state.get("corrected", False):
                raise HTTPException(
                    status_code=409,
                    detail="This exercise has already been corrected",
                )
            if (
                answer.selected_option_id is None
                or answer.selected_pairs is not None
                or answer.selected_tile_ids is not None
            ):
                raise HTTPException(
                    status_code=422,
                    detail="Select exactly one review answer",
                )
            option_ids = {option["id"] for option in (exercise.options or [])}
            if answer.selected_option_id not in option_ids:
                raise HTTPException(status_code=422, detail="Unknown answer option")

            is_correct = answer.selected_option_id == exercise.answer_id
            review_attempts = int(review_state.get("attempts", 0)) + 1
            review_state = {
                **review_state,
                "attempts": review_attempts,
                "corrected": is_correct,
            }
            response = {
                "correct": is_correct,
                "is_final": True,
                "phase": "review",
                "review_complete": is_correct,
                "review_attempt": review_attempts,
                "matched_pairs": {},
                "xp_earned": 0,
                "correct_answer": (
                    _correct_answer(exercise) if not is_correct else None
                ),
                "correct_option_id": (
                    exercise.answer_id if not is_correct else None
                ),
                "missed_word_ids": existing.missed_word_ids or [],
                "mistake_count": 0,
            }
            request_history[answer.submission_id] = {
                "answer": request_answer,
                "response": response,
            }
            existing.selected_answer = {
                "_answer": selected,
                "_submission_requests": request_history,
            }
            existing.result_payload = {
                **(existing.result_payload or {}),
                "_review_state": review_state,
            }
            try:
                db.commit()
            except IntegrityError:
                db.rollback()
                saved = db.scalar(
                    select(ExerciseSubmission).where(
                        ExerciseSubmission.user_id == user.id,
                        ExerciseSubmission.lesson_id == lesson_id,
                        ExerciseSubmission.run_id == answer.run_id,
                        ExerciseSubmission.exercise_id == exercise.id,
                    )
                )
                saved_requests = (
                    (saved.selected_answer or {}).get("_submission_requests", {})
                    if saved and isinstance(saved.selected_answer, dict)
                    else {}
                )
                saved_request = saved_requests.get(answer.submission_id)
                if saved_request and saved_request.get("answer") == request_answer:
                    return saved_request["response"]
                raise HTTPException(
                    status_code=409,
                    detail="This review answer was already submitted",
                )
            return response
        if existing.is_final:
            raise HTTPException(status_code=409, detail="This exercise was already answered")
        if not answer.submission_id and (
            stored_answer.get("_answer") == selected or stored_answer == selected
        ):
            return existing.result_payload
        if exercise.exercise_type != "matchWords":
            raise HTTPException(status_code=409, detail="This exercise was already answered")
    if exercise.exercise_type == "matchWords":
        if answer.selected_pairs is None or len(answer.selected_pairs) != 1:
            raise HTTPException(status_code=422, detail="Select exactly one pair")
        dev_id, eng_id = next(iter(answer.selected_pairs.items()))
        correct_pairs = (exercise.correct_answer_config or {}).get("pairs", {})
        if dev_id not in correct_pairs or eng_id not in set(correct_pairs.values()):
            raise HTTPException(status_code=422, detail="Unknown matching option")
        prior_pairs = {}
        if existing is not None:
            prior_pairs = existing.matched_pairs
        if dev_id in prior_pairs or eng_id in prior_pairs.values():
            raise HTTPException(status_code=422, detail="A matched word cannot be reused")
        is_correct = correct_pairs[dev_id] == eng_id
        matched_pairs = dict(prior_pairs)
        if is_correct:
            matched_pairs[dev_id] = eng_id
        previous_mistakes = (
            (existing.result_payload or {}).get("mistake_count", 0)
            if existing is not None
            else 0
        )
        mistake_count = previous_mistakes + (0 if is_correct else 1)
        finalized = len(matched_pairs) == len(correct_pairs)
        previous_missed = list(existing.missed_word_ids or []) if existing else []
        missed_ids = list(dict.fromkeys(
            previous_missed
            + (
                [
                    (exercise.correct_answer_config or {})
                    .get("word_ids_by_devanagari", {})
                    .get(dev_id)
                ]
                if not is_correct
                else []
            )
        ))
        missed_ids = [item for item in missed_ids if item]
        response = {
            "correct": finalized and mistake_count == 0,
            "pair_correct": is_correct,
            "is_final": finalized,
            "matched_pairs": matched_pairs,
            "xp_earned": exercise.xp if finalized and mistake_count == 0 else 0,
            "correct_answer": None,
            "missed_word_ids": missed_ids,
            "mistake_count": mistake_count,
        }
    else:
        if answer.selected_option_id is None or answer.selected_pairs is not None:
            raise HTTPException(status_code=422, detail="Select exactly one answer")
        option_ids = {option["id"] for option in (exercise.options or [])}
        if answer.selected_option_id not in option_ids:
            raise HTTPException(status_code=422, detail="Unknown answer option")
        is_correct = answer.selected_option_id == exercise.answer_id
        target_word_id = (exercise.content_data or {}).get("target_word_id")
        missed_ids = [] if is_correct or not target_word_id else [target_word_id]
        response = {
            "correct": is_correct,
            "pair_correct": None,
            "is_final": True,
            "matched_pairs": {},
            "xp_earned": exercise.xp if is_correct else 0,
            "correct_answer": _correct_answer(exercise) if not is_correct else None,
            "correct_option_id": exercise.answer_id if not is_correct else None,
            "missed_word_ids": missed_ids,
            "mistake_count": 0,
        }
        matched_pairs = {}
        finalized = True

    if existing is None:
        existing = ExerciseSubmission(
            user_id=user.id,
            lesson_id=lesson_id,
            exercise_id=exercise.id,
            run_id=answer.run_id,
        )
        db.add(existing)
    if answer.submission_id:
        request_history[answer.submission_id] = {
            "answer": request_answer,
            "response": response,
        }
        existing.selected_answer = {
            "_answer": selected,
            "_submission_requests": request_history,
        }
    else:
        existing.selected_answer = selected
    existing.matched_pairs = matched_pairs
    existing.missed_word_ids = response["missed_word_ids"]
    existing.correct = response["correct"] if finalized else None
    existing.is_final = finalized
    existing.result_payload = response
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        saved = db.scalar(
            select(ExerciseSubmission).where(
                ExerciseSubmission.user_id == user.id,
                ExerciseSubmission.lesson_id == lesson_id,
                ExerciseSubmission.run_id == answer.run_id,
                ExerciseSubmission.exercise_id == exercise.id,
            )
        )
        if saved and saved.result_payload:
            saved_requests = (
                (saved.selected_answer or {}).get("_submission_requests", {})
                if isinstance(saved.selected_answer, dict)
                else {}
            )
            saved_request = saved_requests.get(answer.submission_id)
            if saved_request and saved_request.get("answer") == request_answer:
                return saved_request["response"]
        raise HTTPException(status_code=409, detail="This exercise was already answered")
    return response


def _correct_answer(exercise: Exercise) -> dict:
    content = exercise.content_data or {}
    word_id = content.get("target_word_id")
    if exercise.exercise_type == "matchWords":
        return {
            "pairs": [
                {
                    "newari": pair["newari"],
                    "romanization": pair["roman"],
                    "english": pair["english"],
                }
                for pair in content.get("pairs", [])
            ]
        }
    word = next(
        (item for item in load_curriculum()["words"] if item["id"] == word_id),
        None,
    )
    if word is None:
        return {}
    image_key = content.get("image_key") or (
        (content.get("layout") or {}).get("tile", {}).get("image_key")
    )
    if exercise.exercise_type == "wordToPicture":
        correct_option = next(
            (
                option for option in (exercise.options or [])
                if option["id"] == exercise.answer_id
            ),
            {},
        )
        image_key = correct_option.get("image_key")
    return {
        "newari": word["newari"],
        "romanization": word["roman"],
        "english": word["english"],
        "image_key": image_key,
    }


# ─── Leaderboard ───────────────────────────────────────────────


@app.get("/api/v1/leaderboard", response_model=list[LeaderboardEntryOut])
def get_leaderboard(
    filter: str = "weekly",
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    if filter not in {"weekly", "alltime"}:
        raise HTTPException(status_code=422, detail="filter must be weekly or alltime")
    if filter == "weekly":
        start = datetime.now(timezone.utc) - timedelta(days=7)
        scores = dict(
            db.execute(
                select(Attempt.user_id, func.sum(Attempt.xp_earned))
                .where(Attempt.completed_at >= start)
                .group_by(Attempt.user_id)
            ).all()
        )
        rows = (
            db.scalars(select(User).where(User.id.in_(scores.keys())).order_by(User.name)).all()
            if scores
            else []
        )
        rows.sort(key=lambda row: (-scores[row.id], row.name))
        score_for = lambda row: scores[row.id]
    else:
        rows = db.scalars(select(User).order_by(User.xp.desc(), User.name)).all()
        score_for = lambda row: row.xp
    return [
        LeaderboardEntryOut(
            rank=index,
            name=row.name,
            level=level_state(row.xp)[0],
            class_name=hero_class(level_state(row.xp)[0]),
            xp=score_for(row),
            hero_index=row.hero_index,
            is_current_user=row.id == user.id,
        )
        for index, row in enumerate(rows[:100], start=1)
    ]


def _lesson_is_passed(db: Session, user_id: int, lesson_id: str) -> bool:
    return db.scalar(
        select(LessonProgress.id).where(
            LessonProgress.user_id == user_id,
            LessonProgress.lesson_id == lesson_id,
            LessonProgress.completed_at.is_not(None),
        )
    ) is not None


def _lesson_prerequisite_met(
    db: Session,
    user: User,
    lesson: Lesson,
    lessons: list[Lesson] | None = None,
) -> bool:
    ordered = lessons or list(db.scalars(active_lessons_query()).all())
    position = next(
        (index for index, item in enumerate(ordered) if item.id == lesson.id),
        None,
    )
    return position == 0 or (
        position is not None
        and position > 0
        and _lesson_is_passed(db, user.id, ordered[position - 1].id)
    )


def _lesson_availability(
    db: Session,
    user: User,
    lesson: Lesson,
    lessons: list[Lesson] | None = None,
) -> str:
    if not lesson_is_playable(db, lesson):
        return "unavailable"
    if _lesson_is_passed(db, user.id, lesson.id):
        return "completed"
    if not _lesson_prerequisite_met(db, user, lesson, lessons):
        return "locked"
    return "available"


def _planned_exercise_count_for_lesson(lesson: Lesson) -> int:
    return int((lesson.content_data or {}).get("exercise_count", 0))


def _get_town_map(db: Session, user: User, course_id: str) -> list[dict]:
    """Return all lessons for a course with availability status (Town map).

    Includes unpublished lessons so the Town can show the planned
    curriculum without exposing exercise content or correct answers.
    """
    cid = _resolve_course_id(course_id, user)
    lessons = list(db.scalars(active_lessons_query()).all()) if cid == "en_new" else []

    result = []
    lesson_count = len(lessons)
    for lesson in lessons:
        content = lesson.content_data or {}
        availability = _lesson_availability(db, user, lesson, lessons)
        result.append({
            "id": lesson.id,
            "unit_id": lesson.unit_id,
            "unit_sequence": lesson.unit.sequence if lesson.unit else None,
            "unit_title": lesson.unit.title if lesson.unit else None,
            "sequence": lesson.sequence,
            "title": lesson.title,
            "subtitle": lesson.subtitle,
            "exercise_type": lesson.exercise_type,
            "xp_reward": lesson.xp_reward,
            "word_count": lesson.word_count,
            "required_level": lesson.required_level,
            "is_published": lesson.is_published,
            "is_checkpoint": lesson.is_checkpoint,
            "is_capstone": content.get("number") == lesson_count,
            "passing_score": lesson.passing_score,
            "availability": availability,
            "planned_exercise_count": _planned_exercise_count_for_lesson(lesson),
            "populated_exercise_count": len(lesson.exercises) if lesson.exercises else 0,
            "content_environment": content_environment(),
            "provisional": not is_lesson_publication_ready(db, lesson),
        })
    return result
