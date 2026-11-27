"""Startup seeding is idempotent and keeps historical curriculum records."""

import unittest
from unittest.mock import patch

from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import seed as seed_module
from app.curriculum_blueprint import CURRICULUM_VERSION
from app.database import Base
from app.models import Course, Exercise, Language, Lesson, Unit


class TestStartupSeedPreservesHistory(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, expire_on_commit=False)
        with self.Session() as db:
            db.add_all(
                [
                    Language(
                        id="en",
                        name_english="English",
                        name_native="English",
                        script="Latin",
                    ),
                    Language(
                        id="new",
                        name_english="Newari",
                        name_native="Newari",
                        script="Devanagari",
                    ),
                    Language(
                        id="ne",
                        name_english="Nepali",
                        name_native="Nepali",
                        script="Devanagari",
                    ),
                ]
            )
            db.flush()
            db.add_all(
                [
                    Course(
                        id="en_new",
                        source_language_id="en",
                        target_language_id="new",
                        name="Historical course title",
                        is_published=True,
                        is_active=True,
                    ),
                    Course(
                        id="en_ne",
                        source_language_id="en",
                        target_language_id="ne",
                        name="Unrelated course",
                        is_published=True,
                        is_active=True,
                    ),
                ]
            )
            db.flush()
            for unit_number in range(1, 3):
                unit = Unit(
                    course_id="en_new",
                    curriculum_version="legacy",
                    sequence=unit_number,
                    title=f"Historical unit {unit_number}",
                )
                db.add(unit)
                db.flush()
                for lesson_number in range(1, 3):
                    lesson_id = f"old_{unit_number}_{lesson_number}"
                    db.add(
                        Lesson(
                            id=lesson_id,
                            unit_id=unit.id,
                            sequence=lesson_number,
                            title=f"Historical lesson {lesson_id}",
                            subtitle="Preserve",
                            exercise_type="fillBlank",
                        )
                    )
                    db.add(
                        Exercise(
                            id=f"{lesson_id}_exercise",
                            lesson_id=lesson_id,
                            exercise_type="fillBlank",
                            instruction="Historical exercise",
                            options=[],
                        )
                    )
            db.commit()

    def tearDown(self):
        self.engine.dispose()

    def test_seed_adds_new_version_without_replacing_historical_content(self):
        with patch.object(seed_module, "SessionLocal", self.Session):
            seed_module.seed()
            seed_module.seed()

        with self.Session() as db:
            self.assertEqual(
                db.scalar(
                    select(Course.name).where(Course.id == "en_new")
                ),
                "English → Newari",
            )
            self.assertEqual(db.get(Course, "en_ne").name, "Unrelated course")
            self.assertTrue(db.get(Course, "en_ne").is_active)

            old_lessons = list(
                db.scalars(select(Lesson).where(Lesson.id.like("old_%")))
            )
            old_exercises = list(
                db.scalars(
                    select(Exercise)
                    .join(Lesson)
                    .where(Lesson.id.like("old_%"))
                )
            )
            self.assertEqual(len(old_lessons), 4)
            self.assertEqual(len(old_exercises), 4)
            self.assertEqual(old_lessons[0].title, "Historical lesson old_1_1")

            new_units = list(
                db.scalars(
                    select(Unit).where(
                        Unit.course_id == "en_new",
                        Unit.curriculum_version == CURRICULUM_VERSION,
                    )
                )
            )
            new_lessons = list(
                db.scalars(
                    select(Lesson)
                    .join(Unit)
                    .where(Unit.curriculum_version == CURRICULUM_VERSION)
                )
            )
            new_exercises = list(
                db.scalars(
                    select(Exercise)
                    .join(Lesson)
                    .join(Unit)
                    .where(Unit.curriculum_version == CURRICULUM_VERSION)
                )
            )
            self.assertEqual(len(new_units), 5)
            self.assertEqual(len(new_lessons), 15)
            self.assertEqual(len(new_exercises), 162)
            self.assertTrue(all(not lesson.is_published for lesson in new_lessons))


if __name__ == "__main__":
    unittest.main()
