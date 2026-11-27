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
    os.environ["GLOSSA_CONTENT_ENVIRONMENT"] = "development"

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.engine import make_url
from sqlalchemy.orm import sessionmaker

from app import database as database_module
from app import main as main_module
from app.config import settings
from app.main import app
from app.models import (
    Attempt,
    Exercise,
    ExerciseSubmission,
    Lesson,
    LessonCompletion,
    LessonProgress,
    LessonRun,
    Unit,
    User,
)
from app.security import create_token

if TEST_URL and database_module.engine.url != make_url(TEST_URL):
    # Another test module may have imported the application before this
    # module set DATABASE_URL, leaving the cached engine bound to a different
    # database. Rebind settings, the engine and both session factories to the
    # isolated PostgreSQL URL so these tests cannot touch another database,
    # whatever the collection order is.
    settings.database_url = TEST_URL
    settings.jwt_secret = "stage6-isolated-postgres-test-secret"
    settings.content_environment = "development"
    database_module.engine = create_engine(TEST_URL, pool_pre_ping=True)
    _session_factory = sessionmaker(
        bind=database_module.engine, autoflush=False, expire_on_commit=False
    )
    database_module.SessionLocal = _session_factory
    main_module.SessionLocal = _session_factory

SessionLocal = database_module.SessionLocal


@unittest.skipUnless(TEST_URL, "Set GLOSSA_TEST_POSTGRES_URL for PostgreSQL account-isolation tests")
class TestPostgresAccountIsolation(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.db = SessionLocal()
        self.suffix = uuid.uuid4().hex
        self.account_a = self._register("A")
        self.account_b = self._register("B")

    def tearDown(self):
        if hasattr(self, "db"):
            self.db.query(User).filter(
                User.email.like(f"stage6-isolation-{self.suffix}-%@example.com")
            ).delete(synchronize_session=False)
            self.db.commit()
            self.db.close()
        if hasattr(self, "client"):
            self.client.close()

    def _register(self, account):
        response = self.client.post(
            "/api/v1/auth/register",
            json={
                "name": f"Stage 6 isolation {account}",
                "email": f"stage6-isolation-{self.suffix}-{account.lower()}@example.com",
                "password": "valid-test-password",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        result = response.json()
        return {
            "token": result["access_token"],
            "user": result["user"],
        }

    def _headers(self, account):
        return {"Authorization": f"Bearer {account['token']}"}

    def _start(self, account, lesson_id):
        response = self.client.post(
            f"/api/v1/lessons/{lesson_id}/start",
            headers=self._headers(account),
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["run_id"]

    def _answer_lesson(self, account, lesson_id, run_id):
        exercises = list(
            self.db.scalars(
                select(Exercise)
                .where(Exercise.lesson_id == lesson_id)
                .order_by(Exercise.sequence)
            )
        )
        for exercise in exercises:
            if exercise.exercise_type == "matchWords":
                for left_id, right_id in exercise.correct_answer_config[
                    "pairs"
                ].items():
                    answer = {
                        "exercise_id": exercise.id,
                        "run_id": run_id,
                        "submission_id": uuid.uuid4().hex,
                        "selected_pairs": {left_id: right_id},
                    }
                    response = self.client.post(
                        f"/api/v1/lessons/{lesson_id}/answer",
                        headers=self._headers(account),
                        json=answer,
                    )
                    self.assertEqual(response.status_code, 200, response.text)
            else:
                response = self.client.post(
                    f"/api/v1/lessons/{lesson_id}/answer",
                    headers=self._headers(account),
                    json={
                        "exercise_id": exercise.id,
                        "run_id": run_id,
                        "submission_id": uuid.uuid4().hex,
                        "selected_option_id": exercise.answer_id,
                    },
                )
                self.assertEqual(response.status_code, 200, response.text)

    def _complete_lesson(self, account, lesson_id):
        run_id = self._start(account, lesson_id)
        self._answer_lesson(account, lesson_id, run_id)
        response = self.client.post(
            f"/api/v1/lessons/{lesson_id}/attempts",
            headers=self._headers(account),
            json={"run_id": run_id},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_registered_accounts_have_independent_progress_and_run_ownership(self):
        new_user = self.account_b["user"]
        self.assertEqual(new_user["xp"], 0)
        self.assertEqual(new_user["level"], 1)
        self.assertEqual(new_user["streak"], 0)
        self.assertEqual(new_user["lessons_completed"], 0)
        self.assertEqual(new_user["words_found"], 0)
        self.assertEqual(
            new_user["hero_stats"],
            {"hp": 100, "attack": 10, "defense": 8, "speed": 8, "magic": 10},
        )

        fresh_lessons = self.client.get(
            "/api/v1/lessons", headers=self._headers(self.account_b)
        ).json()
        availability = {item["id"]: item["availability"] for item in fresh_lessons}
        self.assertEqual(availability["L01"], "available")
        self.assertTrue(
            all(
                status == "locked"
                for lesson_id, status in availability.items()
                if lesson_id != "L01"
            )
        )
        with SessionLocal() as db:
            account_b_id = int(new_user["id"])
            self.assertEqual(
                db.scalar(
                    select(func.count()).select_from(LessonRun).where(
                        LessonRun.user_id == account_b_id
                    )
                ),
                0,
            )

        self._complete_lesson(self.account_a, "L01")
        self._complete_lesson(self.account_a, "L02")
        a_progress = self.client.get(
            "/api/v1/lessons", headers=self._headers(self.account_a)
        ).json()
        a_status = {item["id"]: item["availability"] for item in a_progress}
        self.assertEqual(a_status["L03"], "available")
        a_run_id = self._start(self.account_a, "L03")

        lessons_before = self._db_exercises("L03")
        single_answer = next(
            item for item in lessons_before if item.exercise_type != "matchWords"
        )
        wrong_option = next(
            item["id"]
            for item in single_answer.options
            if item["id"] != single_answer.answer_id
        )
        wrong_answer = self.client.post(
            f"/api/v1/lessons/L03/answer",
            headers=self._headers(self.account_a),
            json={
                "exercise_id": single_answer.id,
                "run_id": a_run_id,
                "submission_id": uuid.uuid4().hex,
                "selected_option_id": wrong_option,
            },
        )
        self.assertEqual(wrong_answer.status_code, 200, wrong_answer.text)
        self.assertFalse(wrong_answer.json()["correct"])
        a_queue = self.client.get(
            f"/api/v1/lessons/L03/runs/{a_run_id}/review-queue",
            headers=self._headers(self.account_a),
        )
        self.assertEqual(a_queue.status_code, 200, a_queue.text)
        self.assertEqual(a_queue.json()["review_queue"], [single_answer.id])

        self.assertEqual(
            self.client.post(
                "/api/v1/lessons/L03/start",
                headers=self._headers(self.account_b),
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.get(
                f"/api/v1/lessons/L03/runs/{a_run_id}/review-queue",
                headers=self._headers(self.account_b),
            ).status_code,
            404,
        )
        self.assertEqual(
            self.client.post(
                "/api/v1/lessons/L01/answer",
                headers=self._headers(self.account_b),
                json={
                    "exercise_id": self._db_exercises("L01")[0].id,
                    "run_id": a_run_id,
                    "submission_id": uuid.uuid4().hex,
                    "selected_option_id": "forged-option",
                },
            ).status_code,
            404,
        )
        self.assertEqual(
            self.client.post(
                "/api/v1/lessons/L01/attempts",
                headers=self._headers(self.account_b),
                json={"run_id": a_run_id},
            ).status_code,
            404,
        )

        b_result = self._complete_lesson(self.account_b, "L01")
        self.assertTrue(b_result["passed"])
        b_progress = self.client.get(
            "/api/v1/lessons", headers=self._headers(self.account_b)
        ).json()
        b_status = {item["id"]: item["availability"] for item in b_progress}
        self.assertEqual(b_status["L01"], "completed")
        self.assertEqual(b_status["L02"], "available")
        self.assertEqual(b_status["L03"], "locked")

        a_after = self.client.get(
            "/api/v1/me", headers=self._headers(self.account_a)
        ).json()
        b_after = self.client.get(
            "/api/v1/me", headers=self._headers(self.account_b)
        ).json()
        self.assertGreater(a_after["xp"], 0)
        self.assertGreater(b_after["xp"], 0)
        self.assertEqual(a_after["lessons_completed"], 2)
        self.assertEqual(b_after["lessons_completed"], 1)
        self.assertEqual(
            self.client.post(
                "/api/v1/lessons/L03/start",
                headers=self._headers(self.account_a),
            ).json()["run_id"],
            a_run_id,
        )
        self.assertEqual(
            self.client.get(
                "/api/v1/lessons/L03/runs/{}/review-queue".format(a_run_id),
                headers=self._headers(self.account_a),
            ).json()["review_queue"],
            [single_answer.id],
        )

        current_leaderboard = self.client.get(
            "/api/v1/leaderboard?filter=alltime",
            headers=self._headers(self.account_b),
        ).json()
        self.assertTrue(
            next(
                row["is_current_user"]
                for row in current_leaderboard
                if row["name"] == new_user["name"]
            )
        )
        self.assertFalse(
            next(
                row["is_current_user"]
                for row in current_leaderboard
                if row["name"] == self.account_a["user"]["name"]
            )
        )
        weekly_leaderboard = self.client.get(
            "/api/v1/leaderboard?filter=weekly",
            headers=self._headers(self.account_b),
        ).json()
        self.assertTrue(
            next(
                row["is_current_user"]
                for row in weekly_leaderboard
                if row["name"] == new_user["name"]
            )
        )
        self.assertFalse(
            next(
                row["is_current_user"]
                for row in weekly_leaderboard
                if row["name"] == self.account_a["user"]["name"]
            )
        )

    def _db_exercises(self, lesson_id):
        return list(
            self.db.scalars(
                select(Exercise)
                .where(Exercise.lesson_id == lesson_id)
                .order_by(Exercise.sequence)
            ).all()
        )

@unittest.skipUnless(TEST_URL, "Set GLOSSA_TEST_POSTGRES_URL to run isolated PostgreSQL HTTP concurrency tests")
class TestPostgresConcurrentCompletionHTTP(unittest.TestCase):
    lesson_id = "L01"
    other_lesson_id = "L02"

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
        self.other_lesson = self.db.get(Lesson, self.other_lesson_id)
        self.db.add(self.user)
        self.db.commit()
        self.db.refresh(self.user)
        self.token = create_token(self.user.id)
        self.answers = self._answers_for_lesson(self.lesson_id)
        self.assertTrue(self.answers)

    def tearDown(self):
        user_ids = list(
            self.db.scalars(
                select(User.id).where(User.email.like("stage6-%@example.com"))
            ).all()
        )
        if user_ids:
            for model in (
                ExerciseSubmission,
                LessonProgress,
                LessonCompletion,
                Attempt,
            ):
                self.db.query(model).filter(model.user_id.in_(user_ids)).delete(
                    synchronize_session=False
                )
            self.db.query(User).filter(User.id.in_(user_ids)).delete(
                synchronize_session=False
            )
        self.db.commit()
        self.db.close()

    def _db_exercises(self, lesson_id):
        return list(
            self.db.scalars(
                select(Exercise)
                .where(Exercise.lesson_id == lesson_id)
                .order_by(Exercise.sequence)
            ).all()
        )

    def _prepare_run(self, lesson_id, answers, key, token=None):
        run_token = token or self.token
        for answer in answers:
            parts = answer.get("selected_pairs")
            if parts:
                requests = [
                    {
                        "exercise_id": answer["exercise_id"],
                        "submission_id": uuid.uuid4().hex,
                        "selected_pairs": {left: right},
                    }
                    for left, right in parts.items()
                ]
            else:
                requests = [{**answer, "submission_id": uuid.uuid4().hex}]
            for item in requests:
                response = self._answer(
                    lesson_id,
                    {**item, "run_id": key},
                    token=run_token,
                )
                self.assertEqual(response.status_code, 200, response.text)

    def _answer(self, lesson_id, answer, token=None):
        with TestClient(app) as client:
            return client.post(
                f"/api/v1/lessons/{lesson_id}/answer",
                headers={"Authorization": f"Bearer {token or self.token}"},
                json=answer,
            )

    def _finalize(self, lesson_id, key, token=None):
        with TestClient(app) as client:
            return client.post(
                f"/api/v1/lessons/{lesson_id}/attempts",
                headers={"Authorization": f"Bearer {token or self.token}"},
                json={"run_id": key},
            )

    def _submit(self, lesson_id, answers, key, token=None):
        self._prepare_run(lesson_id, answers, key, token)
        return self._finalize(lesson_id, key, token)

    def _answers_for_lesson(self, lesson_id):
        answers = []
        for exercise in self.db.scalars(
            select(Exercise).where(Exercise.lesson_id == lesson_id).order_by(Exercise.sequence)
        ):
            if exercise.exercise_type == "matchWords":
                answer = {
                    "exercise_id": exercise.id,
                    "selected_pairs": exercise.correct_answer_config["pairs"],
                }
            else:
                answer = {"exercise_id": exercise.id, "selected_option_id": exercise.answer_id}
            answers.append(answer)
        return answers

    def _submit_concurrently(self, runs):
        prepared_keys = set()
        for lesson_id, key, answers in runs:
            if key not in prepared_keys:
                self._prepare_run(lesson_id, answers, key)
                prepared_keys.add(key)
        barrier = threading.Barrier(2)

        def send(lesson_id, key, answers):
            with TestClient(app) as client:
                barrier.wait(timeout=10)
                return client.post(
                    f"/api/v1/lessons/{lesson_id}/attempts",
                    headers={"Authorization": f"Bearer {self.token}"},
                    json={"run_id": key},
                )

        with ThreadPoolExecutor(max_workers=2) as pool:
            return list(pool.map(lambda run: send(*run), runs))

    def _assert_single_reward(self, attempt_count, expected_xp=None):
        self.db.expire_all()
        user = self.db.get(User, self.user.id)
        self.assertEqual(
            user.xp,
            self.lesson.xp_reward if expected_xp is None else expected_xp,
        )
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
        run = (self.lesson_id, key, self.answers)
        responses = self._submit_concurrently([run, run])
        self.assertEqual([response.status_code for response in responses], [200, 200])
        self._assert_single_reward(1)

    def test_different_keys_concurrent_http_requests(self):
        runs = [
            (self.lesson_id, uuid.uuid4().hex, self.answers),
            (self.lesson_id, uuid.uuid4().hex, self.answers),
        ]
        responses = self._submit_concurrently(runs)
        self.assertEqual([response.status_code for response in responses], [200, 200])
        self._assert_single_reward(2, expected_xp=25)

    def test_same_key_with_different_answers_is_rejected(self):
        key = uuid.uuid4().hex
        first = self._submit(self.lesson_id, self.answers, key)
        self.assertEqual(first.status_code, 200)
        exercise = next(
            exercise for exercise in self._db_exercises(self.lesson_id)
            if exercise.exercise_type != "matchWords"
        )
        changed_answer = next(
            option["id"] for option in exercise.options
            if option["id"] != exercise.answer_id
        )
        conflict = self._answer(
            self.lesson_id,
            {
                "run_id": key,
                "exercise_id": exercise.id,
                "selected_option_id": changed_answer,
            },
        )
        self.assertEqual(conflict.status_code, 409)
        self._assert_single_reward(1)

    def test_same_key_for_another_unlocked_lesson_is_rejected(self):
        key = uuid.uuid4().hex
        first = self._submit(self.lesson_id, self.answers, key)
        self.assertEqual(first.status_code, 200)
        other_answers = self._answers_for_lesson(self.other_lesson.id)
        self.assertTrue(other_answers)
        first_answer = other_answers[0]
        if first_answer.get("selected_pairs"):
            pair = next(iter(first_answer["selected_pairs"].items()))
            payload = {"selected_pairs": {pair[0]: pair[1]}}
        else:
            payload = {"selected_option_id": first_answer["selected_option_id"]}
        conflict = self._answer(
            self.other_lesson.id,
            {
                "run_id": key,
                "exercise_id": first_answer["exercise_id"],
                **payload,
            },
        )
        self.assertEqual(conflict.status_code, 404)
        self.assertEqual(
            self.db.query(Attempt).filter_by(user_id=self.user.id, lesson_id=self.other_lesson.id).count(),
            0,
        )

    def test_a_second_user_cannot_reuse_another_accounts_run_id(self):
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
        answer = self.answers[0]
        if answer.get("selected_pairs"):
            pair = next(iter(answer["selected_pairs"].items()))
            payload = {"selected_pairs": {pair[0]: pair[1]}}
        else:
            payload = {"selected_option_id": answer["selected_option_id"]}
        response = self._answer(
            self.lesson_id,
            {
                "run_id": key,
                "exercise_id": answer["exercise_id"],
                **payload,
            },
            token=create_token(second_user.id),
        )
        self.assertEqual(response.status_code, 404)
        response = self._finalize(
            self.lesson_id, key, token=create_token(second_user.id)
        )
        self.assertEqual(response.status_code, 404)
        self.db.expire_all()
        self.assertEqual(self.db.get(User, second_user.id).xp, 0)

    def test_retry_after_success_returns_the_committed_result(self):
        key = uuid.uuid4().hex
        first = self._submit(self.lesson_id, self.answers, key)
        second = self._finalize(self.lesson_id, key)
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.json(), first.json())
        self._assert_single_reward(1)

    def test_reward_failure_rolls_back_user_attempt_and_completion(self):
        def fail_completion_insert(mapper, connection, target):
            raise RuntimeError("forced isolated reward failure")

        event.listen(LessonCompletion, "before_insert", fail_completion_insert)
        try:
            key = uuid.uuid4().hex
            self._prepare_run(self.lesson_id, self.answers, key)
            with TestClient(app, raise_server_exceptions=False) as client:
                response = client.post(
                    f"/api/v1/lessons/{self.lesson_id}/attempts",
                    headers={"Authorization": f"Bearer {self.token}"},
                    json={"run_id": key},
                )
            self.assertEqual(response.status_code, 500)
            self.db.expire_all()
            self.assertEqual(self.db.get(User, self.user.id).xp, 0)
            self.assertEqual(self.db.query(Attempt).filter_by(user_id=self.user.id).count(), 0)
            self.assertEqual(self.db.query(LessonCompletion).filter_by(user_id=self.user.id).count(), 0)
            self.assertEqual(self.db.query(LessonProgress).filter_by(user_id=self.user.id).count(), 0)
        finally:
            event.remove(LessonCompletion, "before_insert", fail_completion_insert)

    def test_concurrent_completed_practice_and_next_lesson_do_not_lose_xp(self):
        self.db.add(LessonCompletion(
            user_id=self.user.id, lesson_id=self.lesson_id, score=1.0,
            passed=True, xp_earned=0, correct_answers=5, total_questions=5,
        ))
        self.db.add(
            LessonProgress(
                user_id=self.user.id,
                lesson_id=self.lesson_id,
                best_earned_xp=self.lesson.xp_reward,
                best_correct_answers=10,
                attempt_count=1,
                completed_at=datetime.now(timezone.utc),
            )
        )
        self.user.xp = 100
        self.db.commit()
        other_answers = self._answers_for_lesson(self.other_lesson.id)
        runs = [
            (self.lesson_id, uuid.uuid4().hex, self.answers),
            (self.other_lesson.id, uuid.uuid4().hex, other_answers),
        ]
        responses = self._submit_concurrently(runs)
        self.assertEqual([response.status_code for response in responses], [200, 200])
        self.db.expire_all()
        expected_xp = 100 + self.lesson.xp_reward // 4 + self.other_lesson.xp_reward
        self.assertEqual(self.db.get(User, self.user.id).xp, expected_xp)
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
                self.db.query(ExerciseSubmission).filter_by(
                    user_id=self.user.id, lesson_id=self.lesson_id
                ).delete()
                self.user.xp = 0
                self.user.level = 1
                self.db.commit()


if __name__ == "__main__":
    unittest.main()
