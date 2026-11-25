from datetime import datetime, timedelta, timezone
import hashlib
import json

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select, func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload
import jwt

from app.config import settings
from app.database import SessionLocal
from app.exercise_engine import validate_exercise, ALL_EXERCISE_TYPES
from app.curriculum_blueprint import EXERCISE_SEQUENCES, LESSON_TO_UNIT, PLANNED_UNITS, UNIT_SEQUENCE
from app.models import (
    Attempt, Course, Exercise, Language, Lesson, LessonCompletion, Unit, User, VocabularyEntry
)
from app.schemas import (
    AnswerIn, AttemptIn, AuthOut, CourseOut, CourseUpdate, Credentials,
    ExerciseAnswerIn, ExerciseOut, ExerciseResultOut, LessonAttemptIn,
    LessonAttemptOut, LanguageOut, LeaderboardEntryOut, LessonOut,
    ProfileUpdate, Registration, UnitOut, UserOut,
)
from app.security import create_token, hash_password, verify_password

app = FastAPI(title="Glossa API", version="2.0.0")
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
    return user.level * 150 if user.level > 1 else 100


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

EXERCISE_TYPE_ORDER = [
    "matchWords", "fillBlank", "pictureToWord", "wordToPicture",
    "translate", "wordOrder", "dialogueComplete",
]


def _plan_lesson_number(lesson_id: str) -> int | None:
    """Extract the course-plan lesson number (1-15) from a lesson id.

    Lesson ids use the format ``<course>_u<unit>_l<lesson_in_unit>``,
    e.g. ``en_new_u2_l3`` -> plan lesson 6 (unit 2, lesson 3 in unit).
    Returns None for non-blueprint lesson ids.
    """
    try:
        parts = lesson_id.split("_")
        # parts: ["en", "new", "u<N>", "l<M>"]
        unit_seq = int(parts[2][1:])
        lesson_in_unit = int(parts[3][1:])
        return (unit_seq - 1) * 3 + lesson_in_unit
    except (IndexError, ValueError):
        return None


def _is_current_blueprint_lesson(lesson_id: str) -> bool:
    try:
        parts = lesson_id.split("_")
        unit_number = int(parts[2][1:])
        lesson_number = int(parts[3][1:])
    except (IndexError, ValueError):
        return False
    return (
        lesson_id.startswith("en_new_u")
        and 1 <= unit_number <= 5
        and 1 <= lesson_number <= 3
    )


def _planned_exercise_slots_for_lesson(lesson: Lesson) -> int:
    """Return the planned exercise slot count for a lesson.

    For en_new blueprint lessons, uses EXERCISE_SEQUENCES keyed by the
    course-plan lesson number. For legacy lessons (no blueprint), returns
    the current exercise count so publication-readiness is not blocked
    by missing blueprint data.
    """
    plan_lesson = _plan_lesson_number(lesson.id)
    if plan_lesson is not None and plan_lesson in EXERCISE_SEQUENCES:
        return len(EXERCISE_SEQUENCES[plan_lesson])
    return len(lesson.exercises) if lesson.exercises else 0


def _exercise_requires_domain(exercise: Exercise, domain: str) -> bool:
    """Return True if an exercise type requires verification in a domain."""
    if domain == "illustration":
        return exercise.exercise_type in ("pictureToWord", "wordToPicture")
    if domain == "sentence":
        return exercise.exercise_type in ("wordOrder", "dialogueComplete")
    if domain == "dialogue":
        return exercise.exercise_type == "dialogueComplete"
    return False


def is_exercise_payload_valid(exercise: Exercise) -> bool:
    """Check that an exercise payload is structurally valid.

    Does not expose correct answers; only validates structure.
    """
    if not exercise.instruction or not exercise.instruction.strip():
        return False
    if exercise.exercise_type not in ALL_EXERCISE_TYPES:
        return False
    if not exercise.options or not isinstance(exercise.options, list):
        return False
    # Every option must have an id and text
    for opt in exercise.options:
        if not isinstance(opt, dict):
            return False
        if not opt.get("id") or not opt.get("text"):
            return False
    # Type-specific structural checks
    if exercise.exercise_type == "matchWords":
        if not exercise.pairs or not isinstance(exercise.pairs, dict):
            return False
    if exercise.exercise_type in ("fillBlank", "pictureToWord", "wordToPicture", "dialogueComplete"):
        if not exercise.answer_id:
            return False
    if exercise.exercise_type in ("translate", "wordOrder"):
        if not exercise.word_tiles or not isinstance(exercise.word_tiles, list):
            return False
        if len(exercise.word_tiles) < 2:
            return False
    return True


def is_lesson_publication_ready(db: Session, lesson: Lesson) -> bool:
    """Check whether a lesson is ready for publication.

    A lesson must not be publicly playable unless:
    - Publication has been explicitly authorized (is_published=True)
    - All planned exercise slots are populated
    - All exercise payloads pass structural validation
    - All referenced vocabulary entries are is_verified=True
    - Newari spelling and romanization are present (verification flag governs trust)
    - Sentence/dialogue/illustration verification flags are True where required
    """
    # Explicit publication authorization required
    if not lesson.is_published:
        return False
    if not lesson.exercises:
        return False

    # All planned slots populated
    planned = _planned_exercise_slots_for_lesson(lesson)
    if len(lesson.exercises) < planned:
        return False

    # All exercise payloads structurally valid
    for exercise in lesson.exercises:
        if not is_exercise_payload_valid(exercise):
            return False

    # All referenced vocabulary entries must be verified
    vocab_ids = set()
    for lv in lesson.vocabulary or []:
        vocab_ids.add(lv.vocabulary_entry_id)
    if vocab_ids:
        verified_rows = db.scalars(
            select(VocabularyEntry.id).where(
                VocabularyEntry.id.in_(vocab_ids), VocabularyEntry.is_verified == True  # noqa: E712
            )
        ).all()
        if set(verified_rows) != vocab_ids:
            return False

    # Newari spelling + romanization present for exercises that have script
    for exercise in lesson.exercises:
        if exercise.newari_script and not exercise.romanization:
            return False

    # Domain-specific verification flags
    if not lesson.vocabulary_verified:
        return False
    needs_sentence = any(_exercise_requires_domain(e, "sentence") for e in lesson.exercises)
    if needs_sentence and not lesson.sentence_verified:
        return False
    needs_dialogue = any(_exercise_requires_domain(e, "dialogue") for e in lesson.exercises)
    if needs_dialogue and not lesson.dialogue_verified:
        return False
    needs_illustration = any(_exercise_requires_domain(e, "illustration") for e in lesson.exercises)
    if needs_illustration and not lesson.illustration_verified:
        return False

    return True


def lesson_publication_status(db: Session, lesson: Lesson) -> dict:
    """Return publication-readiness details for a lesson."""
    ready = is_lesson_publication_ready(db, lesson)
    reasons = []
    if not lesson.is_published:
        reasons.append("not_explicitly_published")
    if not lesson.exercises:
        reasons.append("no_exercises")
    else:
        planned = _planned_exercise_slots_for_lesson(lesson)
        if len(lesson.exercises) < planned:
            reasons.append(f"incomplete_exercises_{len(lesson.exercises)}_of_{planned}")
        for exercise in lesson.exercises:
            if not is_exercise_payload_valid(exercise):
                reasons.append(f"invalid_payload_{exercise.id}")
            if exercise.newari_script and not exercise.romanization:
                reasons.append(f"missing_romanization_{exercise.id}")
    if not lesson.vocabulary_verified:
        reasons.append("vocabulary_not_verified")
    needs_sentence = any(_exercise_requires_domain(e, "sentence") for e in lesson.exercises)
    if needs_sentence and not lesson.sentence_verified:
        reasons.append("sentence_not_verified")
    needs_dialogue = any(_exercise_requires_domain(e, "dialogue") for e in lesson.exercises)
    if needs_dialogue and not lesson.dialogue_verified:
        reasons.append("dialogue_not_verified")
    needs_illustration = any(_exercise_requires_domain(e, "illustration") for e in lesson.exercises)
    if needs_illustration and not lesson.illustration_verified:
        reasons.append("illustration_not_verified")
    return {
        "lesson_id": lesson.id,
        "is_published": lesson.is_published,
        "publication_ready": ready,
        "blockers": reasons,
    }



def user_output(user: User) -> UserOut:
    return UserOut(
        id=user.id, name=user.name, email=user.email, hero_index=user.hero_index,
        hero_class_name=user.hero_class_name, language_id=user.language_id,
        active_course_id=user.active_course_id, xp=user.xp,
        xp_to_next_level=xp_to_next(user), level=user.level,
        streak=current_streak(user), words_found=user.words_found,
        lessons_completed=user.lessons_completed,
    )


def auth_output(user: User) -> AuthOut:
    return AuthOut(access_token=create_token(user.id), user=user_output(user))


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
    """Calculate cleared/current/locked status for lessons in a course."""
    cid = _resolve_course_id(course_id, user)

    # Query published lessons in this course, ordered by unit.sequence then lesson.sequence
    lessons = list(
        db.scalars(
            select(Lesson)
            .join(Unit, Lesson.unit_id == Unit.id)
            .where(Unit.course_id == cid, Lesson.is_published == True)
            .order_by(Unit.sequence, Lesson.sequence)
        ).all()
    )
    lessons = [lesson for lesson in lessons if _is_current_blueprint_lesson(lesson.id)]
    if not lessons:
        return {}

    result = {}
    for lesson in lessons:
        result[lesson.id] = {
            "completed": "cleared",
            "available": "current",
            "locked": "locked",
            "unavailable": "locked",
        }[_lesson_availability(db, user, lesson)]
    return result
# ─── Health ────────────────────────────────────────────────────


@app.get("/health")
def health():
    return {"status": "ok"}


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
    return auth_output(user)


@app.post("/api/v1/auth/login", response_model=AuthOut)
def login(payload: Credentials, db: Session = Depends(db_session)):
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email or password is incorrect")
    return auth_output(user)


# ─── User profile ──────────────────────────────────────────────


@app.get("/api/v1/me", response_model=UserOut)
def get_me(user: User = Depends(current_user)):
    return user_output(user)


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
    return user_output(user)


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
    return user_output(user)


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
            .where(Unit.course_id == course_id, Unit.sequence.between(1, 5))
            .order_by(Unit.sequence)
        ).all()
    )

    # Progress is based on authoritative completions, never failed attempts.
    cleared_ids = set(
        db.scalars(
            select(LessonCompletion.lesson_id)
            .join(Lesson, Lesson.id == LessonCompletion.lesson_id)
            .join(Unit, Unit.id == Lesson.unit_id)
            .where(
                LessonCompletion.user_id == user.id,
                LessonCompletion.passed == True,  # noqa: E712
                Unit.course_id == course_id,
            )
        ).all()
    )

    result = []
    for unit in units:
        planned_ids = {
            f"en_new_u{unit.sequence}_l{lesson_number}"
            for lesson_number in range(1, 4)
        }
        total_lessons = len(planned_ids)
        cleared_lessons = sum(1 for lesson_id in planned_ids if lesson_id in cleared_ids)
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

    lessons = list(
        db.scalars(
            select(Lesson)
            .join(Unit, Lesson.unit_id == Unit.id)
            .where(Unit.course_id == cid, Lesson.is_published == True)
            .order_by(Unit.sequence, Lesson.sequence)
        ).all()
    )
    lessons = [lesson for lesson in lessons if _is_current_blueprint_lesson(lesson.id)]

    return [
        {
            "id": l.id,
            "unit_id": l.unit_id,
            "sequence": l.sequence,
            "title": l.title,
            "subtitle": l.subtitle,
            "exercise_type": l.exercise_type,
            "status": statuses.get(l.id, "locked"),
            "xp_reward": l.xp_reward,
            "word_count": l.word_count,
            "required_level": l.required_level,
            "is_published": l.is_published,
            "is_checkpoint": l.is_checkpoint,
            "is_capstone": l.id.endswith("_l15"),
            "passing_score": l.passing_score,
            "availability": _lesson_availability(db, user, l),
            "planned_exercise_count": _planned_exercise_count_for_lesson(l),
            "populated_exercise_count": len(l.exercises) if l.exercises else 0,
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
    lesson_ids = [
        f"en_new_u{unit}_l{lesson}"
        for unit in range(1, 6)
        for lesson in range(1, 4)
    ]
    completed_ids = set(
        db.scalars(
            select(LessonCompletion.lesson_id).where(
                LessonCompletion.user_id == user.id,
                LessonCompletion.lesson_id.in_(lesson_ids),
                LessonCompletion.passed == True,  # noqa: E712
            )
        ).all()
    )
    completed = len(completed_ids)
    return {
        "course_id": course_id,
        "completed_lessons": completed,
        "total_lessons": 15,
        "is_complete": completed == 15,
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
    # Enforce en_new course membership: retired course lessons are inaccessible.
    lesson_unit = db.scalar(
        select(Unit).where(Unit.id == lesson.unit_id)
    )
    if lesson_unit is None or lesson_unit.course_id != "en_new":
        raise HTTPException(status_code=403, detail="Lesson is not available")
    if not _is_current_blueprint_lesson(lesson.id):
        raise HTTPException(status_code=403, detail="Lesson is not part of the active curriculum")
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    # Publication-readiness: unreviewed lessons remain unpublished and
    # their exercises are not served to learners.
    if not lesson.is_published:
        raise HTTPException(
            status_code=403,
            detail="Lesson is not published and awaiting verification.",
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
                instruction=e.instruction,
                prompt=e.prompt,
                prompt_hint=e.prompt_hint,
                image_key=e.image_key,
                audio_key=e.audio_key,
                newari_script=e.newari_script,
                romanization=e.romanization,
                illustration_id=e.illustration_id,
                vocabulary_reference=e.vocabulary_reference,
                options=public_options,
                word_tiles=public_word_tiles,
                dialogue_structure=e.dialogue_structure,
            )
        )
    return exercises


@app.post("/api/v1/lessons/{lesson_id}/attempts", response_model=LessonAttemptOut)
def submit_attempt(
    lesson_id: str,
    payload: LessonAttemptIn,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    """Submit answers for all exercises in a lesson.

    Server-authoritative scoring: the client does not provide scores,
    completion flags, or XP. Supports variable exercise counts,
    idempotency (via idempotency_key), and legitimate retries.
    XP is awarded only on the first passing attempt (100% for ordinary
    lessons, 80%+ for checkpoints).
    """
    user = db.scalar(
        select(User)
        .where(User.id == user.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    lesson = db.scalar(
        select(Lesson).where(Lesson.id == lesson_id).options(selectinload(Lesson.exercises))
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")

    # Enforce en_new course membership: retired course lessons are inaccessible.
    lesson_unit = db.scalar(
        select(Unit).where(Unit.id == lesson.unit_id)
    )
    if lesson_unit is None or lesson_unit.course_id != "en_new":
        raise HTTPException(status_code=403, detail="Lesson is not available")
    if not _is_current_blueprint_lesson(lesson.id):
        raise HTTPException(status_code=403, detail="Lesson is not part of the active curriculum")

    # Publication check: unreviewed lessons cannot be played.
    if not lesson.is_published:
        raise HTTPException(
            status_code=403,
            detail="Lesson is not published and awaiting verification.",
        )

    # Lock check: prerequisites must be completed.
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")

    exercises = {e.id: e for e in lesson.exercises}
    if not exercises:
        raise HTTPException(status_code=422, detail="Lesson has no exercises")

    # Build submitted answers map
    submitted: dict[str, ExerciseAnswerIn] = {}
    for answer in payload.answers:
        if answer.exercise_id in submitted:
            raise HTTPException(
                status_code=422,
                detail=f"Duplicate response for exercise {answer.exercise_id}",
            )
        submitted[answer.exercise_id] = answer

    # Validate: exactly one response per playable exercise
    submitted_ids = set(submitted.keys())
    exercise_ids = set(exercises.keys())
    if submitted_ids != exercise_ids:
        missing = exercise_ids - submitted_ids
        unknown = submitted_ids - exercise_ids
        msg_parts = []
        if missing:
            msg_parts.append(f"Missing responses for: {sorted(missing)}")
        if unknown:
            msg_parts.append(f"Unknown exercise ids: {sorted(unknown)}")
        raise HTTPException(status_code=422, detail="; ".join(msg_parts))

    # Validate each answer using the exercise engine
    results: list[ExerciseResultOut] = []
    correct_count = 0
    for exercise_id, exercise in exercises.items():
        answer = submitted[exercise_id]
        # Build exercise config dict for the validator
        ex_config = {
            "exercise_type": exercise.exercise_type,
            "options": exercise.options or [],
            "pairs": exercise.pairs,
            "answer_id": exercise.answer_id,
            "correct_answer_config": exercise.correct_answer_config or {},
            "word_tiles": exercise.word_tiles or [],
            "dialogue_structure": exercise.dialogue_structure,
        }

        # Extract submitted payload based on exercise type
        if exercise.exercise_type == "matchWords":
            submitted_payload = answer.selected_pairs
        elif exercise.exercise_type in ("translate", "wordOrder"):
            submitted_payload = answer.selected_tile_ids
        else:
            submitted_payload = answer.selected_option_id

        validation = validate_exercise(
            exercise.exercise_type, submitted_payload, ex_config
        )
        if not validation.valid:
            raise HTTPException(
                status_code=422,
                detail=f"Exercise {exercise_id}: {validation.error}",
            )
        is_correct = validation.correct
        if is_correct:
            correct_count += 1
        results.append(
            ExerciseResultOut(
                exercise_id=exercise_id,
                exercise_type=exercise.exercise_type,
                correct=is_correct,
            )
        )

    total_questions = len(exercises)
    passing_score = lesson.passing_score or 100
    # is_correct_all = 100% correct (backward-compatible meaning)
    is_correct_all = correct_count == total_questions
    # passed = meets the lesson's passing threshold (80% for checkpoints, 100% ordinary)
    passed = correct_count * 100 >= total_questions * passing_score
    submission_hash = hashlib.sha256(
        json.dumps(
            [answer.model_dump(exclude_none=True) for answer in sorted(payload.answers, key=lambda item: item.exercise_id)],
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()

    # Determine attempt number
    existing_attempts = list(
        db.scalars(
            select(Attempt).where(
                Attempt.user_id == user.id, Attempt.lesson_id == lesson_id
            ).order_by(Attempt.attempt_number)
        ).all()
    )
    attempt_number = (existing_attempts[-1].attempt_number + 1) if existing_attempts else 1

    # Check idempotency: if the same idempotency_key was already used by this user, return the prior result
    if payload.idempotency_key:
        existing_by_key = db.scalar(
            select(Attempt).where(
                Attempt.idempotency_key == payload.idempotency_key,
                Attempt.user_id == user.id,
            )
        )
        if existing_by_key:
            if existing_by_key.lesson_id != lesson_id:
                raise HTTPException(status_code=409, detail="Idempotency key was used for another lesson")
            if existing_by_key.submission_hash:
                conflict = existing_by_key.submission_hash != submission_hash
            else:
                conflict = (
                    existing_by_key.correct_answers != correct_count
                    or existing_by_key.total_questions != total_questions
                )
            if conflict:
                raise HTTPException(status_code=409, detail="Idempotency key was used with a different submission")
            db.refresh(user)
            return LessonAttemptOut(
                lesson_id=lesson_id,
                attempt_number=existing_by_key.attempt_number,
                is_correct=existing_by_key.is_correct,
                correct_answers=existing_by_key.correct_answers,
                total_questions=existing_by_key.total_questions,
                xp_earned=existing_by_key.xp_earned,
                score=existing_by_key.correct_answers / max(existing_by_key.total_questions, 1),
                passing_threshold=existing_by_key.passing_threshold or 100,
                passed=existing_by_key.correct_answers * 100 >= existing_by_key.total_questions * (existing_by_key.passing_threshold or 100),
                results=[],
                already_completed=True,
            )

    # Award XP only on the first passing attempt (not every correct attempt)
    xp_earned = 0
    already_completed = db.scalar(
        select(LessonCompletion).where(
            LessonCompletion.user_id == user.id,
            LessonCompletion.lesson_id == lesson_id,
        )
    )
    if passed and already_completed is None:
        xp_earned = lesson.xp_reward
        user.xp += xp_earned
        user.words_found += lesson.word_count
        user.lessons_completed += 1
        today = datetime.now(timezone.utc).date()
        if user.last_activity_date != today:
            yesterday = today - timedelta(days=1)
            user.streak = (
                user.streak + 1 if user.last_activity_date == yesterday else 1
            )
            user.last_activity_date = today
        while user.xp >= xp_to_next(user):
            user.level += 1
        levels = [(2, "Traveler"), (4, "Speaker"), (6, "Guardian")]
        user.hero_class_name = (
            "Master"
            if user.level >= 7
            else next(
                (title for limit, title in levels if user.level <= limit),
                "Master",
            )
        )

    # Create the attempt record (always, for history)
    attempt = Attempt(
        user_id=user.id,
        lesson_id=lesson_id,
        attempt_number=attempt_number,
        idempotency_key=payload.idempotency_key,
        submission_hash=submission_hash,
        is_correct=is_correct_all,
        passing_threshold=passing_score,
        correct_answers=correct_count,
        total_questions=total_questions,
        xp_earned=xp_earned,
    )
    db.add(attempt)

    # Create the completion record (only on first pass, idempotent)
    if passed and already_completed is None:
        completion = LessonCompletion(
            user_id=user.id,
            lesson_id=lesson_id,
            score=correct_count / total_questions if total_questions > 0 else 0.0,
            passed=True,
            xp_earned=xp_earned,
            correct_answers=correct_count,
            total_questions=total_questions,
        )
        db.add(completion)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        # Duplicate idempotency key (scoped to user) or concurrent completion
        # blocked by the unique constraint on (user_id, lesson_id).
        existing_by_key = None
        if payload.idempotency_key:
            existing_by_key = db.scalar(
                select(Attempt).where(
                    Attempt.idempotency_key == payload.idempotency_key,
                    Attempt.user_id == user.id,
                )
            )
        if existing_by_key:
            return LessonAttemptOut(
                lesson_id=lesson_id,
                attempt_number=existing_by_key.attempt_number,
                is_correct=existing_by_key.is_correct,
                correct_answers=existing_by_key.correct_answers,
                total_questions=existing_by_key.total_questions,
                xp_earned=existing_by_key.xp_earned,
                score=existing_by_key.correct_answers / max(existing_by_key.total_questions, 1),
                passing_threshold=existing_by_key.passing_threshold or 100,
                passed=existing_by_key.correct_answers * 100 >= existing_by_key.total_questions * (existing_by_key.passing_threshold or 100),
                results=[],
                already_completed=True,
            )
        # Check if a completion already exists (concurrent submission race)
        existing_completion = db.scalar(
            select(LessonCompletion).where(
                LessonCompletion.user_id == user.id,
                LessonCompletion.lesson_id == lesson_id,
            )
        )
        if existing_completion:
            return LessonAttemptOut(
                lesson_id=lesson_id,
                attempt_number=attempt_number,
                is_correct=is_correct_all,
                correct_answers=correct_count,
                total_questions=total_questions,
                xp_earned=existing_completion.xp_earned,
                score=correct_count / total_questions,
                passing_threshold=passing_score,
                passed=True,
                results=[],
                already_completed=True,
            )
        raise HTTPException(status_code=409, detail="Concurrent submission conflict")

    db.refresh(user)
    return LessonAttemptOut(
        lesson_id=lesson_id,
        attempt_number=attempt_number,
        is_correct=is_correct_all,
        correct_answers=correct_count,
        total_questions=total_questions,
        xp_earned=xp_earned,
        score=correct_count / total_questions,
        passing_threshold=passing_score,
        passed=passed,
        results=results,
        already_completed=already_completed is not None,
    )


@app.post("/api/v1/lessons/{lesson_id}/answer")
def check_answer(
    lesson_id: str,
    answer: AnswerIn,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    exercise = db.get(Exercise, answer.exercise_id)
    if exercise is None or exercise.lesson_id != lesson_id:
        raise HTTPException(status_code=404, detail="Exercise not found")
    lesson = db.get(Lesson, lesson_id)
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    # Enforce en_new course membership.
    lesson_unit = db.scalar(
        select(Unit).where(Unit.id == lesson.unit_id)
    )
    if lesson_unit is None or lesson_unit.course_id != "en_new":
        raise HTTPException(status_code=403, detail="Lesson is not available")
    if not _is_current_blueprint_lesson(lesson.id):
        raise HTTPException(status_code=403, detail="Lesson is not part of the active curriculum")
    # Publication check: unreviewed lessons cannot be played or probed.
    if not lesson.is_published:
        raise HTTPException(
            status_code=403,
            detail="Lesson is not published and awaiting verification.",
        )
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")

    # Build exercise config dict for the validator
    ex_config = {
        "exercise_type": exercise.exercise_type,
        "options": exercise.options or [],
        "pairs": exercise.pairs,
        "answer_id": exercise.answer_id,
        "correct_answer_config": exercise.correct_answer_config or {},
        "word_tiles": exercise.word_tiles or [],
        "dialogue_structure": exercise.dialogue_structure,
    }

    # Extract submitted payload based on exercise type
    if exercise.exercise_type == "matchWords":
        submitted_payload = answer.selected_pairs
    elif exercise.exercise_type in ("translate", "wordOrder"):
        submitted_payload = answer.selected_tile_ids
    else:
        submitted_payload = answer.selected_option_id

    validation = validate_exercise(
        exercise.exercise_type, submitted_payload, ex_config
    )
    if not validation.valid:
        raise HTTPException(
            status_code=422,
            detail=validation.error or "Invalid submission",
        )
    return {"correct": validation.correct}


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
            level=row.level,
            class_name=row.hero_class_name,
            xp=score_for(row),
            hero_index=row.hero_index,
            is_current_user=row.id == user.id,
        )
        for index, row in enumerate(rows[:100], start=1)
    ]


# ════════════════════════════════════════════════════════════════════
# Lesson completion and progression (Stage 6)
# ════════════════════════════════════════════════════════════════════

def _lesson_passing_score(lesson: Lesson) -> int:
    """Return the passing score threshold (0-100) for a lesson.

    Ordinary lessons require 100 (fully correct). Checkpoints require 80.
    """
    return lesson.passing_score or 100


def _lesson_is_passed(db: Session, user_id: int, lesson_id: str) -> bool:
    """Check if a lesson has been passed (completion record with passed=True)."""
    return db.scalar(
        select(LessonCompletion).where(
            LessonCompletion.user_id == user_id,
            LessonCompletion.lesson_id == lesson_id,
            LessonCompletion.passed == True,  # noqa: E712
        )
    ) is not None


def _lesson_prerequisite_met(db: Session, user: User, lesson: Lesson) -> bool:
    """Check if all prerequisite lessons for a lesson are completed.

    Lesson N (N > 1) requires lesson N-1 to be passed. Lesson 1 has no
    prerequisite. This naturally handles unit transitions: lesson 4
    requires lesson 3 (unit 1 checkpoint), etc.
    """
    try:
        parts = lesson.id.split("_")
        # Format: en_new_u<unit>_l<lesson_in_unit>
        unit_seq = int(parts[2][1:])
        lesson_in_unit = int(parts[3][1:])
    except (IndexError, ValueError):
        # Non-blueprint lesson - no prerequisite
        return True

    if unit_seq == 1 and lesson_in_unit == 1:
        # Lesson 1 (en_new_u1_l1) has no prerequisite
        return True

    # Previous lesson number in course-plan numbering (1-15)
    prev_lesson_num = (unit_seq - 1) * 3 + (lesson_in_unit - 1)
    if prev_lesson_num < 1:
        return True

    prev_unit_seq = (prev_lesson_num - 1) // 3 + 1
    prev_lesson_in_unit = ((prev_lesson_num - 1) % 3) + 1
    prev_lesson_id = f"en_new_u{prev_unit_seq}_l{prev_lesson_in_unit}"

    previous_lesson = db.get(Lesson, prev_lesson_id)
    if previous_lesson is None or not previous_lesson.is_published:
        return False
    return _lesson_is_passed(db, user.id, prev_lesson_id)


def _lesson_availability(db: Session, user: User, lesson: Lesson) -> str:
    """Determine the availability status of a lesson for a user.

    Returns one of: "unavailable", "locked", "available", "completed".
    """
    if not lesson.is_published:
        return "unavailable"
    if _lesson_is_passed(db, user.id, lesson.id):
        return "completed"
    if not _lesson_prerequisite_met(db, user, lesson):
        return "locked"
    return "available"


def _planned_exercise_count_for_lesson(lesson: Lesson) -> int:
    """Return the planned exercise slot count for a lesson."""
    return _planned_exercise_slots_for_lesson(lesson)


def _get_town_map(db: Session, user: User, course_id: str) -> list[dict]:
    """Return all lessons for a course with availability status (Town map).

    Includes unpublished lessons so the Town can show the planned
    curriculum without exposing exercise content or correct answers.
    """
    cid = _resolve_course_id(course_id, user)

    lessons = list(
        db.scalars(
            select(Lesson)
            .join(Unit, Lesson.unit_id == Unit.id)
            .where(Unit.course_id == cid)
            .order_by(Unit.sequence, Lesson.sequence)
        ).all()
    )

    result = []
    blueprint_ids = {
        f"en_new_u{unit}_l{lesson}"
        for unit in range(1, 6)
        for lesson in range(1, 4)
    }
    for lesson in lessons:
        if lesson.id not in blueprint_ids:
            continue
        availability = _lesson_availability(db, user, lesson)
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
            "is_capstone": lesson.id.endswith("_l15"),
            "passing_score": lesson.passing_score,
            "availability": availability,
            "planned_exercise_count": _planned_exercise_count_for_lesson(lesson),
            "populated_exercise_count": len(lesson.exercises) if lesson.exercises else 0,
        })
    return result
