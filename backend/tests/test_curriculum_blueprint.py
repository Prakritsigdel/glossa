"""Tests for the authoritative JSON curriculum and its idempotent seeder."""

from copy import deepcopy
import unittest

from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.curriculum_blueprint import (
    CURRICULUM_VERSION,
    load_curriculum,
    seed_curriculum,
    validate_curriculum,
)
from app.database import Base
from app.models import Course, Exercise, Language, Lesson, Unit


class TestNewariCurriculum(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
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
                ]
            )
            db.add(
                Course(
                    id="en_new",
                    source_language_id="en",
                    target_language_id="new",
                    name="English to Newari",
                    is_published=True,
                    is_active=True,
                )
            )
            db.commit()

    def tearDown(self):
        self.engine.dispose()

    def test_source_has_expected_dynamic_totals_and_playable_formats(self):
        content = load_curriculum()
        validate_curriculum(content)
        self.assertEqual(len(content["units"]), 5)
        self.assertEqual(len(content["words"]), 70)
        self.assertEqual(len(content["lessons"]), 15)
        self.assertEqual(
            sum(len(lesson["exercises"]) for lesson in content["lessons"]), 162
        )
        self.assertEqual(
            sum(lesson["xp_max"] for lesson in content["lessons"]), 620
        )
        self.assertEqual(
            {
                exercise["type"]
                for lesson in content["lessons"]
                for exercise in lesson["exercises"]
            },
            {"matchWords", "fillBlank", "pictureToWord", "wordToPicture"},
        )
        self.assertEqual(
            sum(lesson["is_checkpoint"] for lesson in content["lessons"]), 5
        )
        self.assertTrue(all(not lesson["is_published"] for lesson in content["lessons"]))

    def test_source_rejects_dangling_words_and_malformed_playable_layouts(self):
        source = load_curriculum()
        invalid_pair = deepcopy(source)
        invalid_pair["lessons"][0]["exercises"][0]["pairs"][0]["word_id"] = (
            "missing-word"
        )
        with self.assertRaisesRegex(ValueError, "unknown pair word"):
            validate_curriculum(invalid_pair)

        missing_blank = deepcopy(source)
        missing_blank["lessons"][0]["exercises"][1]["layout"]["sentence"] = [
            {"text": "No answer slot"}
        ]
        with self.assertRaisesRegex(ValueError, "exactly one blank"):
            validate_curriculum(missing_blank)

        unsupported_picture = deepcopy(source)
        unsupported_picture["lessons"][4]["exercises"][6]["options"][0]["image_key"] = (
            "unknown-image"
        )
        with self.assertRaisesRegex(ValueError, "unsupported illustration"):
            validate_curriculum(unsupported_picture)

    def test_seed_is_idempotent_and_preserves_legacy_rows(self):
        with self.Session() as db:
            legacy_unit = Unit(
                course_id="en_new",
                curriculum_version="legacy",
                sequence=1,
                title="Historical unit",
            )
            db.add(legacy_unit)
            db.flush()
            legacy_lesson = Lesson(
                id="historical_lesson",
                unit_id=legacy_unit.id,
                sequence=1,
                title="Historical lesson",
                subtitle="Do not replace",
                exercise_type="fillBlank",
            )
            db.add(legacy_lesson)
            db.commit()

            first = seed_curriculum(db)
            db.commit()
            second = seed_curriculum(db)
            db.commit()

            self.assertEqual(first["unit_count"], 5)
            self.assertEqual(first["lesson_count"], 15)
            self.assertEqual(first["exercise_count"], 162)
            self.assertEqual(first["word_count"], 70)
            self.assertEqual(first["xp_max"], 620)
            self.assertEqual(first["lessons_created"], 15)
            self.assertEqual(first["exercises_created"], 162)
            self.assertEqual(second["lessons_created"], 0)
            self.assertEqual(second["exercises_created"], 0)
            self.assertEqual(
                db.scalar(
                    select(Lesson.title).where(Lesson.id == "historical_lesson")
                ),
                "Historical lesson",
            )
            active_units = list(
                db.scalars(
                    select(Unit).where(
                        Unit.course_id == "en_new",
                        Unit.curriculum_version == CURRICULUM_VERSION,
                    )
                )
            )
            active_lessons = list(
                db.scalars(
                    select(Lesson)
                    .join(Unit)
                    .where(Unit.curriculum_version == CURRICULUM_VERSION)
                )
            )
            active_exercises = list(
                db.scalars(
                    select(Exercise)
                    .join(Lesson)
                    .join(Unit)
                    .where(Unit.curriculum_version == CURRICULUM_VERSION)
                )
            )
            self.assertEqual(len(active_units), 5)
            self.assertEqual(len(active_lessons), 15)
            self.assertEqual(len(active_exercises), 162)
            self.assertTrue(all(not lesson.is_published for lesson in active_lessons))
            self.assertTrue(
                all(exercise.audio_key is None for exercise in active_exercises)
            )

    def test_seed_refuses_to_overwrite_a_historical_id_collision(self):
        with self.Session() as db:
            legacy_unit = Unit(
                course_id="en_new",
                curriculum_version="legacy",
                sequence=1,
                title="Historical unit",
            )
            db.add(legacy_unit)
            db.flush()
            db.add(
                Lesson(
                    id="L01",
                    unit_id=legacy_unit.id,
                    sequence=1,
                    title="Historical L01",
                    subtitle="Preserve me",
                    exercise_type="fillBlank",
                )
            )
            db.commit()

            with self.assertRaisesRegex(ValueError, "historical content"):
                seed_curriculum(db)
            db.rollback()
            self.assertEqual(db.get(Lesson, "L01").title, "Historical L01")
            self.assertEqual(
                db.scalar(
                    select(Unit.id).where(
                        Unit.curriculum_version == CURRICULUM_VERSION
                    )
                ),
                None,
            )


if __name__ == "__main__":
    unittest.main()
