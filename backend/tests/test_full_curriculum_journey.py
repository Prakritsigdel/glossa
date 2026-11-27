"""End-to-end Newari curriculum journeys against the isolated dev API.

Opt in with:
    GLOSSA_DEV_API_URL=http://localhost:18002
    GLOSSA_DEV_DATABASE_URL=postgresql+psycopg://glossa_dev:glossa_dev@localhost:15432/glossa_dev

The suite creates unique test accounts and deliberately leaves them intact.
"""

from __future__ import annotations

import os
import unittest
import uuid

import httpx
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import sessionmaker

from app.curriculum_blueprint import SUPPORTED_ILLUSTRATION_KEYS, load_curriculum
from app.models import Attempt, Exercise, LessonProgress

DEV_API_URL = os.getenv("GLOSSA_DEV_API_URL", "").rstrip("/")
DEV_DB_URL = os.getenv("GLOSSA_DEV_DATABASE_URL", "").strip()
JOURNEY_USER_EMAIL = os.getenv("GLOSSA_DEV_JOURNEY_USER_EMAIL", "").strip()
JOURNEY_USER_PASSWORD = os.getenv("GLOSSA_DEV_JOURNEY_USER_PASSWORD", "")
CONTENT = load_curriculum()
LESSONS = CONTENT["lessons"]
WORD_IDS = {word["id"] for word in CONTENT["words"]}
LESSON_IDS = [lesson["id"] for lesson in LESSONS]
CHECKPOINT_IDS = {
    lesson["id"] for lesson in LESSONS if lesson.get("is_checkpoint")
}
ACTIVE_TYPES = {"matchWords", "fillBlank", "pictureToWord", "wordToPicture"}

requires_dev_environment = unittest.skipUnless(
    DEV_API_URL and DEV_DB_URL,
    "Set GLOSSA_DEV_API_URL and GLOSSA_DEV_DATABASE_URL to run the "
    "development curriculum journey",
)


@requires_dev_environment
class TestFullCurriculumJourney(unittest.TestCase):
    """Run every active lesson against the real API and PostgreSQL database."""

    client: httpx.Client

    @classmethod
    def setUpClass(cls):
        cls.client = httpx.Client(base_url=DEV_API_URL, timeout=60.0)
        health = cls.client.get("/health")
        if health.status_code != 200:
            raise RuntimeError(f"Development API health failed: {health.text}")
        if health.json().get("content_environment") != "development":
            raise RuntimeError("The journey requires the isolated development API")
        cls.engine = create_engine(DEV_DB_URL, pool_pre_ping=True)
        cls.db_session = sessionmaker(bind=cls.engine, expire_on_commit=False)

    @classmethod
    def tearDownClass(cls):
        cls.client.close()
        cls.engine.dispose()

    def setUp(self):
        self.created_emails: set[str] = set()

    def tearDown(self):
        if not self.created_emails:
            return
        with self.db_session() as db:
            from app.models import User
            db.query(User).filter(
                User.email.in_(self.created_emails)
            ).delete(synchronize_session=False)
            db.commit()

    def _register(self, prefix: str = "stage81") -> tuple[dict, str]:
        email = f"{prefix}-{uuid.uuid4().hex}@example.com"
        self.created_emails.add(email)
        password = "Stage81Journey123!"
        response = self.client.post(
            "/api/v1/auth/register",
            json={"name": "Stage 8.1 learner", "email": email, "password": password},
        )
        self.assertIn(response.status_code, (200, 201), response.text)
        body = response.json()
        return body, email

    def _login(self, email: str, password: str) -> dict:
        response = self.client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def _login_or_register(self, email: str, password: str) -> dict:
        response = self.client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        if response.status_code == 401:
            response = self.client.post(
                "/api/v1/auth/register",
                json={
                    "email": email,
                    "password": password,
                    "name": "Stage 8.1 persistence learner",
                },
            )
        self.assertIn(response.status_code, (200, 201), response.text)
        return response.json()

    def _headers(self, token: str) -> dict[str, str]:
        return {"Authorization": f"Bearer {token}"}

    def _get_json(self, path: str, token: str) -> dict | list:
        response = self.client.get(path, headers=self._headers(token))
        self.assertEqual(response.status_code, 200, f"{path}: {response.text}")
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

    def _post_answer(self, lesson_id: str, token: str, run_id: str, answer: dict):
        response = self.client.post(
            f"/api/v1/lessons/{lesson_id}/answer",
            headers=self._headers(token),
            json={"run_id": run_id, **answer},
        )
        return response

    def _answer_exercise(
        self,
        exercise: Exercise,
        token: str,
        run_id: str,
        *,
        correct: bool,
    ) -> dict:
        if exercise.exercise_type == "matchWords":
            pairs = (exercise.correct_answer_config or {}).get("pairs", {})
            self.assertGreaterEqual(len(pairs), 2, exercise.id)
            if not correct:
                keys = list(pairs)
                wrong_request = {
                    "exercise_id": exercise.id,
                    "submission_id": uuid.uuid4().hex,
                    "selected_pairs": {keys[0]: pairs[keys[1]]},
                }
                response = self._post_answer(
                    exercise.lesson_id,
                    token,
                    run_id,
                    wrong_request,
                )
                self.assertEqual(response.status_code, 200, response.text)
                feedback = response.json()
                self.assertFalse(feedback["correct"])
                self.assertFalse(feedback["is_final"])
                self.assertFalse(feedback["pair_correct"])
                self.assertIsNone(feedback["correct_answer"])
                self.assertEqual(feedback["xp_earned"], 0)
                self.assertEqual(feedback["mistake_count"], 1)
                duplicate = self._post_answer(
                    exercise.lesson_id, token, run_id, wrong_request
                )
                self.assertEqual(duplicate.status_code, 200, duplicate.text)
                self.assertEqual(duplicate.json(), feedback)
                conflict_request = {
                    **wrong_request,
                    "selected_pairs": {keys[1]: pairs[keys[0]]},
                }
                conflict = self._post_answer(
                    exercise.lesson_id, token, run_id, conflict_request
                )
                self.assertEqual(conflict.status_code, 409, conflict.text)

            feedback = None
            for index, (dev_id, eng_id) in enumerate(pairs.items()):
                response = self._post_answer(
                    exercise.lesson_id,
                    token,
                    run_id,
                    {
                        "exercise_id": exercise.id,
                        "submission_id": uuid.uuid4().hex,
                        "selected_pairs": {dev_id: eng_id},
                    },
                )
                self.assertEqual(response.status_code, 200, response.text)
                feedback = response.json()
                self.assertEqual(
                    feedback["pair_correct"],
                    True,
                )
                self.assertEqual(feedback["is_final"], index == len(pairs) - 1)
                self.assertEqual(
                    feedback["xp_earned"],
                    exercise.xp
                    if correct and index == len(pairs) - 1
                    else 0,
                )
            if not correct:
                self.assertFalse(feedback["correct"])
                self.assertEqual(feedback["mistake_count"], 1)
            return feedback

        selected_id = exercise.answer_id
        if not correct:
            selected_id = next(
                option["id"]
                for option in (exercise.options or [])
                if option["id"] != exercise.answer_id
            )
        submission_id = uuid.uuid4().hex
        answer_payload = {
            "exercise_id": exercise.id,
            "submission_id": submission_id,
            "selected_option_id": selected_id,
        }
        response = self._post_answer(
            exercise.lesson_id,
            token,
            run_id,
            answer_payload,
        )
        self.assertEqual(response.status_code, 200, response.text)
        feedback = response.json()
        self.assertTrue(feedback["is_final"])
        self.assertEqual(feedback["correct"], correct)
        self.assertEqual(feedback["xp_earned"], exercise.xp if correct else 0)
        if not correct:
            self.assertTrue(feedback["correct_answer"])
            self.assertEqual(feedback["correct_option_id"], exercise.answer_id)
            duplicate = self._post_answer(
                exercise.lesson_id, token, run_id, answer_payload
            )
            self.assertEqual(duplicate.status_code, 200, duplicate.text)
            self.assertEqual(duplicate.json(), feedback)
        return feedback

    def _play_lesson(
        self,
        lesson_id: str,
        token: str,
        *,
        wrong_indexes: set[int] | None = None,
    ) -> tuple[dict, str, dict[str, dict]]:
        start = self.client.post(
            f"/api/v1/lessons/{lesson_id}/start",
            headers=self._headers(token),
        )
        self.assertEqual(start.status_code, 200, start.text)
        run_state = start.json()
        self.assertFalse(run_state["answered_exercise_ids"])
        run_id = run_state["run_id"]
        exercises = self._db_exercises(lesson_id)
        final_feedback = {}
        wrong_indexes = wrong_indexes or set()
        for index, exercise in enumerate(exercises):
            final_feedback[exercise.id] = self._answer_exercise(
                exercise,
                token,
                run_id,
                correct=index not in wrong_indexes,
            )
        for index in wrong_indexes:
            exercise = exercises[index]
            if exercise.exercise_type == "matchWords":
                continue
            response = self._post_answer(
                exercise.lesson_id,
                token,
                run_id,
                {
                    "exercise_id": exercise.id,
                    "submission_id": uuid.uuid4().hex,
                    "phase": "review",
                    "selected_option_id": exercise.answer_id,
                },
            )
            self.assertEqual(response.status_code, 200, response.text)
            self.assertTrue(response.json()["correct"])

        response = self.client.post(
            f"/api/v1/lessons/{lesson_id}/attempts",
            headers=self._headers(token),
            json={"run_id": run_id},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json(), run_id, final_feedback

    def test_perfect_journey_covers_all_content_and_rewards(self):
        if JOURNEY_USER_EMAIL:
            auth = self._login_or_register(
                JOURNEY_USER_EMAIL, JOURNEY_USER_PASSWORD
            )
            self.assertEqual(auth["user"]["lessons_completed"], 0)
            self.assertEqual(auth["user"]["xp"], 0)
            email = JOURNEY_USER_EMAIL
        else:
            auth, email = self._register()
        token = auth["access_token"]

        lessons = self._get_json("/api/v1/lessons", token)
        self.assertEqual(len(LESSONS), 15)
        self.assertEqual(len(lessons), 15)
        self.assertEqual([row["id"] for row in lessons], LESSON_IDS)
        self.assertEqual(len({row["unit_id"] for row in lessons}), 5)
        self.assertEqual(
            sum(row["planned_exercise_count"] for row in lessons),
            162,
        )
        self.assertTrue(all(not row["is_published"] for row in lessons))
        self.assertEqual(lessons[0]["availability"], "available")
        self.assertTrue(all(row["availability"] == "locked" for row in lessons[1:]))

        locked = self.client.get(
            f"/api/v1/lessons/{LESSON_IDS[1]}/exercises",
            headers=self._headers(token),
        )
        self.assertEqual(locked.status_code, 403)
        locked_start = self.client.post(
            f"/api/v1/lessons/{LESSON_IDS[1]}/start",
            headers=self._headers(token),
        )
        self.assertEqual(locked_start.status_code, 403)
        locked_attempt = self.client.post(
            f"/api/v1/lessons/{LESSON_IDS[1]}/attempts",
            headers=self._headers(token),
            json={"run_id": uuid.uuid4().hex},
        )
        self.assertEqual(locked_attempt.status_code, 404)

        unit_ids = {row["unit_id"] for row in lessons}
        seen_types = set()
        total_xp = 0
        expected_lesson_count = 0
        last_result = None
        last_run_id = None
        for lesson_index, (public_lesson, source_lesson) in enumerate(
            zip(lessons, LESSONS, strict=True), start=1
        ):
            self.assertEqual(public_lesson["title"], source_lesson["title"])
            self.assertEqual(
                public_lesson["planned_exercise_count"],
                source_lesson["exercise_count"],
            )
            public_exercises = self._get_json(
                f"/api/v1/lessons/{source_lesson['id']}/exercises", token
            )
            source_exercises = source_lesson["exercises"]
            self.assertEqual(len(public_exercises), len(source_exercises))
            self.assertEqual(
                [item["id"] for item in public_exercises],
                [item["id"] for item in source_exercises],
            )
            for public, source in zip(public_exercises, source_exercises, strict=True):
                seen_types.add(public["exercise_type"])
                self.assertEqual(public["exercise_type"], source["type"])
                self.assertEqual(public["xp"], source["xp"])
                self.assertEqual(public["prompt"], source.get("prompt"))
                self.assertEqual(public["image_key"], source.get("image_key"))
                self.assertEqual(len(public["options"]), len({option["id"] for option in public["options"]}))
                self.assertNotIn("answer_id", public)
                self.assertNotIn("correct_answer_config", public)
                self.assertNotIn("answer_index", public)
                target_word_id = source.get("target_word_id")
                if target_word_id is not None:
                    self.assertIn(target_word_id, WORD_IDS, source["id"])
                if source["type"] == "matchWords":
                    source_pair_ids = [pair["word_id"] for pair in source["pairs"]]
                    self.assertTrue(set(source_pair_ids).issubset(WORD_IDS))
                    self.assertEqual(
                        sum(option["is_devanagari"] for option in public["options"]),
                        len(source_pair_ids),
                    )
                    self.assertEqual(len(public["options"]), 2 * len(source_pair_ids))
                elif source["type"] == "fillBlank":
                    self.assertTrue(public["options"], source["id"])
                    sentence = source["layout"]["sentence"]
                    self.assertEqual(
                        sum(part.get("blank") is True for part in sentence), 1
                    )
                elif source["type"] == "pictureToWord":
                    self.assertIn(source["image_key"], SUPPORTED_ILLUSTRATION_KEYS)
                elif source["type"] == "wordToPicture":
                    self.assertTrue(public["options"], source["id"])
                    for option in source["options"]:
                        self.assertIn(
                            option["image_key"], SUPPORTED_ILLUSTRATION_KEYS
                        )
                if source.get("planned_type"):
                    self.assertEqual(public["exercise_type"], "fillBlank")
                    self.assertEqual(public["planned_type"], source["planned_type"])
                if public["exercise_type"] == "fillBlank":
                    actual_layout = public["layout"]
                    tile_image = actual_layout.get("tile", {}).pop("image_key", None)
                    if tile_image:
                        self.assertIn(tile_image, SUPPORTED_ILLUSTRATION_KEYS)
                    self.assertEqual(actual_layout, source["layout"])

            result, run_id, _ = self._play_lesson(source_lesson["id"], token)
            last_result = result
            last_run_id = run_id
            lesson_xp = sum(exercise["xp"] for exercise in source_exercises)
            self.assertEqual(result["earned_xp"], lesson_xp, source_lesson["id"])
            self.assertEqual(result["credited_xp"], lesson_xp, source_lesson["id"])
            self.assertTrue(result["passed"], source_lesson["id"])
            self.assertTrue(result["completed"], source_lesson["id"])
            self.assertEqual(result["correct_answers"], len(source_exercises))
            self.assertEqual(result["total_questions"], len(source_exercises))
            self.assertEqual(result["stat_gains"], source_lesson["stat_gains"])
            total_xp += result["credited_xp"]
            expected_lesson_count += 1

            profile = self._get_json("/api/v1/me", token)
            self.assertEqual(profile["lessons_completed"], expected_lesson_count)
            if lesson_index == 1:
                self.assertEqual(profile["words_found"], 6)
            if lesson_index < len(LESSONS):
                refreshed = self._get_json("/api/v1/lessons", token)
                self.assertEqual(refreshed[lesson_index]["availability"], "available")
                if lesson_index + 1 < len(LESSONS):
                    self.assertEqual(
                        refreshed[lesson_index + 1]["availability"], "locked"
                    )

        self.assertEqual(seen_types, ACTIVE_TYPES)
        self.assertEqual(total_xp, 620)
        self.assertEqual(len(unit_ids), 5)
        profile = self._get_json("/api/v1/me", token)
        self.assertEqual(profile["xp"], 620)
        self.assertEqual(profile["xp_in_level"], 70)
        self.assertEqual(profile["xp_to_next_level"], 200)
        self.assertEqual(profile["level"], 5)
        self.assertEqual(profile["words_found"], 70)
        self.assertEqual(profile["lessons_completed"], 15)
        self.assertEqual(
            profile["hero_stats"],
            {"hp": 200, "attack": 25, "defense": 22, "speed": 21, "magic": 23},
        )
        town = self._get_json("/api/v1/courses/en_new/town-map", token)
        self.assertEqual(len(town), 15)
        self.assertTrue(all(row["availability"] == "completed" for row in town))
        progress = self._get_json("/api/v1/courses/en_new/progress", token)
        self.assertEqual(progress, {
            "course_id": "en_new",
            "completed_lessons": 15,
            "total_lessons": 15,
            "is_complete": True,
        })
        leaderboard = self._get_json("/api/v1/leaderboard?filter=alltime", token)
        current = next(row for row in leaderboard if row["is_current_user"])
        self.assertEqual(current["xp"], 620)
        self.assertEqual(current["level"], 5)

        second, _ = self._register("stage81-isolation")
        isolated = self._get_json("/api/v1/me", second["access_token"])
        self.assertEqual(isolated["xp"], 0)
        self.assertEqual(isolated["lessons_completed"], 0)
        self.assertEqual(isolated["words_found"], 0)
        self.assertEqual(isolated["hero_stats"], {
            "hp": 100, "attack": 10, "defense": 8, "speed": 8, "magic": 10,
        })

        retry = self.client.post(
            f"/api/v1/lessons/{LESSON_IDS[-1]}/attempts",
            headers=self._headers(token),
            json={"run_id": last_run_id},
        )
        self.assertEqual(retry.status_code, 200, retry.text)
        self.assertEqual(retry.json(), last_result)
        with self.db_session() as db:
            attempts = db.scalar(
                select(func.count()).select_from(Attempt).where(
                    Attempt.user_id == auth["user"]["id"],
                    Attempt.lesson_id == LESSON_IDS[-1],
                )
            )
            self.assertEqual(attempts, 1)

    def test_mistakes_checkpoint_retry_replay_and_idempotency(self):
        auth, _ = self._register("stage81-mistakes")
        token = auth["access_token"]

        first_exercises = self._db_exercises("L01")
        start = self.client.post(
            "/api/v1/lessons/L01/start",
            headers=self._headers(token),
        )
        self.assertEqual(start.status_code, 200, start.text)
        first_run = start.json()["run_id"]
        wrong_feedback = {}
        for index, exercise in enumerate(first_exercises):
            wrong_feedback[exercise.id] = self._answer_exercise(
                exercise, token, first_run, correct=index >= 3
            )
        first_wrong = first_exercises[0]
        if first_wrong.exercise_type == "matchWords":
            self.assertIsNone(wrong_feedback[first_wrong.id]["correct_answer"])
            self.assertEqual(wrong_feedback[first_wrong.id]["mistake_count"], 1)
        else:
            self.assertTrue(wrong_feedback[first_wrong.id]["correct_answer"])
        alternate_answer = (
            {"selected_pairs": first_wrong.correct_answer_config["pairs"]}
            if first_wrong.exercise_type == "matchWords"
            else {"selected_option_id": first_wrong.answer_id}
        )
        duplicate = self._post_answer(
            "L01",
            token,
            first_run,
            {"exercise_id": first_wrong.id, **alternate_answer},
        )
        self.assertEqual(duplicate.status_code, 409)

        review_queue_response = self.client.get(
            f"/api/v1/lessons/L01/runs/{first_run}/review-queue",
            headers=self._headers(token),
        )
        self.assertEqual(review_queue_response.status_code, 200)
        expected_review_ids = [
            exercise.id
            for index, exercise in enumerate(first_exercises)
            if index < 3 and exercise.exercise_type != "matchWords"
        ]
        review_queue = review_queue_response.json()["review_queue"]
        self.assertEqual(review_queue, expected_review_ids)

        for index, exercise in enumerate(first_exercises):
            if exercise.id not in review_queue:
                continue
            wrong_option_id = next(
                option["id"]
                for option in (exercise.options or [])
                if option["id"] != exercise.answer_id
            )
            wrong_review_payload = {
                "exercise_id": exercise.id,
                "submission_id": uuid.uuid4().hex,
                "phase": "review",
                "selected_option_id": wrong_option_id,
            }
            wrong_review = self._post_answer(
                "L01", token, first_run, wrong_review_payload
            )
            self.assertEqual(wrong_review.status_code, 200, wrong_review.text)
            self.assertFalse(wrong_review.json()["correct"])
            self.assertFalse(wrong_review.json()["review_complete"])
            self.assertEqual(wrong_review.json()["xp_earned"], 0)
            self.assertEqual(
                wrong_review.json()["correct_option_id"], exercise.answer_id
            )
            duplicate_review = self._post_answer(
                "L01", token, first_run, wrong_review_payload
            )
            self.assertEqual(duplicate_review.json(), wrong_review.json())
            self.assertEqual(
                self.client.get(
                    f"/api/v1/lessons/L01/runs/{first_run}/review-queue",
                    headers=self._headers(token),
                ).json()["review_queue"],
                review_queue,
            )

            correct_review = self._post_answer(
                "L01",
                token,
                first_run,
                {
                    "exercise_id": exercise.id,
                    "submission_id": uuid.uuid4().hex,
                    "phase": "review",
                    "selected_option_id": exercise.answer_id,
                },
            )
            self.assertEqual(correct_review.status_code, 200, correct_review.text)
            self.assertTrue(correct_review.json()["correct"])
            self.assertTrue(correct_review.json()["review_complete"])
            self.assertEqual(correct_review.json()["xp_earned"], 0)
            review_queue.remove(exercise.id)
            self.assertEqual(
                self.client.get(
                    f"/api/v1/lessons/L01/runs/{first_run}/review-queue",
                    headers=self._headers(token),
                ).json()["review_queue"],
                review_queue,
            )
        self.assertFalse(review_queue)

        result_response = self.client.post(
            "/api/v1/lessons/L01/attempts",
            headers=self._headers(token),
            json={"run_id": first_run},
        )
        self.assertEqual(result_response.status_code, 200, result_response.text)
        first_result = result_response.json()
        self.assertTrue(first_result["passed"])
        self.assertEqual(first_result["correct_answers"], 7)
        self.assertEqual(first_result["total_questions"], 10)
        self.assertEqual(first_result["mistakes_corrected"], len(expected_review_ids))
        self.assertEqual(first_result["earned_xp"], 14)
        self.assertEqual(first_result["credited_xp"], 14)
        self.assertEqual(len(first_result["missed_vocabulary"]), 2)
        self.assertEqual(len({row["exercise_id"] for row in first_result["results"]}), 10)

        duplicate_finish = self.client.post(
            "/api/v1/lessons/L01/attempts",
            headers=self._headers(token),
            json={"run_id": first_run},
        )
        self.assertEqual(duplicate_finish.status_code, 200)
        self.assertEqual(duplicate_finish.json(), first_result)

        # Regular L02 opens despite L01's mistakes.
        second_result, _, _ = self._play_lesson("L02", token)
        self.assertTrue(second_result["passed"])

        checkpoint_source = next(lesson for lesson in LESSONS if lesson["id"] == "L03")
        checkpoint_exercises = self._db_exercises("L03")
        self.assertIn("L03", CHECKPOINT_IDS)
        self.assertEqual(len(checkpoint_exercises), 12)
        failed, _, _ = self._play_lesson("L03", token, wrong_indexes={9, 10, 11})
        self.assertFalse(failed["passed"])
        self.assertFalse(failed["completed"])
        self.assertEqual(failed["correct_answers"], 9)
        self.assertEqual(failed["passing_threshold"], 80)
        self.assertEqual(failed["earned_xp"], 28)
        self.assertEqual(failed["credited_xp"], 28)
        self.assertEqual(failed["stat_gains"], {})
        self.assertEqual(failed["hero_stats"]["hp"], 110)
        town = self._get_json("/api/v1/courses/en_new/town-map", token)
        self.assertEqual(
            next(row for row in town if row["id"] == "L04")["availability"],
            "locked",
        )

        passed, _, _ = self._play_lesson("L03", token, wrong_indexes={10, 11})
        self.assertTrue(passed["passed"])
        self.assertTrue(passed["completed"])
        self.assertEqual(passed["correct_answers"], 10)
        self.assertEqual(passed["earned_xp"], 32)
        self.assertEqual(passed["credited_xp"], 4)
        self.assertEqual(passed["stat_gains"], checkpoint_source["stat_gains"])

        replay, _, _ = self._play_lesson("L03", token)
        self.assertTrue(replay["already_completed"])
        self.assertEqual(replay["earned_xp"], 40)
        self.assertEqual(replay["credited_xp"], 10)
        self.assertEqual(replay["stat_gains"], {})

        replay_l01, _, _ = self._play_lesson("L01", token)
        self.assertTrue(replay_l01["already_completed"])
        self.assertEqual(replay_l01["credited_xp"], 5)
        self.assertEqual(replay_l01["stat_gains"], {})
        profile = self._get_json("/api/v1/me", token)
        self.assertEqual(profile["lessons_completed"], 3)
        expected_stats = dict(CONTENT["progression"]["base_stats"])
        for lesson_id in ("L01", "L02", "L03"):
            for stat, gain in next(
                lesson for lesson in LESSONS if lesson["id"] == lesson_id
            )["stat_gains"].items():
                expected_stats[stat] += gain
        self.assertEqual(profile["hero_stats"], expected_stats)
        with self.db_session() as db:
            self.assertEqual(
                db.scalar(
                    select(func.count()).select_from(LessonProgress).where(
                        LessonProgress.user_id == auth["user"]["id"],
                        LessonProgress.lesson_id == "L03",
                        LessonProgress.completed_at.is_not(None),
                    )
                ),
                1,
            )

    @unittest.skipUnless(
        JOURNEY_USER_EMAIL and JOURNEY_USER_PASSWORD,
        "Set GLOSSA_DEV_JOURNEY_USER_EMAIL and GLOSSA_DEV_JOURNEY_USER_PASSWORD "
        "to verify persistence after restarting the API",
    )
    def test_progress_persists_after_backend_restart(self):
        auth = self._login(JOURNEY_USER_EMAIL, JOURNEY_USER_PASSWORD)
        token = auth["access_token"]
        profile = self._get_json("/api/v1/me", token)
        self.assertEqual(profile["lessons_completed"], 15)
        self.assertEqual(profile["xp"], 620)
        self.assertEqual(profile["level"], 5)
        self.assertEqual(profile["xp_in_level"], 70)
        self.assertEqual(profile["words_found"], 70)
        self.assertEqual(profile["hero_stats"], {
            "hp": 200, "attack": 25, "defense": 22, "speed": 21, "magic": 23,
        })
        lessons = self._get_json("/api/v1/lessons", token)
        self.assertEqual(len(lessons), 15)
        self.assertTrue(all(lesson["availability"] == "completed" for lesson in lessons))


if __name__ == "__main__":
    unittest.main()
