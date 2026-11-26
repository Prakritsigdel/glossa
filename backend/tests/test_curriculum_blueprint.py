"""Automated tests for the Newari curriculum blueprint (Stage 2).

Run from the backend directory with:

    python -m unittest tests.test_curriculum_blueprint -v

These tests use an in-memory SQLite database with real vocabulary
imported from newari_vocabulary.xlsx (read-only). No PostgreSQL
instance is required for unit tests.
"""

from __future__ import annotations

import unittest
from collections import Counter
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models import (
    Course, Exercise, Lesson, LessonVocabulary, Unit, VocabularyEntry,
)
from app.curriculum_blueprint import (
    CHECKPOINT_LESSONS,
    EXERCISE_SEQUENCES,
    LESSON_TO_UNIT,
    PLANNED_UNITS,
    SUPPORTED_EXERCISE_TYPES,
    UNIT_SEQUENCE,
    generate_blueprint_lessons,
    seed_blueprint,
    vocabulary_for_lesson,
)
from app.vocabulary_importer import import_vocabulary

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
XLSX_PATH = str(REPO_ROOT / "newari_vocabulary.xlsx")

PLANNED_EXERCISE_TOTAL = sum(len(v) for v in EXERCISE_SEQUENCES.values())


def make_session():
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)()


def seed_minimal_course(session):
    """Create languages, courses, and 10 units for en_new (like seed.py)."""
    session.execute(
        text(
            "INSERT INTO languages (id, name_english, name_native, script, is_active) "
            "VALUES (:id, :en, :nat, :script, :active)"
        ),
        [{"id": "en", "en": "English", "nat": "English", "script": "Latin", "active": 1},
         {"id": "new", "en": "Newari", "nat": "नेपाल भाषा", "script": "Devanagari", "active": 1}],
    )
    session.execute(
        text(
            "INSERT INTO courses (id, source_language_id, target_language_id, "
            "name, description, is_published, is_active) "
            "VALUES (:id, :src, :tgt, :name, :desc, :pub, :active)"
        ),
        {"id": "en_new", "src": "en", "tgt": "new",
         "name": "English -> Newari", "desc": "Learn Newari starting from English", "pub": 0, "active": 1},
    )
    for seq in range(1, 11):
        session.add(Unit(course_id="en_new", sequence=seq,
                         title=f"Unit {seq}", description=f"Unit {seq} - English -> Newari"))
    session.commit()


def _plan_lesson_for_unit_seq(unit_sequence: int, lesson_seq_in_unit: int) -> int:
    """Given unit sequence (1-5) and lesson seq within unit (1-3), return
    the course-plan lesson number (1-15)."""
    unit_name = PLANNED_UNITS[unit_sequence - 1]
    for pn, un in LESSON_TO_UNIT.items():
        if un == unit_name:
            # lesson_seq_in_unit maps: 1->first lesson of unit, 2->second, 3->third
            # Unit 1: lessons 1,2,3; Unit 2: lessons 4,5,6; etc.
            base = (unit_sequence - 1) * 3
            return base + lesson_seq_in_unit
    return -1


class TestCurriculumBlueprint(unittest.TestCase):
    def test_blueprint_defines_15_lessons(self):
        self.assertEqual(len(EXERCISE_SEQUENCES), 15)
        self.assertEqual(set(EXERCISE_SEQUENCES.keys()), set(range(1, 16)))

    def test_planned_exercise_total_is_111(self):
        self.assertEqual(PLANNED_EXERCISE_TOTAL, 111)

    def test_checkpoint_lessons(self):
        self.assertEqual(CHECKPOINT_LESSONS, {3, 6, 9, 12, 15})

    def test_lesson_to_unit_mapping(self):
        self.assertEqual(LESSON_TO_UNIT[1], "Greetings")
        self.assertEqual(LESSON_TO_UNIT[4], "Family")
        self.assertEqual(LESSON_TO_UNIT[7], "Numbers & Colors")
        self.assertEqual(LESSON_TO_UNIT[10], "Food & Drinks")
        self.assertEqual(LESSON_TO_UNIT[13], "Home & Routines")

    def test_unit_sequence(self):
        self.assertEqual(UNIT_SEQUENCE["Greetings"], 1)
        self.assertEqual(UNIT_SEQUENCE["Home & Routines"], 5)

    def test_supported_exercise_types(self):
        # Stage 8 extended support to all seven exercise types using
        # illustration catalog, word-order phrases and dialogue content.
        self.assertEqual(SUPPORTED_EXERCISE_TYPES, {
            "matchWords", "fillBlank", "translate",
            "pictureToWord", "wordToPicture",
            "wordOrder", "dialogueComplete",
        })
        # All seven types are now supported.
        for ex_type in ("matchWords", "fillBlank", "translate",
                        "pictureToWord", "wordToPicture",
                        "wordOrder", "dialogueComplete"):
            self.assertIn(ex_type, SUPPORTED_EXERCISE_TYPES)

    def test_import_vocabulary_then_blueprint(self):
        session = make_session()
        try:
            seed_minimal_course(session)
            vocab_report = import_vocabulary(session, XLSX_PATH)
            self.assertEqual(vocab_report.imported_count, 70)

            units = session.query(Unit).filter(Unit.course_id == "en_new").all()
            generated = generate_blueprint_lessons(session, "en_new", units)
            self.assertEqual(len(generated), 15)

            # All lessons unpublished — production safeguard
            for gl in generated:
                self.assertFalse(
                    gl.is_published,
                    f"Lesson {gl.lesson_id} must be unpublished (provisional content requires verification)",
                )

            # Checkpoint lessons flagged
            checkpoint_lessons = [gl for gl in generated if gl.is_checkpoint]
            self.assertEqual(len(checkpoint_lessons), 5)
            for gl in checkpoint_lessons:
                # lesson_id format: en_new_u<unit_seq>_l<lesson_seq_in_unit>
                parts = gl.lesson_id.split("_")
                # parts: ["en", "new", "u<N>", "l<M>"]
                unit_seq = int(parts[2][1:])
                lesson_seq = int(parts[3][1:])
                pn = _plan_lesson_for_unit_seq(unit_seq, lesson_seq)
                self.assertIn(pn, CHECKPOINT_LESSONS)

            # Only supported exercise types are generated
            populated_by_type = Counter()
            for gl in generated:
                for ex in gl.exercises:
                    self.assertIn(ex.exercise_type, SUPPORTED_EXERCISE_TYPES)
                    populated_by_type[ex.exercise_type] += 1
                    display_options = ex.options or ex.word_tiles or []
                    devanagari = [o["text"] for o in display_options if o.get("is_devanagari")]
                    self.assertEqual(len(devanagari), len(set(devanagari)))
            # Stage 8: all 7 exercise types with counts from EXERCISE_SEQUENCES
            self.assertEqual(populated_by_type["matchWords"], 19)
            self.assertEqual(populated_by_type["fillBlank"], 35)
            self.assertEqual(populated_by_type["translate"], 15)
            self.assertEqual(populated_by_type["pictureToWord"], 15)
            self.assertEqual(populated_by_type["wordToPicture"], 10)
            self.assertEqual(populated_by_type["wordOrder"], 11)
            self.assertEqual(populated_by_type["dialogueComplete"], 6)
            total = sum(populated_by_type.values())
            self.assertEqual(total, 111)
            for gl in generated:
                for ex in gl.exercises:
                    if ex.exercise_type == "translate":
                        self.assertEqual(len(ex.word_tiles), 4)
                        self.assertEqual(len(ex.correct_answer_config["correct_sequence"]), 1)
                        self.assertTrue(all(tile["romanization"] for tile in ex.word_tiles))

        finally:
            session.close()

    def test_seed_blueprint_idempotent(self):
        session = make_session()
        try:
            seed_minimal_course(session)
            import_vocabulary(session, XLSX_PATH)
            units = session.query(Unit).filter(Unit.course_id == "en_new").all()

            report1 = seed_blueprint(session, course_id="en_new")
            self.assertEqual(report1["total_lessons"], 15)
            self.assertEqual(report1["lessons_created"], 15)
            self.assertEqual(report1["lessons_existed"], 0)
            # Stage 8: all 111 exercise slots populated across 7 exercise types
            self.assertEqual(report1["total_created_exercises"], 111)
            self.assertEqual(session.query(Lesson).filter(Lesson.id.like("en_new_%")).count(), 15)

            # Re-run: no new lessons or exercises
            report2 = seed_blueprint(session, course_id="en_new")
            self.assertEqual(report2["lessons_created"], 0)
            self.assertEqual(report2["lessons_existed"], 15)
            self.assertEqual(report2["exercises_created"], 0)
            self.assertEqual(report2["exercises_existed"], report1["total_created_exercises"])
            self.assertEqual(session.query(Lesson).filter(Lesson.id.like("en_new_%")).count(), 15)

        finally:
            session.close()

    def test_seed_preserves_published_and_verified_lesson_content(self):
        session = make_session()
        try:
            seed_minimal_course(session)
            import_vocabulary(session, XLSX_PATH)
            units = session.query(Unit).filter(Unit.course_id == "en_new").all()
            seed_blueprint(session, course_id="en_new")
            lesson = session.get(Lesson, "en_new_u1_l1")
            exercise = session.query(Exercise).filter_by(
                lesson_id=lesson.id
            ).first()
            lesson.title = "Native-reviewed title"
            lesson.is_published = True
            lesson.vocabulary_verified = True
            exercise.instruction = "Native-reviewed instruction"
            session.commit()

            report = seed_blueprint(session, course_id="en_new")

            self.assertEqual(report["exercises_created"], 0)
            # Lesson 1 has 5 planned exercises (EXERCISE_SEQUENCES[1])
            self.assertEqual(session.query(Exercise).filter_by(
                lesson_id=lesson.id
            ).count(), 5)
            self.assertEqual(lesson.title, "Native-reviewed title")
            self.assertTrue(lesson.is_published)
            self.assertTrue(lesson.vocabulary_verified)
            self.assertEqual(exercise.instruction, "Native-reviewed instruction")
        finally:
            session.close()

    def test_lesson_ids_do_not_collide_with_legacy(self):
        session = make_session()
        try:
            seed_minimal_course(session)
            import_vocabulary(session, XLSX_PATH)
            units = session.query(Unit).filter(Unit.course_id == "en_new").all()
            seed_blueprint(session, course_id="en_new")

            new_ids = {l.id for l in session.query(Lesson).filter(Lesson.id.like("en_new_%")).all()}
            self.assertEqual(len(new_ids), 15)
            for lid in new_ids:
                self.assertFalse(lid.startswith("lesson_"))
                self.assertTrue(lid.startswith("en_new_u"))

        finally:
            session.close()

    def test_vocabulary_links_created(self):
        session = make_session()
        try:
            seed_minimal_course(session)
            import_vocabulary(session, XLSX_PATH)
            units = session.query(Unit).filter(Unit.course_id == "en_new").all()
            seed_blueprint(session, course_id="en_new")

            links = session.query(LessonVocabulary).all()
            self.assertGreater(len(links), 0)
            for link in links:
                self.assertIsNotNone(session.get(Lesson, link.lesson_id))
                self.assertIsNotNone(session.get(VocabularyEntry, link.vocabulary_entry_id))
                self.assertIn(link.role, ("introduced", "reviewed"))

        finally:
            session.close()

    def test_first_introduction_unit_matches_workbook(self):
        """Lesson 1 introduces Greetings words whose first lesson number is 1."""
        session = make_session()
        try:
            seed_minimal_course(session)
            import_vocabulary(session, XLSX_PATH)
            introduced, reviewed = vocabulary_for_lesson(session, 1)
            self.assertGreater(len(introduced), 0)
            greetings_words = {
                "Hello", "Thank you", "Yes", "No", "Good", "Well / fine",
            }
            for pair in introduced:
                self.assertIn(pair.english_meaning, greetings_words)

        finally:
            session.close()

    def test_no_published_content(self):
        session = make_session()
        try:
            seed_minimal_course(session)
            import_vocabulary(session, XLSX_PATH)
            units = session.query(Unit).filter(Unit.course_id == "en_new").all()
            seed_blueprint(session, course_id="en_new")

            published = session.query(Lesson).filter(
                Lesson.id.like("en_new_%"), Lesson.is_published == True,  # noqa: E712
            ).count()
            self.assertEqual(published, 0)

        finally:
            session.close()

    def test_legacy_lessons_preserved(self):
        session = make_session()
        try:
            # Create legacy lessons directly (simulating pre-existing data)
            session.add(Unit(id=999, course_id="new_en", sequence=0,
                             title="Legacy Unit", description="Legacy"))
            session.commit()
            session.add(Lesson(
                id="lesson_1", unit_id=999, sequence=1,
                title="Rice and Bread", subtitle="Match · 4 words",
                exercise_type="matchWords", xp_reward=20, word_count=4,
                required_level=1, is_published=False,
            ))
            session.add(Exercise(
                id="mw_1", lesson_id="lesson_1", exercise_type="matchWords",
                instruction="Match the words", options=[], sequence=1,
            ))
            session.commit()

            seed_minimal_course(session)
            import_vocabulary(session, XLSX_PATH)
            units = session.query(Unit).filter(Unit.course_id == "en_new").all()
            seed_blueprint(session, course_id="en_new")

            # Legacy lesson still exists
            self.assertIsNotNone(session.get(Lesson, "lesson_1"))
            self.assertIsNotNone(session.get(Exercise, "mw_1"))

            # New lessons don't collide
            self.assertEqual(session.query(Lesson).filter(Lesson.id.like("en_new_%")).count(), 15)

        finally:
            session.close()


if __name__ == "__main__":
    unittest.main()
