"""Stage 3.1 integration tests for publication-readiness and endpoint security.

Uses in-memory SQLite with real model objects.
"""

from __future__ import annotations

import unittest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.main import is_lesson_publication_ready, lesson_publication_status
from app.models import (
    Attempt, Course, Exercise, Language, Lesson, LessonVocabulary,
    Unit, User, VocabularyEntry,
)


def make_session():
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)()


def seed_minimal(session):
    """Seed languages, course, unit, user."""
    session.execute(
        text(
            "INSERT INTO languages (id, name_english, name_native, script, is_active) "
            "VALUES ('en','English','English','Latin',1),"
            "('new','Newari','नेपाल भाषा','Devanagari',1)"
        )
    )
    session.execute(
        text(
            "INSERT INTO courses (id, source_language_id, target_language_id, "
            "name, description, is_published, is_active) "
            "VALUES ('en_new','en','new','English -> Newari','Test',0,1)"
        )
    )
    session.add(Unit(course_id="en_new", sequence=1, title="Greetings", description="Unit 1"))
    session.add(User(id=1, name="Test", email="t@e.com", password_hash="h", active_course_id="en_new"))
    session.commit()


def make_vocab(session, english, newari, roman, verified=False, lessons="1"):
    vid = f"vocab_{english.lower().replace(' ', '_')}"
    entry = VocabularyEntry(
        id=vid, source_worksheet="Vocabulary", source_row=1,
        unit="Greetings", english_meaning=english, newari_script=newari,
        romanization=roman, lesson_numbers=lessons, is_verified=verified,
    )
    session.add(entry)
    session.flush()
    return entry


def make_lesson_with_exercises(session, lesson_id, unit, published=False,
                               vocab_verified=False, num_exercises=2,
                               planned=2):
    """Create a lesson with exercises and vocab links."""
    lesson = Lesson(
        id=lesson_id, unit_id=unit.id, sequence=1,
        title="Test", subtitle="Test", exercise_type="matchWords",
        xp_reward=20, word_count=4, required_level=1,
        is_published=published, vocabulary_verified=vocab_verified,
    )
    session.add(lesson)
    session.commit()

    for i in range(num_exercises):
        ex = Exercise(
            id=f"{lesson_id}_ex{i}", lesson_id=lesson.id,
            exercise_type="matchWords", instruction="Match",
            sequence=i + 1,
            options=[{"id": "d1", "text": "नमस्ते", "is_devanagari": True},
                     {"id": "e1", "text": "Hello"}],
            pairs={"d1": "e1"},
            correct_answer_config={"pairs": {"d1": "e1"}},
            newari_script="नमस्ते", romanization="namaste",
        )
        session.add(ex)

    vocab = make_vocab(session, "Hello", "नमस्ते", "namaste", verified=vocab_verified, lessons="1")
    session.add(LessonVocabulary(
        lesson_id=lesson.id, vocabulary_entry_id=vocab.id,
        role="introduced", sequence=1,
    ))
    session.commit()
    return lesson


class TestPublicationEnforcementIntegration(unittest.TestCase):
    """An incomplete or unverified lesson must not become playable
    simply by setting is_published=True."""

    def setUp(self):
        self.session = make_session()
        seed_minimal(self.session)
        self.unit = self.session.query(Unit).filter_by(course_id="en_new").first()

    def tearDown(self):
        self.session.close()

    def test_unpublished_lesson_not_ready(self):
        lesson = make_lesson_with_exercises(
            self.session, "lesson_unpub", self.unit,
            published=False, vocab_verified=True, num_exercises=2, planned=2,
        )
        self.assertFalse(lesson.is_published)
        self.assertFalse(is_lesson_publication_ready(self.session, lesson))
        status = lesson_publication_status(self.session, lesson)
        self.assertFalse(status["publication_ready"])
        self.assertIn("not_explicitly_published", status["blockers"])

    def test_published_but_unverified_vocab_not_ready(self):
        """is_published=True alone is NOT sufficient when vocab is unverified."""
        lesson = make_lesson_with_exercises(
            self.session, "lesson_unverified", self.unit,
            published=True, vocab_verified=False, num_exercises=2, planned=2,
        )
        self.assertTrue(lesson.is_published)
        self.assertFalse(lesson.vocabulary_verified)
        self.assertFalse(is_lesson_publication_ready(self.session, lesson))
        status = lesson_publication_status(self.session, lesson)
        self.assertFalse(status["publication_ready"])
        self.assertIn("vocabulary_not_verified", status["blockers"])

    def test_published_but_incomplete_exercises_not_ready(self):
        """Published with fewer exercises than planned is not ready."""
        lesson = make_lesson_with_exercises(
            self.session, "en_new_u1_l1", self.unit,
            published=True, vocab_verified=True, num_exercises=1, planned=2,
        )
        self.assertTrue(lesson.is_published)
        self.assertFalse(is_lesson_publication_ready(self.session, lesson))
        status = lesson_publication_status(self.session, lesson)
        self.assertFalse(status["publication_ready"])
        self.assertTrue(any("incomplete_exercises" in b for b in status["blockers"]))

    def test_fully_verified_lesson_is_ready(self):
        """A fully published + verified lesson IS publication-ready."""
        lesson = make_lesson_with_exercises(
            self.session, "lesson_ready", self.unit,
            published=True, vocab_verified=True, num_exercises=2, planned=2,
        )
        self.assertTrue(is_lesson_publication_ready(self.session, lesson))
        status = lesson_publication_status(self.session, lesson)
        self.assertTrue(status["publication_ready"])
        self.assertEqual(status["blockers"], [])

    def test_published_without_romanization_not_ready(self):
        """Newari script without romanization blocks publication."""
        lesson = Lesson(
            id="lesson_norom", unit_id=self.unit.id, sequence=1,
            title="Test", subtitle="Test", exercise_type="matchWords",
            xp_reward=20, word_count=4, required_level=1,
            is_published=True, vocabulary_verified=True,
        )
        self.session.add(lesson)
        self.session.commit()
        ex = Exercise(
            id="lesson_norom_ex", lesson_id=lesson.id,
            exercise_type="matchWords", instruction="Match", sequence=1,
            options=[{"id": "d1", "text": "नमस्ते", "is_devanagari": True},
                     {"id": "e1", "text": "Hello"}],
            pairs={"d1": "e1"}, correct_answer_config={"pairs": {"d1": "e1"}},
            newari_script="नमस्ते", romanization=None,
        )
        self.session.add(ex)
        vocab = make_vocab(self.session, "Hello", "नमस्ते", "namaste", verified=True, lessons="1")
        self.session.add(LessonVocabulary(
            lesson_id=lesson.id, vocabulary_entry_id=vocab.id,
            role="introduced", sequence=1,
        ))
        self.session.commit()
        self.assertFalse(is_lesson_publication_ready(self.session, lesson))
        status = lesson_publication_status(self.session, lesson)
        self.assertFalse(status["publication_ready"])
        self.assertTrue(any("missing_romanization" in b for b in status["blockers"]))


if __name__ == "__main__":
    unittest.main()
