"""Startup seeding preserves history and creates only the active blueprint."""

import unittest
from pathlib import Path
from unittest.mock import patch

from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import seed as seed_module
from app.curriculum_blueprint import get_curriculum_coverage_report
from app.database import Base
from app.models import Course, Language, Lesson, Unit


class TestStartupSeedCleanup(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, expire_on_commit=False)
        with self.Session() as db:
            db.add_all([
                Language(id="en", name_english="English", name_native="English", script="Latin"),
                Language(id="new", name_english="Newari", name_native="नेपाल भाषा", script="Devanagari"),
                Language(id="ne", name_english="Nepali", name_native="नेपाली", script="Devanagari"),
            ])
            db.flush()
            db.add_all([
                Course(id="en_new", source_language_id="en", target_language_id="new",
                       name="English to Newari", is_published=True, is_active=True),
                Course(id="en_ne", source_language_id="en", target_language_id="ne",
                       name="Retired historical course", is_published=True, is_active=True),
            ])
            db.flush()
            for unit_number in range(1, 11):
                unit = Unit(course_id="en_new", sequence=unit_number,
                            title=f"Historical unit {unit_number}")
                db.add(unit)
                db.flush()
                for lesson_number in range(1, 5):
                    db.add(Lesson(
                        id=f"en_new_u{unit_number}_l{lesson_number}",
                        unit_id=unit.id, sequence=lesson_number,
                        title=f"Historical lesson {unit_number}-{lesson_number}",
                        subtitle="Preserved generated curriculum shell",
                        exercise_type="fillBlank", is_published=False,
                    ))
            db.commit()

    def tearDown(self):
        self.engine.dispose()

    def test_seed_is_idempotent_and_separates_active_blueprint_from_history(self):
        workbook = Path(seed_module.__file__).resolve().parent.parent / "newari_vocabulary.xlsx"
        self.assertTrue(workbook.is_file(), "validated vocabulary workbook must be available")
        with patch.object(seed_module, "SessionLocal", self.Session):
            seed_module.seed()
            seed_module.seed()

        with self.Session() as db:
            courses = list(db.scalars(select(Course)).all())
            active_courses = [course.id for course in courses if course.is_active]
            self.assertEqual(active_courses, ["en_new"])
            self.assertFalse(db.get(Course, "en_ne").is_active)
            self.assertEqual(db.query(Unit).filter_by(course_id="en_new").count(), 10)
            self.assertEqual(db.query(Lesson).filter(Lesson.id.like("en_new_u%_l%")).count(), 40)

            coverage = get_curriculum_coverage_report(db)
            active = coverage["active_blueprint"]
            history = coverage["historical_records"]
            self.assertEqual(active["planned_units"], 5)
            self.assertEqual(active["unit_rows_present"], 5)
            self.assertEqual(active["planned_lessons"], 15)
            self.assertEqual(active["lesson_rows_present"], 15)
            self.assertEqual(active["checkpoints_including_capstone"], 5)
            self.assertEqual(active["planned_exercise_slots"], 111)
            # Stage 8: all 7 exercise types implemented; all 111 slots populated
            self.assertEqual(active["populated_exercise_slots"], 111)
            self.assertEqual(active["missing_exercise_slots"], 0)
            self.assertEqual(active["published_lessons"], 0)
            self.assertEqual(active["imported_vocabulary_entries"], 70)
            self.assertEqual(history["retired_courses"], 1)
            self.assertEqual(history["units"], 5)
            self.assertEqual(history["lessons"], 25)


if __name__ == "__main__":
    unittest.main()
