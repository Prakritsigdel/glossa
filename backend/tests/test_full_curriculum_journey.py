"""Full 15-lesson curriculum journey against the isolated development API.

Opt-in integration test (the same pattern as the PostgreSQL concurrency
tests). It only talks to the development stack created by
``docker-compose.dev.yml`` and never touches the production database:

    GLOSSA_DEV_API_URL=http://localhost:18002
    GLOSSA_DEV_DATABASE_URL=postgresql+psycopg://glossa_dev:glossa_dev@localhost:15432/glossa_dev

Default mode registers a fresh learner and plays the real curriculum:
all 15 lessons, all 111 exercises and all seven exercise types, including
thresholds, retries, sequential unlocking, one-time XP and idempotent
submissions.

Persistence mode is enabled by additionally setting:

    GLOSSA_DEV_JOURNEY_USER_EMAIL=<email>
    GLOSSA_DEV_JOURNEY_USER_PASSWORD=<password>

and verifies that a previously completed journey survives a backend
restart. It is skipped when those variables are absent.
"""

from __future__ import annotations

import os
import unittest
import uuid

import httpx
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.models import Attempt, Exercise, Lesson, LessonCompletion

DEV_API_URL = os.getenv("GLOSSA_DEV_API_URL", "").rstrip("/")
DEV_DB_URL = os.getenv("GLOSSA_DEV_DATABASE_URL", "").strip()
JOURNEY_USER_EMAIL = os.getenv("GLOSSA_DEV_JOURNEY_USER_EMAIL", "").strip()
JOURNEY_USER_PASSWORD = os.getenv("GLOSSA_DEV_JOURNEY_USER_PASSWORD", "")

LESSON_IDS = [
    f"en_new_u{unit}_l{position}"
    for unit in range(1, 6)
    for position in range(1, 4)
]
CHECKPOINT_LESSONS = {3, 6, 9, 12, 15}
PLAN_NUMBER = {lesson_id: index + 1 for index, lesson_id in enumerate(LESSON_IDS)}
ALL_EXERCISE_TYPES = {
    "matchWords",
    "fillBlank",
    "pictureToWord",
    "wordToPicture",
    "translate",
    "wordOrder",
    "dialogueComplete",
}
OPTION_EXERCISE_TYPES = {
    "fillBlank", "pictureToWord", "wordToPicture", "dialogueComplete",
}

requires_dev_environment = unittest.skipUnless(
    DEV_API_URL and DEV_DB_URL,
    "Set GLOSSA_DEV_API_URL and GLOSSA_DEV_DATABASE_URL to run the "
    "development curriculum journey",
)


def correct_answer(exercise: Exercise) -> dict:
    """Build the server-authoritative correct answer for one exercise."""
    config = exercise.correct_answer_config or {}
    if exercise.exercise_type == "matchWords":
        pairs = config.get("pairs") or exercise.pairs or {}
        return {"exercise_id": exercise.id, "selected_pairs": pairs}
    if exercise.exercise_type in ("translate", "wordOrder"):
        return {
            "exercise_id": exercise.id,
            "selected_tile_ids": list(config.get("correct_sequence") or []),
        }
    option_id = config.get("correct_option_id") or exercise.answer_id
    return {"exercise_id": exercise.id, "selected_option_id": option_id}


def wrong_answer(exercise: Exercise) -> dict | None:
    """Build a structurally valid but incorrect answer, or None if impossible."""
    config = exercise.correct_answer_config or {}
    if exercise.exercise_type in OPTION_EXERCISE_TYPES:
        correct_id = config.get("correct_option_id") or exercise.answer_id
        alternatives = [
            option["id"]
            for option in (exercise.options or [])
            if isinstance(option, dict) and option.get("id") != correct_id
        ]
        if not alternatives:
            return None
        return {"exercise_id": exercise.id, "selected_option_id": alternatives[0]}
    if exercise.exercise_type == "matchWords":
        pairs = dict(config.get("pairs") or exercise.pairs or {})
        if len(pairs) < 2:
            return None
        keys = list(pairs)
        first, second = keys[0], keys[1]
        pairs[first], pairs[second] = pairs[second], pairs[first]
        return {"exercise_id": exercise.id, "selected_pairs": pairs}
    sequence = list(config.get("correct_sequence") or [])
    if len(sequence) < 2:
        # A single-tile answer has no valid but incorrect submission.
        return None
    sequence.reverse()
    return {"exercise_id": exercise.id, "selected_tile_ids": sequence}


@requires_dev_environment
class TestFullCurriculumJourney(unittest.TestCase):
    """Play the real provisional curriculum on the development API."""

    client: httpx.Client
    token: str
    user_id: int

    @classmethod
    def setUpClass(cls):
        cls.client = httpx.Client(base_url=DEV_API_URL, timeout=30.0)
        health = cls.client.get("/health")
        assert health.status_code == 200, health.text
        payload = health.json()
        assert payload.get("content_environment") == "development", (
            f"Expected the development content environment, got {payload}"
        )

        engine = create_engine(DEV_DB_URL)
        cls.db_session = sessionmaker(bind=engine, expire_on_commit=False)
        cls.engine = engine

    @classmethod
    def tearDownClass(cls):
        cls.client.close()
        cls.engine.dispose()

    # ── helpers ────────────────────────────────────────────────────────

    @property
    def auth(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    def _register_or_login(self, email: str, password: str, name: str) -> dict:
        response = self.client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": password, "name": name},
        )
        if response.status_code == 409:
            response = self.client.post(
                "/api/v1/auth/login",
                json={"email": email, "password": password},
            )
        self.assertIn(response.status_code, (200, 201), response.text)
        return response.json()

    def _me(self) -> dict:
        response = self.client.get("/api/v1/me", headers=self.auth)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def _lessons(self) -> list[dict]:
        response = self.client.get("/api/v1/lessons", headers=self.auth)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def _exercises(self, lesson_id: str) -> list[dict]:
        response = self.client.get(
            f"/api/v1/lessons/{lesson_id}/exercises", headers=self.auth
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def _db_exercises(self, lesson_id: str) -> list[Exercise]:
        with self.db_session() as db:
            return list(
                db.scalars(
                    select(Exercise)
                    .where(Exercise.lesson_id == lesson_id)
                    .order_by(Exercise.sequence)
                ).all()
            )

    def _attempt(self, lesson_id: str, answers: list[dict], key: str) -> httpx.Response:
        return self.client.post(
            f"/api/v1/lessons/{lesson_id}/attempts",
            json={"answers": answers, "idempotency_key": key},
            headers=self.auth,
        )

    # ── tests ─────────────────────────────────────────────────────────

    def test_registration_login_and_hero_selection(self):
        email = f"journey_auth_{uuid.uuid4().hex[:10]}@test.glossa"
        password = "Journey123!"
        registered = self._register_or_login(email, password, "Journey Auth")
        self.assertIn("access_token", registered)
        self.assertEqual(registered["user"]["email"], email)

        login = self.client.post(
            "/api/v1/auth/login", json={"email": email, "password": password}
        )
        self.assertEqual(login.status_code, 200, login.text)
        self.assertIn("access_token", login.json())

        self.token = login.json()["access_token"]
        hero = self.client.patch(
            "/api/v1/me", json={"hero_index": 1}, headers=self.auth
        )
        self.assertEqual(hero.status_code, 200, hero.text)
        self.assertEqual(hero.json()["hero_index"], 1)
        self.assertEqual(self._me()["hero_index"], 1)

    def test_play_all_fifteen_lessons_and_111_exercises(self):
        # With GLOSSA_DEV_JOURNEY_USER_EMAIL set, the journey runs as that
        # learner so the completed progress can be re-checked after a backend
        # restart. Such a learner must still be fresh (zero completed lessons).
        email = JOURNEY_USER_EMAIL or f"journey_full_{uuid.uuid4().hex[:10]}@test.glossa"
        password = JOURNEY_USER_PASSWORD or "Journey123!"
        auth = self._register_or_login(email, password, "Journey Player")
        self.token = auth["access_token"]
        self.user_id = auth["user"]["id"]
        if JOURNEY_USER_EMAIL:
            started = self._me()
            self.assertEqual(
                started["lessons_completed"], 0,
                "the persistence journey user already has progress; "
                "choose a fresh GLOSSA_DEV_JOURNEY_USER_EMAIL",
            )

        lessons = self._lessons()
        self.assertEqual(len(lessons), 15, [lesson["id"] for lesson in lessons])
        self.assertEqual([lesson["id"] for lesson in lessons], LESSON_IDS)

        planned_total = sum(lesson["planned_exercise_count"] for lesson in lessons)
        populated_total = sum(lesson["populated_exercise_count"] for lesson in lessons)
        self.assertEqual(planned_total, 111)
        self.assertEqual(populated_total, 111)

        for lesson in lessons:
            plan = PLAN_NUMBER[lesson["id"]]
            expected_score = 80 if plan in CHECKPOINT_LESSONS else 100
            self.assertEqual(lesson["passing_score"], expected_score, lesson["id"])
            self.assertEqual(lesson["is_checkpoint"], plan in CHECKPOINT_LESSONS)

        # Sequential unlocking: only the first lesson is open at the start.
        self.assertEqual(lessons[0]["availability"], "available")
        for lesson in lessons[1:]:
            self.assertEqual(lesson["availability"], "locked", lesson["id"])

        # A locked lesson cannot be inspected or submitted.
        locked = self.client.get(
            f"/api/v1/lessons/{LESSON_IDS[1]}/exercises", headers=self.auth
        )
        self.assertEqual(locked.status_code, 403)

        seen_types: set[str] = set()
        played_exercises = 0
        xp_earned_total = 0
        expected_xp = 0

        for index, lesson_id in enumerate(LESSON_IDS, start=1):
            public_exercises = self._exercises(lesson_id)
            db_exercises = self._db_exercises(lesson_id)
            self.assertEqual(len(public_exercises), len(db_exercises), lesson_id)
            self.assertEqual(len(public_exercises), lessons[index - 1]["planned_exercise_count"])
            played_exercises += len(public_exercises)
            seen_types.update(item["exercise_type"] for item in public_exercises)

            answers = [correct_answer(exercise) for exercise in db_exercises]
            total = len(answers)
            passing_score = lessons[index - 1]["passing_score"]

            # 1. A failing attempt must sit just below the threshold: it must
            # not pass and must not award XP. For checkpoints (80%) the
            # passing attempt below is the smallest integer score that still
            # clears the threshold, so one extra wrong answer is a failure.
            min_correct = -(-total * passing_score // 100)  # ceil
            failing_wrong = total - min_correct + 1
            passing_wrong = total - min_correct
            self.assertLess(
                (min_correct - 1) * 100, total * passing_score,
                f"{lesson_id}: the failing attempt must be below {passing_score}%",
            )
            self.assertGreaterEqual(
                min_correct * 100, total * passing_score,
                f"{lesson_id}: the passing attempt must reach {passing_score}%",
            )
            failing = list(answers)
            usable = [
                position
                for position, exercise in enumerate(db_exercises)
                if wrong_answer(exercise) is not None
            ]
            self.assertLessEqual(
                failing_wrong, len(usable),
                f"{lesson_id}: not enough exercises can be answered incorrectly",
            )
            for position in usable[:failing_wrong]:
                failing[position] = wrong_answer(db_exercises[position])

            before = self._me()
            failed_response = self._attempt(
                lesson_id, failing, f"j{uuid.uuid4().hex[:24]}"
            )
            self.assertEqual(failed_response.status_code, 200, failed_response.text)
            failed = failed_response.json()
            self.assertFalse(failed["passed"], f"{lesson_id} must not pass below {passing_score}%")
            self.assertEqual(failed["correct_answers"], min_correct - 1, lesson_id)
            self.assertEqual(failed["xp_earned"], 0, lesson_id)
            after_failure = self._me()
            self.assertEqual(after_failure["xp"], before["xp"], lesson_id)
            self.assertEqual(
                after_failure["lessons_completed"], before["lessons_completed"], lesson_id
            )

            # 2. The passing attempt - exactly at the threshold for
            # checkpoints, fully correct for ordinary lessons - awards XP
            # exactly once.
            passing_answers = list(answers)
            for position in usable[:passing_wrong]:
                passing_answers[position] = wrong_answer(db_exercises[position])
            reward = lessons[index - 1]["xp_reward"]
            expected_xp += reward
            key = f"j{uuid.uuid4().hex[:24]}"
            passed_response = self._attempt(lesson_id, passing_answers, key)
            self.assertEqual(passed_response.status_code, 200, passed_response.text)
            passed = passed_response.json()
            self.assertTrue(
                passed["passed"],
                f"{lesson_id} must pass at exactly {min_correct}/{total} "
                f"(threshold {passing_score}%)",
            )
            self.assertEqual(passed["correct_answers"], min_correct)
            self.assertEqual(passed["total_questions"], total)
            self.assertEqual(passed["xp_earned"], reward, lesson_id)
            xp_earned_total += passed["xp_earned"]

            state = self._me()
            self.assertEqual(state["xp"], expected_xp, lesson_id)
            self.assertEqual(state["lessons_completed"], index, lesson_id)

            # 3. Idempotent replay of the exact same submission.
            replay = self._attempt(lesson_id, passing_answers, key)
            self.assertEqual(replay.status_code, 200, replay.text)
            replayed = replay.json()
            self.assertTrue(replayed["already_completed"], lesson_id)
            self.assertEqual(replayed["xp_earned"], reward, lesson_id)
            self.assertEqual(self._me()["xp"], expected_xp, lesson_id)

            # 4. A fresh fully correct submission after completion awards
            # nothing - even one that beats the threshold-exact pass above.
            retry = self._attempt(lesson_id, answers, f"j{uuid.uuid4().hex[:24]}")
            self.assertEqual(retry.status_code, 200, retry.text)
            self.assertTrue(retry.json()["already_completed"], lesson_id)
            self.assertEqual(retry.json()["xp_earned"], 0, lesson_id)
            self.assertEqual(self._me()["xp"], expected_xp, lesson_id)

            # 5. Authoritative records exist in the development database.
            with self.db_session() as db:
                completion = db.scalar(
                    select(LessonCompletion).where(
                        LessonCompletion.user_id == self.user_id,
                        LessonCompletion.lesson_id == lesson_id,
                    )
                )
                self.assertIsNotNone(completion, lesson_id)
                self.assertTrue(completion.passed, lesson_id)
                self.assertEqual(completion.xp_earned, reward, lesson_id)
                attempts = list(
                    db.scalars(
                        select(Attempt).where(
                            Attempt.user_id == self.user_id,
                            Attempt.lesson_id == lesson_id,
                        )
                    ).all()
                )
                self.assertGreaterEqual(len(attempts), 2, lesson_id)

            # 6. Unlocking: the next lesson opens only after this one clears.
            statuses = {lesson["id"]: lesson["availability"] for lesson in self._lessons()}
            self.assertEqual(statuses[lesson_id], "completed", lesson_id)
            if index < 15:
                self.assertEqual(
                    statuses[LESSON_IDS[index]], "available",
                    f"{LESSON_IDS[index]} must unlock after {lesson_id}",
                )

        self.assertEqual(played_exercises, 111)
        self.assertEqual(seen_types, ALL_EXERCISE_TYPES, seen_types)
        self.assertEqual(xp_earned_total, expected_xp)

        progress = self.client.get(
            "/api/v1/courses/en_new/progress", headers=self.auth
        )
        self.assertEqual(progress.status_code, 200, progress.text)
        body = progress.json()
        self.assertEqual(body["completed_lessons"], 15)
        self.assertEqual(body["total_lessons"], 15)
        self.assertTrue(body["is_complete"], "the capstone must complete the course")

    @unittest.skipUnless(
        JOURNEY_USER_EMAIL and JOURNEY_USER_PASSWORD,
        "Set GLOSSA_DEV_JOURNEY_USER_EMAIL and GLOSSA_DEV_JOURNEY_USER_PASSWORD "
        "to verify progress persistence across a backend restart",
    )
    def test_progress_persists_after_backend_restart(self):
        auth = self._register_or_login(
            JOURNEY_USER_EMAIL, JOURNEY_USER_PASSWORD, "Journey Restart"
        )
        self.token = auth["access_token"]
        state = self._me()
        self.assertEqual(state["lessons_completed"], 15, state)
        self.assertEqual(state["xp"], 300, state)

        lessons = self._lessons()
        self.assertEqual(len(lessons), 15)
        self.assertTrue(
            all(lesson["availability"] == "completed" for lesson in lessons),
            [lesson["availability"] for lesson in lessons],
        )

        progress = self.client.get(
            "/api/v1/courses/en_new/progress", headers=self.auth
        )
        self.assertEqual(progress.status_code, 200, progress.text)
        self.assertTrue(progress.json()["is_complete"])


if __name__ == "__main__":
    unittest.main()
