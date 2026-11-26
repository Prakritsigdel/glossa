"""Opt-in concurrent HTTP reward tests for an isolated PostgreSQL database.

Run with GLOSSA_TEST_POSTGRES_URL set to a disposable database whose schema
is at the current Alembic head. The guard deliberately rejects the main DB.
"""

import os
import threading
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

TEST_URL = os.getenv("GLOSSA_TEST_POSTGRES_URL", "")
if TEST_URL:
    if not TEST_URL.rsplit("/", 1)[-1].startswith("glossa_migration_verify"):
        raise RuntimeError("PostgreSQL concurrency tests require glossa_migration_verify")
    os.environ["DATABASE_URL"] = TEST_URL
    os.environ["JWT_SECRET"] = "stage6-isolated-postgres-test-secret"

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import sessionmaker

from app import database as database_module
from app import main as main_module
from app.config import settings
from app.main import app
from app.models import Attempt, Exercise, Lesson, LessonCompletion, Unit, User
from app.security import create_token

if TEST_URL and database_module.engine.url.get_backend_name() != "postgresql":
    # Another test module may have imported the application before this
    # module set DATABASE_URL, leaving the cached engine bound to the legacy
    # SQLite file. Rebind settings, the engine and both session factories to
    # the isolated PostgreSQL URL so these tests can never touch
    # backend/glossa.db, whatever the collection order is.
    settings.database_url = TEST_URL
    settings.jwt_secret = "stage6-isolated-postgres-test-secret"
    database_module.engine = create_engine(TEST_URL, pool_pre_ping=True)
    _session_factory = sessionmaker(
        bind=database_module.engine, autoflush=False, expire_on_commit=False
    )
    database_module.SessionLocal = _session_factory
    main_module.SessionLocal = _session_factory

SessionLocal = database_module.SessionLocal


@unittest.skipUnless(TEST_URL, "Set GLOSSA_TEST_POSTGRES_URL to run isolated PostgreSQL HTTP concurrency tests")
class TestPostgresConcurrentCompletionHTTP(unittest.TestCase):
    lesson_id = "en_new_u1_l1"

    def setUp(self):
        self.db = SessionLocal()
        self.user = User(
            name="Stage 6 concurrency fixture",
            email=f"stage6-{uuid.uuid4().hex}@example.com",
            password_hash="unused-test-fixture",
            active_course_id="en_new",
        )
        self.lesson = self.db.get(Lesson, self.lesson_id)
        self.assertIsNotNone(self.lesson)
        self.original_published = self.lesson.is_published
        self.other_lesson = self.db.get(Lesson, "en_new_u1_l2")
        self.original_other_published = self.other_lesson.is_published
        self.lesson.is_published = True  # Published only in the isolated test clone.
        self.lesson.is_checkpoint = False
        self.lesson.passing_score = 100
        self.db.add(self.user)
        self.db.commit()
        self.db.refresh(self.user)
        self.token = create_token(self.user.id)
        self.answers = []
        for exercise in self.db.scalars(
            select(Exercise).where(Exercise.lesson_id == self.lesson_id).order_by(Exercise.sequence)
        ):
            if exercise.exercise_type == "matchWords":
                answer = {"exercise_id": exercise.id, "selected_pairs": exercise.pairs}
            elif exercise.exercise_type in ("translate", "wordOrder"):
                answer = {"exercise_id": exercise.id, "selected_tile_ids": exercise.correct_answer_config["correct_tile_ids"]}
            else:
                answer = {"exercise_id": exercise.id, "selected_option_id": exercise.answer_id}
            self.answers.append(answer)
        self.assertTrue(self.answers)

    def tearDown(self):
        for user in self.db.scalars(select(User).where(User.email.like("stage6-%@example.com"))).all():
            self.db.query(LessonCompletion).filter_by(user_id=user.id).delete()
            self.db.query(Attempt).filter_by(user_id=user.id).delete()
            self.db.delete(user)
        self.lesson.is_published = self.original_published
        self.other_lesson.is_published = self.original_other_published
        self.lesson.is_checkpoint = False
        self.lesson.passing_score = 100
        self.db.commit()
        self.db.close()

    def _submit(self, lesson_id, answers, key, token=None):
        with TestClient(app) as client:
            return client.post(
                f"/api/v1/lessons/{lesson_id}/attempts",
                headers={"Authorization": f"Bearer {token or self.token}"},
                json={"answers": answers, "idempotency_key": key},
            )

    def _answers_for_lesson(self, lesson_id):
        answers = []
        for exercise in self.db.scalars(
            select(Exercise).where(Exercise.lesson_id == lesson_id).order_by(Exercise.sequence)
        ):
            if exercise.exercise_type == "matchWords":
                answer = {"exercise_id": exercise.id, "selected_pairs": exercise.pairs}
            elif exercise.exercise_type in ("translate", "wordOrder"):
                answer = {"exercise_id": exercise.id, "selected_tile_ids": exercise.correct_answer_config["correct_tile_ids"]}
            else:
                answer = {"exercise_id": exercise.id, "selected_option_id": exercise.answer_id}
            answers.append(answer)
        return answers

    def _submit_concurrently(self, keys):
        barrier = threading.Barrier(2)

        def send(key):
            with TestClient(app) as client:
                barrier.wait(timeout=10)
                return client.post(
                    f"/api/v1/lessons/{self.lesson_id}/attempts",
                    headers={"Authorization": f"Bearer {self.token}"},
                    json={"answers": self.answers, "idempotency_key": key},
                )

        with ThreadPoolExecutor(max_workers=2) as pool:
            return list(pool.map(send, keys))

    def _assert_single_reward(self, attempt_count):
        self.db.expire_all()
        user = self.db.get(User, self.user.id)
        self.assertEqual(user.xp, self.lesson.xp_reward)
        self.assertEqual(
            self.db.query(LessonCompletion).filter_by(user_id=user.id, lesson_id=self.lesson_id).count(),
            1,
        )
        self.assertEqual(
            self.db.query(Attempt).filter_by(user_id=user.id, lesson_id=self.lesson_id).count(),
            attempt_count,
        )

    def test_same_idempotency_key_concurrent_http_requests(self):
        key = uuid.uuid4().hex
        responses = self._submit_concurrently([key, key])
        self.assertEqual([response.status_code for response in responses], [200, 200])
        self._assert_single_reward(1)

    def test_different_keys_concurrent_http_requests(self):
        responses = self._submit_concurrently([uuid.uuid4().hex, uuid.uuid4().hex])
        self.assertEqual([response.status_code for response in responses], [200, 200])
        self._assert_single_reward(2)

    def test_same_key_with_different_answers_is_rejected(self):
        key = uuid.uuid4().hex
        first = self._submit(self.lesson_id, self.answers, key)
        self.assertEqual(first.status_code, 200)
        changed = [dict(answer) for answer in self.answers]
        fill_answer = next(answer for answer in changed if "selected_option_id" in answer)
        exercise = self.db.get(Exercise, fill_answer["exercise_id"])
        fill_answer["selected_option_id"] = next(
            option["id"] for option in exercise.options
            if option["id"] != exercise.answer_id
        )
        conflict = self._submit(self.lesson_id, changed, key)
        self.assertEqual(conflict.status_code, 409)
        self._assert_single_reward(1)

    def test_same_key_for_another_unlocked_lesson_is_rejected(self):
        key = uuid.uuid4().hex
        first = self._submit(self.lesson_id, self.answers, key)
        self.assertEqual(first.status_code, 200)
        self.other_lesson.is_published = True
        self.db.commit()
        other_answers = self._answers_for_lesson(self.other_lesson.id)
        self.assertTrue(other_answers)
        conflict = self._submit(self.other_lesson.id, other_answers, key)
        self.assertEqual(conflict.status_code, 409)
        self.assertEqual(
            self.db.query(Attempt).filter_by(user_id=self.user.id, lesson_id=self.other_lesson.id).count(),
            0,
        )

    def test_same_key_is_scoped_to_different_users(self):
        key = uuid.uuid4().hex
        first = self._submit(self.lesson_id, self.answers, key)
        self.assertEqual(first.status_code, 200)
        second_user = User(
            name="Stage 6 second fixture",
            email=f"stage6-{uuid.uuid4().hex}@example.com",
            password_hash="unused-test-fixture",
            active_course_id="en_new",
        )
        self.db.add(second_user)
        self.db.commit()
        self.db.refresh(second_user)
        response = self._submit(
            self.lesson_id, self.answers, key, token=create_token(second_user.id)
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["xp_earned"], self.lesson.xp_reward)
        self.db.expire_all()
        self.assertEqual(self.db.get(User, second_user.id).xp, self.lesson.xp_reward)

    def test_retry_after_success_returns_the_committed_result(self):
        key = uuid.uuid4().hex
        first = self._submit(self.lesson_id, self.answers, key)
        second = self._submit(self.lesson_id, self.answers, key)
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.json()["attempt_number"], first.json()["attempt_number"])
        self.assertEqual(second.json()["xp_earned"], first.json()["xp_earned"])
        self.assertTrue(second.json()["already_completed"])
        self._assert_single_reward(1)

    def test_reward_failure_rolls_back_user_attempt_and_completion(self):
        def fail_completion_insert(mapper, connection, target):
            raise RuntimeError("forced isolated reward failure")

        event.listen(LessonCompletion, "before_insert", fail_completion_insert)
        try:
            with TestClient(app, raise_server_exceptions=False) as client:
                response = client.post(
                    f"/api/v1/lessons/{self.lesson_id}/attempts",
                    headers={"Authorization": f"Bearer {self.token}"},
                    json={"answers": self.answers, "idempotency_key": uuid.uuid4().hex},
                )
            self.assertEqual(response.status_code, 500)
            self.db.expire_all()
            self.assertEqual(self.db.get(User, self.user.id).xp, 0)
            self.assertEqual(self.db.query(Attempt).filter_by(user_id=self.user.id).count(), 0)
            self.assertEqual(self.db.query(LessonCompletion).filter_by(user_id=self.user.id).count(), 0)
        finally:
            event.remove(LessonCompletion, "before_insert", fail_completion_insert)

    def test_concurrent_completed_practice_and_next_lesson_do_not_lose_xp(self):
        self.other_lesson.is_published = True
        self.db.add(LessonCompletion(
            user_id=self.user.id, lesson_id=self.lesson_id, score=1.0,
            passed=True, xp_earned=0, correct_answers=5, total_questions=5,
        ))
        self.user.xp = 100
        self.db.commit()
        other_answers = self._answers_for_lesson(self.other_lesson.id)
        barrier = threading.Barrier(2)

        def send(lesson_id, answers, key):
            with TestClient(app) as client:
                barrier.wait(timeout=10)
                return client.post(
                    f"/api/v1/lessons/{lesson_id}/attempts",
                    headers={"Authorization": f"Bearer {self.token}"},
                    json={"answers": answers, "idempotency_key": key},
                )

        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(send, self.lesson_id, self.answers, uuid.uuid4().hex)
            second = pool.submit(send, self.other_lesson.id, other_answers, uuid.uuid4().hex)
            responses = [first.result(), second.result()]
        self.assertEqual([response.status_code for response in responses], [200, 200])
        self.db.expire_all()
        self.assertEqual(self.db.get(User, self.user.id).xp, 120)
        self.assertEqual(
            self.db.query(LessonCompletion).filter_by(user_id=self.user.id).count(),
            2,
        )

    def test_server_xp_level_hero_and_profile_remain_consistent(self):
        self.user.xp = 290
        self.user.level = 2
        self.user.hero_index = 1
        self.user.hero_class_name = "Traveler"
        self.db.commit()
        response = self._submit(self.lesson_id, self.answers, uuid.uuid4().hex)
        self.assertEqual(response.status_code, 200)
        self.db.expire_all()
        updated = self.db.get(User, self.user.id)
        self.assertEqual(updated.xp, 310)
        self.assertEqual(updated.level, 3)
        self.assertEqual(updated.hero_class_name, "Speaker")
        self.assertEqual(updated.hero_index, 1)
        with TestClient(app) as client:
            profile = client.get(
                "/api/v1/me", headers={"Authorization": f"Bearer {self.token}"}
            )
            leaderboard = client.get(
                "/api/v1/leaderboard?filter=alltime",
                headers={"Authorization": f"Bearer {self.token}"},
            )
        self.assertEqual(profile.status_code, 200)
        self.assertEqual(profile.json()["xp"], 310)
        self.assertEqual(profile.json()["level"], 3)
        self.assertEqual(leaderboard.status_code, 200)
        self.assertEqual(
            next(row["xp"] for row in leaderboard.json() if row["is_current_user"]),
            310,
        )

    def test_streak_same_day_consecutive_and_missed_day_policy(self):
        fixed_now = datetime(2025, 6, 15, 12, 0, tzinfo=timezone.utc)

        class FrozenDateTime:
            @classmethod
            def now(cls, tz=None):
                return fixed_now if tz else fixed_now.replace(tzinfo=None)

        scenarios = [
            (fixed_now.date(), 4, 4),
            (fixed_now.date() - timedelta(days=1), 4, 5),
            (fixed_now.date() - timedelta(days=2), 4, 1),
        ]
        for last_date, starting_streak, expected_streak in scenarios:
            with self.subTest(last_date=last_date):
                self.user.last_activity_date = last_date
                self.user.streak = starting_streak
                self.db.commit()
                with patch.object(main_module, "datetime", FrozenDateTime):
                    response = self._submit(
                        self.lesson_id, self.answers, uuid.uuid4().hex
                    )
                self.assertEqual(response.status_code, 200)
                self.db.expire_all()
                self.assertEqual(self.db.get(User, self.user.id).streak, expected_streak)
                self.db.query(LessonCompletion).filter_by(
                    user_id=self.user.id, lesson_id=self.lesson_id
                ).delete()
                self.db.query(Attempt).filter_by(
                    user_id=self.user.id, lesson_id=self.lesson_id
                ).delete()
                self.user.xp = 0
                self.user.level = 1
                self.db.commit()


if __name__ == "__main__":
    unittest.main()
