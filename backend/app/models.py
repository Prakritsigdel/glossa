from datetime import date, datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80))
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    hero_index: Mapped[int] = mapped_column(Integer, default=0)
    hero_class_name: Mapped[str] = mapped_column(String(40), default="Traveler")
    language_id: Mapped[str] = mapped_column(String(40), default="newari")
    xp: Mapped[int] = mapped_column(Integer, default=0)
    level: Mapped[int] = mapped_column(Integer, default=1)
    streak: Mapped[int] = mapped_column(Integer, default=0)
    last_activity_date: Mapped[date | None] = mapped_column(nullable=True)
    words_found: Mapped[int] = mapped_column(Integer, default=0)
    lessons_completed: Mapped[int] = mapped_column(Integer, default=0)
    attempts: Mapped[list["Attempt"]] = relationship(back_populates="user")


class Lesson(Base):
    __tablename__ = "lessons"
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    title: Mapped[str] = mapped_column(String(120))
    subtitle: Mapped[str] = mapped_column(String(200))
    exercise_type: Mapped[str] = mapped_column(String(40))
    xp_reward: Mapped[int] = mapped_column(Integer, default=20)
    word_count: Mapped[int] = mapped_column(Integer, default=4)
    required_level: Mapped[int] = mapped_column(Integer, default=1)
    exercises: Mapped[list["Exercise"]] = relationship(back_populates="lesson", cascade="all, delete-orphan")


class Exercise(Base):
    __tablename__ = "exercises"
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"))
    exercise_type: Mapped[str] = mapped_column(String(40))
    instruction: Mapped[str] = mapped_column(String(200))
    prompt: Mapped[str | None] = mapped_column(String(300), nullable=True)
    prompt_hint: Mapped[str | None] = mapped_column(String(300), nullable=True)
    image_key: Mapped[str | None] = mapped_column(String(80), nullable=True)
    options: Mapped[list] = mapped_column(JSON)
    answer_id: Mapped[str | None] = mapped_column(String(40), nullable=True)
    pairs: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    lesson: Mapped[Lesson] = relationship(back_populates="exercises")


class Attempt(Base):
    __tablename__ = "attempts"
    __table_args__ = (UniqueConstraint("user_id", "lesson_id", name="uq_user_lesson_attempt"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id"))
    correct_answers: Mapped[int] = mapped_column(Integer)
    total_questions: Mapped[int] = mapped_column(Integer)
    xp_earned: Mapped[int] = mapped_column(Integer)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    user: Mapped[User] = relationship(back_populates="attempts")
