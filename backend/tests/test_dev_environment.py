"""Verify provisional curriculum isolation and publication safeguards."""

import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import content_environment, development_content_enabled, settings
from app.curriculum_blueprint import seed_curriculum
from app.database import Base
from app.main import (
    DEVELOPMENT_CONTENT_NOTICE,
    app,
    current_user,
    db_session,
    is_lesson_publication_ready,
    is_lesson_structurally_ready,
    lesson_is_playable,
)
from app.models import Course, Language, Lesson, User


class TestContentEnvironment(unittest.TestCase):
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
                ]
            )
            db.flush()
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
            db.flush()
            seed_curriculum(db)
            self.user = User(
                id=1,
                name="Fixture learner",
                email="environment@example.test",
                password_hash="unused",
                active_course_id="en_new",
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

    def test_unknown_content_environment_fails_closed(self):
        for value in ("staging", "", "DEVELOPMENT-PREVIEW", None):
            settings.content_environment = value
            self.assertEqual(content_environment(), "production")
            self.assertFalse(development_content_enabled())

    def test_development_serves_complete_unpublished_content(self):
        settings.content_environment = "development"
        with self.Session() as db:
            lesson = db.get(Lesson, "L01")
            self.assertTrue(is_lesson_structurally_ready(db, lesson))
            self.assertFalse(is_lesson_publication_ready(db, lesson))
            self.assertTrue(lesson_is_playable(db, lesson))

        health = self.client.get("/health")
        self.assertEqual(health.status_code, 200)
        self.assertEqual(health.json()["content_environment"], "development")
        self.assertEqual(health.json()["notice"], DEVELOPMENT_CONTENT_NOTICE)
        response = self.client.get("/api/v1/lessons/L01/exercises")
        self.assertEqual(response.status_code, 200, response.text)
        exercises = response.json()
        self.assertEqual(len(exercises), 10)
        self.assertTrue(all(exercise["audio_key"] is None for exercise in exercises))
        self.assertTrue(
            all(
                "answer_id" not in exercise
                and "correct_answer_config" not in exercise
                for exercise in exercises
            )
        )

    def test_production_keeps_unpublished_curriculum_unplayable(self):
        settings.content_environment = "production"
        with self.Session() as db:
            lesson = db.get(Lesson, "L01")
            self.assertFalse(lesson_is_playable(db, lesson))

        response = self.client.get("/api/v1/lessons/L01/exercises")
        self.assertEqual(response.status_code, 403)
        town = self.client.get("/api/v1/courses/en_new/town-map")
        self.assertEqual(town.status_code, 200)
        rows = {lesson["id"]: lesson for lesson in town.json()}
        self.assertEqual(len(rows), 15)
        self.assertEqual(rows["L01"]["availability"], "unavailable")
        self.assertFalse(rows["L01"]["is_published"])


if __name__ == "__main__":
    unittest.main()
