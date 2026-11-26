"""Development vs production content-environment isolation tests.

The provisional English->Newari curriculum must be playable only while
GLOSSA_CONTENT_ENVIRONMENT=development (the isolated docker-compose.dev.yml
stack). Under the normal production configuration the same lesson rows stay
unpublished, unplayable and not publication-ready.
"""

from __future__ import annotations

import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import content_environment, development_content_enabled, settings
from app.curriculum_blueprint import EXERCISE_SEQUENCES, SUPPORTED_ILLUSTRATION_KEYS
from app.database import Base
from app.main import (
    app,
    current_user,
    db_session,
    is_lesson_publication_ready,
    is_lesson_structurally_ready,
    lesson_is_playable,
    lesson_publication_status,
)
from app.models import Course, Exercise, Language, Lesson, Unit, User

LESSON_ID = "en_new_u1_l1"
INCOMPLETE_LESSON_ID = "en_new_u1_l2"


def _match_words(exercise_id: str, sequence: int) -> Exercise:
    options = []
    pairs = {}
    for index in (1, 2):
        dev_id = f"{exercise_id}_d{index}"
        eng_id = f"{exercise_id}_e{index}"
        options.append({
            "id": dev_id, "text": f"नेपाली शब्द{index}",
            "is_devanagari": True, "romanization": f"shabd{index}",
        })
        options.append({"id": eng_id, "text": f"english word {index}"})
        pairs[dev_id] = eng_id
    return Exercise(
        id=exercise_id, lesson_id=LESSON_ID, exercise_type="matchWords",
        instruction="Match the words", sequence=sequence,
        options=options, pairs=pairs, correct_answer_config={"pairs": pairs},
    )


def _fill_blank(exercise_id: str, sequence: int) -> Exercise:
    options = [
        {"id": f"{exercise_id}_a", "text": "नेपाली", "is_devanagari": True,
         "romanization": "nepali"},
        {"id": f"{exercise_id}_d1", "text": "अर्को", "is_devanagari": True,
         "romanization": "arko"},
    ]
    return Exercise(
        id=exercise_id, lesson_id=LESSON_ID, exercise_type="fillBlank",
        instruction="Fill in the blank", prompt="___ (Nepali)", sequence=sequence,
        options=options, answer_id=f"{exercise_id}_a",
        correct_answer_config={"correct_option_id": f"{exercise_id}_a"},
        newari_script="नेपाली", romanization="nepali",
    )


def _picture_to_word(exercise_id: str, sequence: int, image_key: str) -> Exercise:
    options = [
        {"id": f"{exercise_id}_a", "text": "नमस्ते", "is_devanagari": True,
         "romanization": "namaste"},
        {"id": f"{exercise_id}_d1", "text": "धन्यवाद", "is_devanagari": True,
         "romanization": "dhanyabaad"},
    ]
    return Exercise(
        id=exercise_id, lesson_id=LESSON_ID, exercise_type="pictureToWord",
        instruction="Choose the picture", sequence=sequence,
        options=options, answer_id=f"{exercise_id}_a",
        correct_answer_config={"correct_option_id": f"{exercise_id}_a"},
        image_key=image_key,
    )


def build_planned_exercises(lesson_id: str) -> list[Exercise]:
    """Build structurally valid exercises for every planned slot of lesson 1."""
    image_key = sorted(SUPPORTED_ILLUSTRATION_KEYS)[0]
    builders = {"matchWords": _match_words, "fillBlank": _fill_blank}
    exercises = []
    for sequence, exercise_type in enumerate(EXERCISE_SEQUENCES[1], start=1):
        exercise_id = f"{lesson_id}_{exercise_type}{sequence}"
        if exercise_type == "pictureToWord":
            exercises.append(_picture_to_word(exercise_id, sequence, image_key))
        else:
            exercises.append(builders[exercise_type](exercise_id, sequence))
    return exercises


class ContentEnvironmentTestCase(unittest.TestCase):
    """Shared in-memory curriculum fixture."""

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
                Language(id="new", name_english="Newari", name_native="Newari", script="Devanagari"),
                Course(
                    id="en_new", source_language_id="en", target_language_id="new",
                    name="English to Newari", description="Fixture course",
                    is_published=True, is_active=True,
                ),
            ])
            db.flush()
            units = []
            for unit_number in range(1, 6):
                unit = Unit(
                    course_id="en_new", sequence=unit_number,
                    title=f"Unit {unit_number}", description="Fixture unit",
                )
                db.add(unit)
                units.append(unit)
            db.flush()
            for unit_number, unit in enumerate(units, start=1):
                for position in range(1, 4):
                    db.add(Lesson(
                        id=f"en_new_u{unit_number}_l{position}",
                        unit_id=unit.id, sequence=position,
                        title=f"Lesson {(unit_number - 1) * 3 + position}",
                        subtitle="Fixture lesson", exercise_type="matchWords",
                        xp_reward=20, word_count=4, required_level=1,
                        is_published=False,
                        is_checkpoint=position == 3,
                        passing_score=80 if position == 3 else 100,
                    ))
            db.add(Lesson(
                id="legacy_lesson", unit_id=units[0].id, sequence=9,
                title="Legacy lesson", subtitle="Not in the blueprint",
                exercise_type="matchWords", xp_reward=20, word_count=1,
                required_level=1, is_published=False,
            ))
            db.add_all(build_planned_exercises(LESSON_ID))
            db.add(Exercise(
                id=f"{INCOMPLETE_LESSON_ID}_matchWords1",
                lesson_id=INCOMPLETE_LESSON_ID, exercise_type="matchWords",
                instruction="Match the words", sequence=1,
                options=[
                    {"id": "incomplete_d1", "text": "पहिलो", "is_devanagari": True,
                     "romanization": "pahilo"},
                    {"id": "incomplete_e1", "text": "first"},
                    {"id": "incomplete_d2", "text": "दोस्रो", "is_devanagari": True,
                     "romanization": "dosro"},
                    {"id": "incomplete_e2", "text": "second"},
                ],
                pairs={"incomplete_d1": "incomplete_e1",
                       "incomplete_d2": "incomplete_e2"},
                correct_answer_config={
                    "pairs": {"incomplete_d1": "incomplete_e1",
                              "incomplete_d2": "incomplete_e2"}
                },
            ))
            self.user = User(
                id=1, name="Fixture learner", email="environment@example.test",
                password_hash="unused", active_course_id="en_new",
            )
            db.add(self.user)
            db.commit()

        self.original_environment = settings.content_environment
        app.dependency_overrides[db_session] = self._db_override
        app.dependency_overrides[current_user] = lambda: self.user
        self.client = TestClient(app)

    def tearDown(self):
        self.client.close()
        app.dependency_overrides.pop(db_session, None)
        app.dependency_overrides.pop(current_user, None)
        settings.content_environment = self.original_environment
        self.engine.dispose()

    def _db_override(self):
        db = self.Session()
        try:
            yield db
        finally:
            db.close()

    def _set_environment(self, value: str):
        settings.content_environment = value


class TestProductionConfiguration(ContentEnvironmentTestCase):
    """Normal configuration: provisional development content stays locked."""

    def test_default_environment_is_production(self):
        self._set_environment("production")
        self.assertEqual(content_environment(), "production")
        self.assertFalse(development_content_enabled())

    def test_unknown_environment_fails_closed(self):
        for value in ("staging", "", "DEVELOPMENT-PREVIEW", None):
            self._set_environment(value)
            self.assertEqual(
                content_environment(), "production",
                f"{value!r} must fail closed to production",
            )
        self.assertFalse(development_content_enabled())

    def test_unpublished_blueprint_lesson_is_not_playable(self):
        self._set_environment("production")
        with self.Session() as db:
            lesson = db.get(Lesson, LESSON_ID)
            self.assertTrue(is_lesson_structurally_ready(db, lesson))
            self.assertFalse(lesson_is_playable(db, lesson))
            self.assertFalse(is_lesson_publication_ready(db, lesson))

    def test_api_rejects_provisional_lessons(self):
        self._set_environment("production")
        self.assertEqual(self.client.get("/api/v1/lessons").json(), [])
        self.assertEqual(
            self.client.get(f"/api/v1/lessons/{LESSON_ID}/exercises").status_code,
            403,
        )
        self.assertEqual(
            self.client.post(
                f"/api/v1/lessons/{LESSON_ID}/attempts",
                json={"answers": [{"exercise_id": "x", "selected_option_id": "y"}]},
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.post(
                f"/api/v1/lessons/{LESSON_ID}/answer",
                json={"exercise_id": f"{LESSON_ID}_fillBlank2",
                      "selected_option_id": f"{LESSON_ID}_fillBlank2_a"},
            ).status_code,
            403,
        )
        town_map = self.client.get("/api/v1/courses/en_new/town-map").json()
        row = next(item for item in town_map if item["id"] == LESSON_ID)
        self.assertEqual(row["availability"], "unavailable")

    def test_published_but_unverified_lesson_is_not_publication_ready(self):
        self._set_environment("production")
        with self.Session() as db:
            lesson = db.get(Lesson, LESSON_ID)
            lesson.is_published = True
            db.commit()
            db.refresh(lesson)
            self.assertFalse(is_lesson_publication_ready(db, lesson))
            status = lesson_publication_status(db, lesson)
            self.assertFalse(status["publication_ready"])
            self.assertIn("vocabulary_not_verified", status["blockers"])

    def test_health_reports_production_environment(self):
        self._set_environment("production")
        payload = self.client.get("/health").json()
        self.assertEqual(payload["content_environment"], "production")
        self.assertFalse(payload["provisional_content"])
        self.assertNotIn("notice", payload)


class TestDevelopmentConfiguration(ContentEnvironmentTestCase):
    """Isolated development environment: provisional curriculum is playable."""

    def test_development_environment_is_active(self):
        self._set_environment("development")
        self.assertEqual(content_environment(), "development")
        self.assertTrue(development_content_enabled())

    def test_structurally_complete_blueprint_lesson_is_playable(self):
        self._set_environment("development")
        with self.Session() as db:
            lesson = db.get(Lesson, LESSON_ID)
            self.assertFalse(lesson.is_published)
            self.assertFalse(is_lesson_publication_ready(db, lesson))
            self.assertTrue(lesson_is_playable(db, lesson))

    def test_api_serves_provisional_curriculum(self):
        self._set_environment("development")
        lessons = self.client.get("/api/v1/lessons").json()
        self.assertEqual(len(lessons), 1)
        self.assertEqual(lessons[0]["id"], LESSON_ID)
        self.assertEqual(lessons[0]["availability"], "available")
        self.assertEqual(lessons[0]["planned_exercise_count"], 5)
        self.assertEqual(lessons[0]["populated_exercise_count"], 5)
        self.assertTrue(lessons[0]["provisional"])

        exercises = self.client.get(f"/api/v1/lessons/{LESSON_ID}/exercises").json()
        self.assertEqual(len(exercises), 5)

        answers = [
            {"exercise_id": f"{LESSON_ID}_matchWords1",
             "selected_pairs": {f"{LESSON_ID}_matchWords1_d1": f"{LESSON_ID}_matchWords1_e1",
                                f"{LESSON_ID}_matchWords1_d2": f"{LESSON_ID}_matchWords1_e2"}},
            {"exercise_id": f"{LESSON_ID}_fillBlank2",
             "selected_option_id": f"{LESSON_ID}_fillBlank2_a"},
            {"exercise_id": f"{LESSON_ID}_matchWords3",
             "selected_pairs": {f"{LESSON_ID}_matchWords3_d1": f"{LESSON_ID}_matchWords3_e1",
                                f"{LESSON_ID}_matchWords3_d2": f"{LESSON_ID}_matchWords3_e2"}},
            {"exercise_id": f"{LESSON_ID}_fillBlank4",
             "selected_option_id": f"{LESSON_ID}_fillBlank4_a"},
            {"exercise_id": f"{LESSON_ID}_pictureToWord5",
             "selected_option_id": f"{LESSON_ID}_pictureToWord5_a"},
        ]
        attempt = self.client.post(
            f"/api/v1/lessons/{LESSON_ID}/attempts",
            json={"answers": answers, "idempotency_key": "dev-environment-fixture"},
        )
        self.assertEqual(attempt.status_code, 200, attempt.text)
        self.assertTrue(attempt.json()["passed"])
        self.assertEqual(attempt.json()["xp_earned"], 20)

    def test_incomplete_lesson_stays_locked_in_development(self):
        self._set_environment("development")
        with self.Session() as db:
            lesson = db.get(Lesson, INCOMPLETE_LESSON_ID)
            self.assertFalse(is_lesson_structurally_ready(db, lesson))
            self.assertFalse(lesson_is_playable(db, lesson))
        self.assertEqual(
            self.client.get(
                f"/api/v1/lessons/{INCOMPLETE_LESSON_ID}/exercises"
            ).status_code,
            403,
        )
        lessons = self.client.get("/api/v1/lessons").json()
        self.assertNotIn(INCOMPLETE_LESSON_ID, [lesson["id"] for lesson in lessons])

    def test_non_blueprint_lesson_stays_locked_in_development(self):
        self._set_environment("development")
        with self.Session() as db:
            self.assertFalse(lesson_is_playable(db, db.get(Lesson, "legacy_lesson")))

    def test_health_reports_development_environment(self):
        self._set_environment("development")
        payload = self.client.get("/health").json()
        self.assertEqual(payload["content_environment"], "development")
        self.assertTrue(payload["provisional_content"])
        self.assertIn("provisional", payload["notice"].lower())
        self.assertIn("unverified", payload["notice"].lower())


if __name__ == "__main__":
    unittest.main()
