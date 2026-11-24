from pydantic import BaseModel, ConfigDict, EmailStr, Field


class Credentials(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class Registration(Credentials):
    name: str = Field(min_length=1, max_length=80)


class ProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    hero_index: int | None = Field(default=None, ge=0, le=1)
    language_id: str | None = Field(default=None, max_length=40)


class UserOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    hero_index: int
    hero_class_name: str
    language_id: str
    active_course_id: str | None = None
    xp: int
    xp_to_next_level: int
    level: int
    streak: int
    words_found: int
    lessons_completed: int
    model_config = ConfigDict(from_attributes=True)


class AuthOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class AnswerIn(BaseModel):
    exercise_id: str
    selected_option_id: str | None = None
    selected_pairs: dict[str, str] | None = None


class AttemptIn(BaseModel):
    answers: list[AnswerIn] = Field(min_length=1)


class LeaderboardEntryOut(BaseModel):
    rank: int
    name: str
    level: int
    class_name: str
    xp: int
    hero_index: int
    is_current_user: bool = False


# ─── Multi-language course schemas ───────────────────────────


class LanguageOut(BaseModel):
    id: str
    name_english: str
    name_native: str
    script: str
    is_active: bool
    model_config = ConfigDict(from_attributes=True)


class CourseOut(BaseModel):
    id: str
    source_language_id: str
    target_language_id: str
    name: str
    description: str | None = None
    is_published: bool
    source_language: LanguageOut
    target_language: LanguageOut
    model_config = ConfigDict(from_attributes=True)


class CourseUpdate(BaseModel):
    active_course_id: str = Field(min_length=1, max_length=40)


class UnitOut(BaseModel):
    id: int
    course_id: str
    sequence: int
    title: str
    description: str | None = None
    total_lessons: int
    cleared_lessons: int
    model_config = ConfigDict(from_attributes=True)


class LessonOut(BaseModel):
    id: str
    unit_id: int | None = None
    sequence: int | None = None
    title: str
    subtitle: str
    exercise_type: str
    status: str
    xp_reward: int
    word_count: int
    required_level: int
    is_published: bool
    model_config = ConfigDict(from_attributes=True)


# ─── Exercise engine schemas ────────────────────────────────────────

class ExerciseOptionOut(BaseModel):
    id: str
    text: str
    is_devanagari: bool = False
    image_key: str | None = None
    speaker: str | None = None


class ExerciseOut(BaseModel):
    id: str
    lesson_id: str
    exercise_type: str
    sequence: int | None = None
    instruction: str
    prompt: str | None = None
    prompt_hint: str | None = None
    image_key: str | None = None
    audio_key: str | None = None
    newari_script: str | None = None
    romanization: str | None = None
    illustration_id: str | None = None
    vocabulary_reference: dict | None = None

    options: list[ExerciseOptionOut] | None = None
    word_tiles: list[ExerciseOptionOut] | None = None
    dialogue_structure: list[dict] | None = None

    model_config = ConfigDict(from_attributes=True)


class ExerciseAnswerIn(BaseModel):
    exercise_id: str
    selected_option_id: str | None = None
    selected_pairs: dict[str, str] | None = None
    selected_tile_ids: list[str] | None = None


class LessonAttemptIn(BaseModel):
    answers: list[ExerciseAnswerIn] = Field(min_length=1)
    idempotency_key: str | None = Field(default=None, min_length=1, max_length=64)


class ExerciseResultOut(BaseModel):
    exercise_id: str
    exercise_type: str
    correct: bool
    error: str | None = None


class LessonAttemptOut(BaseModel):
    lesson_id: str
    attempt_number: int
    is_correct: bool
    correct_answers: int
    total_questions: int
    xp_earned: int
    results: list[ExerciseResultOut]
    already_completed: bool = False
    model_config = ConfigDict(from_attributes=True)
