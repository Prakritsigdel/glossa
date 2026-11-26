from datetime import date, datetime

import sqlalchemy as sa
from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Float,
    Index,
    Integer,
    JSON,
    PrimaryKeyConstraint,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Language(Base):
    __tablename__ = "languages"

    id: Mapped[str] = mapped_column(String(10), primary_key=True)
    name_english: Mapped[str] = mapped_column(String(80))
    name_native: Mapped[str] = mapped_column(String(80))
    script: Mapped[str] = mapped_column(String(40))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    courses_as_source: Mapped[list["Course"]] = relationship(
        foreign_keys="Course.source_language_id", back_populates="source_language"
    )
    courses_as_target: Mapped[list["Course"]] = relationship(
        foreign_keys="Course.target_language_id", back_populates="target_language"
    )


class Course(Base):
    __tablename__ = "courses"
    __table_args__ = (
        UniqueConstraint("source_language_id", "target_language_id", name="uq_source_target"),
    )

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    source_language_id: Mapped[str] = mapped_column(ForeignKey("languages.id"))
    target_language_id: Mapped[str] = mapped_column(ForeignKey("languages.id"))
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    source_language: Mapped["Language"] = relationship(
        foreign_keys=[source_language_id], back_populates="courses_as_source"
    )
    target_language: Mapped["Language"] = relationship(
        foreign_keys=[target_language_id], back_populates="courses_as_target"
    )
    units: Mapped[list["Unit"]] = relationship(back_populates="course")
    active_users: Mapped[list["User"]] = relationship(back_populates="active_course")


class Unit(Base):
    __tablename__ = "units"
    __table_args__ = (
        UniqueConstraint("course_id", "sequence", name="uq_course_sequence"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id"), index=True)
    sequence: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)

    course: Mapped["Course"] = relationship(back_populates="units")
    lessons: Mapped[list["Lesson"]] = relationship(back_populates="unit")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80))
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    hero_index: Mapped[int] = mapped_column(Integer, default=0)
    hero_class_name: Mapped[str] = mapped_column(String(40), default="Traveler")
    language_id: Mapped[str] = mapped_column(String(40), default="newari")
    active_course_id: Mapped[str | None] = mapped_column(
        ForeignKey("courses.id"), nullable=True, index=True
    )
    xp: Mapped[int] = mapped_column(Integer, default=0)
    level: Mapped[int] = mapped_column(Integer, default=1)
    streak: Mapped[int] = mapped_column(Integer, default=0)
    last_activity_date: Mapped[date | None] = mapped_column(nullable=True)
    words_found: Mapped[int] = mapped_column(Integer, default=0)
    lessons_completed: Mapped[int] = mapped_column(Integer, default=0)

    attempts: Mapped[list["Attempt"]] = relationship(back_populates="user")
    lesson_completions: Mapped[list["LessonCompletion"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    active_course: Mapped["Course | None"] = relationship(back_populates="active_users")


class Lesson(Base):
    __tablename__ = "lessons"
    __table_args__ = (
        UniqueConstraint("unit_id", "sequence", name="uq_unit_sequence"),
    )

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    unit_id: Mapped[int | None] = mapped_column(
        ForeignKey("units.id"), nullable=True, index=True
    )
    sequence: Mapped[int | None] = mapped_column(Integer, nullable=True)
    title: Mapped[str] = mapped_column(String(120))
    subtitle: Mapped[str] = mapped_column(String(200))
    exercise_type: Mapped[str] = mapped_column(String(40))
    xp_reward: Mapped[int] = mapped_column(Integer, default=20)
    word_count: Mapped[int] = mapped_column(Integer, default=4)
    required_level: Mapped[int] = mapped_column(Integer, default=1)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False)
    is_checkpoint: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # ── Passing threshold (Stage 6) ─────────────────────────────
    # Ordinary lessons require 100 (fully correct). Checkpoints require 80.
    passing_score: Mapped[int] = mapped_column(Integer, default=100, nullable=False)

    # ── Publication-readiness verification flags (Stage 3.1) ──────
    # All default to False; a lesson is not publication-ready until each
    # relevant domain is explicitly verified by a native speaker.
    vocabulary_verified: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False, server_default=sa.text("false")
    )
    sentence_verified: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False, server_default=sa.text("false")
    )
    dialogue_verified: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False, server_default=sa.text("false")
    )
    illustration_verified: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False, server_default=sa.text("false")
    )

    unit: Mapped["Unit | None"] = relationship(back_populates="lessons")
    exercises: Mapped[list["Exercise"]] = relationship(
        back_populates="lesson", cascade="all, delete-orphan"
    )
    attempts: Mapped[list["Attempt"]] = relationship(back_populates="lesson")
    vocabulary: Mapped[list["LessonVocabulary"]] = relationship(
        back_populates="lesson", cascade="all, delete-orphan"
    )
    completions: Mapped[list["LessonCompletion"]] = relationship(
        back_populates="lesson", cascade="all, delete-orphan"
    )


class Exercise(Base):
    __tablename__ = "exercises"

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"))
    exercise_type: Mapped[str] = mapped_column(String(40))
    instruction: Mapped[str] = mapped_column(String(200))
    prompt: Mapped[str | None] = mapped_column(String(300), nullable=True)
    prompt_hint: Mapped[str | None] = mapped_column(String(300), nullable=True)
    image_key: Mapped[str | None] = mapped_column(String(80), nullable=True)
    audio_key: Mapped[str | None] = mapped_column(String(80), nullable=True)
    sequence: Mapped[int | None] = mapped_column(Integer, nullable=True)
    options: Mapped[list] = mapped_column(JSON)
    answer_id: Mapped[str | None] = mapped_column(String(40), nullable=True)
    pairs: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    # ── Structured fields for all seven exercise types ──────────
    newari_script: Mapped[str | None] = mapped_column(String(200), nullable=True)
    romanization: Mapped[str | None] = mapped_column(String(200), nullable=True)
    word_tiles: Mapped[list | None] = mapped_column(JSON, nullable=True)
    dialogue_structure: Mapped[list | None] = mapped_column(JSON, nullable=True)
    illustration_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    correct_answer_config: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    vocabulary_reference: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    lesson: Mapped["Lesson"] = relationship(back_populates="exercises")


class Attempt(Base):
    __tablename__ = "attempts"
    __table_args__ = (
        # Keys are scoped to an account so unrelated users may reuse them.
        UniqueConstraint("user_id", "idempotency_key", name="uq_attempts_user_idempotency_key"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id"))
    attempt_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    idempotency_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    submission_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    correct_answers: Mapped[int] = mapped_column(Integer)
    total_questions: Mapped[int] = mapped_column(Integer)
    xp_earned: Mapped[int] = mapped_column(Integer)
    passing_threshold: Mapped[int | None] = mapped_column(Integer, nullable=True)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="attempts")
    lesson: Mapped["Lesson"] = relationship(back_populates="attempts")


class LessonCompletion(Base):
    """A single completed lesson attempt for a user.

    One record per (user_id, lesson_id) pair, enforced by a unique
    constraint. This is the authoritative record of whether a lesson has
    been completed and whether XP was awarded. It is separate from
    Attempt, which records every individual submission (including failed
    retries).

    The `passed` flag distinguishes checkpoint completion (80%+) from
    full correctness (100%). Only passed completions award XP, and only
    once per user per lesson.
    """

    __tablename__ = "lesson_completions"
    __table_args__ = (
        UniqueConstraint("user_id", "lesson_id", name="uq_lesson_completion_user_lesson"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    lesson_id: Mapped[str] = mapped_column(
        ForeignKey("lessons.id", ondelete="CASCADE"), index=True, nullable=False
    )
    score: Mapped[float] = mapped_column(Float, nullable=False)
    passed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    xp_earned: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    correct_answers: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_questions: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship(back_populates="lesson_completions")
    lesson: Mapped["Lesson"] = relationship(back_populates="completions")


class VocabularyEntry(Base):
    """A single validated Newari vocabulary entry imported from a workbook.

    Entries are a validated data layer, separate from the curriculum
    (lessons/exercises). They are kept unverified until a native speaker
    reviews them, and are never published automatically.
    """

    __tablename__ = "vocabulary_entries"
    __table_args__ = (
        UniqueConstraint(
            "english_meaning", "newari_script", name="uq_vocabulary_english_newari"
        ),
    )

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    source_worksheet: Mapped[str] = mapped_column(String(80), nullable=False)
    source_row: Mapped[int] = mapped_column(Integer, nullable=False)
    unit: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    english_meaning: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    newari_script: Mapped[str] = mapped_column(String(200), nullable=False)
    romanization: Mapped[str | None] = mapped_column(String(200), nullable=True)
    lesson_numbers: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    lessons: Mapped[list["LessonVocabulary"]] = relationship(
        back_populates="vocabulary_entry", cascade="all, delete-orphan"
    )


class LessonVocabulary(Base):
    """Links a lesson to the vocabulary entries it introduces or reviews.

    The workbook's ``Lessons`` column lists every lesson where a word is
    used; the first number is where it is introduced. This table makes
    that introduction/review assignment queryable for the curriculum
    blueprint and lesson renderers.
    """

    __tablename__ = "lesson_vocabulary"
    __table_args__ = (
        PrimaryKeyConstraint(
            "lesson_id", "vocabulary_entry_id", "role", name="pk_lesson_vocabulary"
        ),
        Index("ix_lesson_vocabulary_lesson_id", "lesson_id"),
        Index("ix_lesson_vocabulary_vocab_entry_id", "vocabulary_entry_id"),
    )

    lesson_id: Mapped[str] = mapped_column(
        String(40), ForeignKey("lessons.id", ondelete="CASCADE"), nullable=False
    )
    vocabulary_entry_id: Mapped[str] = mapped_column(
        String(40), ForeignKey("vocabulary_entries.id", ondelete="CASCADE"), nullable=False
    )
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    lesson: Mapped["Lesson"] = relationship(back_populates="vocabulary")
    vocabulary_entry: Mapped["VocabularyEntry"] = relationship(
        back_populates="lessons"
    )
