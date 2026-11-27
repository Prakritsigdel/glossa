"""Progression, per-answer feedback, and reward tests for the active curriculum."""

import unittest
import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import settings
from app.curriculum_blueprint import CURRICULUM_VERSION, load_curriculum, seed_curriculum
from app.database import Base
from app.main import app, current_user, db_session
from app.models import (
    Course,
    Exercise,
    Language,
    Lesson,
    LessonCompletion,
    LessonProgress,
    Unit,
    User,
)


class TestNewProgression(unittest.TestCase):
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
                    Course(
                        id="en_new",
                        source_language_id="en",
                        target_language_id="new",
                        name="English to Newari",
                        is_published=True,
                        is_active=True,
                    ),
                ]
            )
            db.flush()
            seed_curriculum(db)
            self.user = User(
                id=1,
                name="Synthetic learner",
                email="progression@example.com",
                password_hash="unused",
                active_course_id="en_new",
            )
            db.add(self.user)
            db.commit()

        self.original_environment = settings.content_environment
        settings.content_environment = "development"
        app.dependency_overrides[db_session] = self._db_override
        app.dependency_overrides[current_user] = self._current_user
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

    def _current_user(self):
        with self.Session() as db:
            return db.get(User, self.user.id)

    def _exercises(self, lesson_id):
        with self.Session() as db:
            return list(
                db.scalars(
                    select(Exercise)
                    .where(Exercise.lesson_id == lesson_id)
                    .order_by(Exercise.sequence)
                )
            )

    def _answer_exercise(self, exercise, run_id, correct=True):
        if exercise.exercise_type == "matchWords":
            correct_pairs = exercise.correct_answer_config["pairs"]
            if not correct:
                ids = list(correct_pairs)
                selected = {ids[0]: correct_pairs[ids[1]]}
                wrong = self.client.post(
                    f"/api/v1/lessons/{exercise.lesson_id}/answer",
                    json={
                        "run_id": run_id,
                        "submission_id": uuid.uuid4().hex,
                        "exercise_id": exercise.id,
                        "selected_pairs": selected,
                    },
                )
                if wrong.status_code != 200:
                    return wrong
                response = wrong
            else:
                response = None
            response = None
            for devanagari_id, english_id in correct_pairs.items():
                response = self.client.post(
                    f"/api/v1/lessons/{exercise.lesson_id}/answer",
                    json={
                        "run_id": run_id,
                        "submission_id": uuid.uuid4().hex,
                        "exercise_id": exercise.id,
                        "selected_pairs": {devanagari_id: english_id},
                    },
                )
                if response.status_code != 200:
                    return response
            return response

        selected_id = exercise.answer_id
        if not correct:
            selected_id = next(
                option["id"]
                for option in exercise.options
                if option["id"] != exercise.answer_id
            )
        return self.client.post(
            f"/api/v1/lessons/{exercise.lesson_id}/answer",
            json={
                "run_id": run_id,
                "submission_id": uuid.uuid4().hex,
                "exercise_id": exercise.id,
                "selected_option_id": selected_id,
            },
        )

    def _review_exercise(self, exercise, run_id, *, correct=True):
        selected_id = exercise.answer_id
        if not correct:
            selected_id = next(
                option["id"]
                for option in exercise.options
                if option["id"] != exercise.answer_id
            )
        return self.client.post(
            f"/api/v1/lessons/{exercise.lesson_id}/answer",
            json={
                "run_id": run_id,
                "submission_id": uuid.uuid4().hex,
                "exercise_id": exercise.id,
                "phase": "review",
                "selected_option_id": selected_id,
            },
        )

    def _complete_run(self, lesson_id, correct_count=None):
        exercises = self._exercises(lesson_id)
        run_id = uuid.uuid4().hex
        final_feedback = {}
        for index, exercise in enumerate(exercises):
            correct = correct_count is None or index < correct_count
            response = self._answer_exercise(exercise, run_id, correct)
            self.assertEqual(response.status_code, 200, response.text)
            final_feedback[exercise.id] = response.json()
        for index, exercise in enumerate(exercises):
            if (
                correct_count is not None
                and index >= correct_count
                and exercise.exercise_type != "matchWords"
            ):
                response = self._review_exercise(exercise, run_id)
                self.assertEqual(response.status_code, 200, response.text)
        result = self.client.post(
            f"/api/v1/lessons/{lesson_id}/attempts", json={"run_id": run_id}
        )
        self.assertEqual(result.status_code, 200, result.text)
        return result.json(), run_id, final_feedback

    def _complete_prerequisites(self, lesson_ids):
        with self.Session() as db:
            for lesson_id in lesson_ids:
                db.add(
                    LessonProgress(
                        user_id=self.user.id,
                        lesson_id=lesson_id,
                        completed_at=datetime.now(timezone.utc),
                    )
                )
            db.commit()

    def test_town_and_lesson_payloads_are_dynamic_and_hide_answers(self):
        lessons = self.client.get("/api/v1/lessons")
        self.assertEqual(lessons.status_code, 200)
        self.assertEqual(len(lessons.json()), 15)
        self.assertEqual(
            sum(row["planned_exercise_count"] for row in lessons.json()), 162
        )
        town = self.client.get("/api/v1/courses/en_new/town-map")
        self.assertEqual(town.status_code, 200)
        rows = town.json()
        self.assertEqual(len(rows), 15)
        self.assertEqual(rows[0]["availability"], "available")
        self.assertEqual(rows[-1]["availability"], "locked")
        self.assertTrue(all(not row["is_published"] for row in rows))

        exercises = self.client.get("/api/v1/lessons/L01/exercises")
        self.assertEqual(exercises.status_code, 200)
        first_payloads = exercises.json()
        self.assertEqual(len(first_payloads), 10)
        self._complete_prerequisites([f"L{number:02d}" for number in range(1, 15)])
        payloads = []
        for lesson in lessons.json():
            response = self.client.get(
                f"/api/v1/lessons/{lesson['id']}/exercises"
            )
            self.assertEqual(response.status_code, 200, response.text)
            payloads.extend(response.json())
        self.assertEqual(len(payloads), 162)
        self.assertEqual(
            {row["exercise_type"] for row in payloads},
            {"matchWords", "fillBlank", "pictureToWord", "wordToPicture"},
        )
        self.assertTrue(
            all(
                "answer_id" not in row and "correct_answer_config" not in row
                for row in payloads
            )
        )

    def test_three_mistakes_complete_l01_with_fourteen_xp_and_replay_rewards_once(self):
        exercises = self._exercises("L01")
        self.assertEqual(len(exercises), 10)
        wrong_feedback = {}
        run_id = uuid.uuid4().hex
        for index, exercise in enumerate(exercises):
            response = self._answer_exercise(exercise, run_id, correct=index >= 3)
            self.assertEqual(response.status_code, 200, response.text)
            wrong_feedback[exercise.id] = response.json()
        self.assertTrue(
            all(
                not wrong_feedback[exercise.id]["correct"]
                and (
                    wrong_feedback[exercise.id]["correct_answer"]
                    or exercise.exercise_type == "matchWords"
                )
                for exercise in exercises[:3]
            )
        )
        self.assertEqual(wrong_feedback[exercises[0].id]["mistake_count"], 1)
        self.assertIsNone(wrong_feedback[exercises[0].id]["correct_answer"])
        for exercise in exercises[:3]:
            if exercise.exercise_type != "matchWords":
                reviewed = self._review_exercise(exercise, run_id)
                self.assertEqual(reviewed.status_code, 200, reviewed.text)
                self.assertTrue(reviewed.json()["correct"])

        result_response = self.client.post(
            "/api/v1/lessons/L01/attempts", json={"run_id": run_id}
        )
        self.assertEqual(result_response.status_code, 200, result_response.text)
        result = result_response.json()
        self.assertTrue(result["passed"])
        self.assertEqual(result["earned_xp"], 14)
        self.assertEqual(result["credited_xp"], 14)
        self.assertEqual(result["xp_max"], 20)
        self.assertEqual(result["correct_answers"], 7)
        self.assertEqual(len(result["missed_vocabulary"]), 2)
        self.assertIsNone(result["results"][0]["correct_answer"])
        self.assertTrue(
            all(result["results"][index]["correct_answer"] for index in range(1, 3))
        )
        self.assertEqual(result["results"][0]["mistake_count"], 1)
        self.assertTrue(all(not row["correct_answer"] for row in result["results"][3:]))

        duplicate = self.client.post(
            "/api/v1/lessons/L01/attempts", json={"run_id": run_id}
        )
        self.assertEqual(duplicate.status_code, 200)
        self.assertEqual(duplicate.json(), result)
        profile = self.client.get("/api/v1/me").json()
        self.assertEqual(profile["xp"], 14)
        self.assertEqual(profile["lessons_completed"], 1)
        self.assertEqual(profile["words_found"], 6)
        self.assertEqual(
            profile["hero_stats"],
            {"hp": 105, "attack": 10, "defense": 8, "speed": 10, "magic": 11},
        )

        replay, _, _ = self._complete_run("L01")
        self.assertTrue(replay["already_completed"])
        self.assertEqual(replay["earned_xp"], 20)
        self.assertEqual(replay["credited_xp"], 5)
        self.assertEqual(replay["stat_gains"], {})
        profile_after_replay = self.client.get("/api/v1/me").json()
        self.assertEqual(profile_after_replay["xp"], 19)
        self.assertEqual(profile_after_replay["lessons_completed"], 1)
        self.assertEqual(profile_after_replay["words_found"], 6)
        with self.Session() as db:
            self.assertEqual(
                db.query(LessonCompletion)
                .filter_by(user_id=self.user.id, lesson_id="L01")
                .count(),
                1,
            )

    def test_matching_mistakes_retry_pairs_without_answer_sheet_or_xp(self):
        exercise = self._exercises("L01")[0]
        pairs = exercise.correct_answer_config["pairs"]
        dev_ids = list(pairs)
        english_ids = list(pairs.values())
        run_id = uuid.uuid4().hex

        def submit(pair, submission_id):
            return self.client.post(
                f"/api/v1/lessons/{exercise.lesson_id}/answer",
                json={
                    "run_id": run_id,
                    "submission_id": submission_id,
                    "exercise_id": exercise.id,
                    "selected_pairs": pair,
                },
            )

        first_id = uuid.uuid4().hex
        first = submit({dev_ids[0]: english_ids[1]}, first_id)
        self.assertEqual(first.status_code, 200, first.text)
        self.assertFalse(first.json()["pair_correct"])
        self.assertFalse(first.json()["is_final"])
        self.assertIsNone(first.json()["correct_answer"])
        self.assertEqual(first.json()["mistake_count"], 1)
        self.assertEqual(submit({dev_ids[0]: english_ids[1]}, first_id).json(), first.json())

        reused_id = submit({dev_ids[1]: english_ids[2]}, first_id)
        self.assertEqual(reused_id.status_code, 409)
        second = submit({dev_ids[1]: english_ids[0]}, uuid.uuid4().hex)
        self.assertEqual(second.status_code, 200, second.text)
        self.assertEqual(second.json()["mistake_count"], 2)
        self.assertEqual(len(second.json()["matched_pairs"]), 0)

        final = None
        for dev_id, english_id in pairs.items():
            final = submit({dev_id: english_id}, uuid.uuid4().hex)
            self.assertEqual(final.status_code, 200, final.text)
        self.assertIsNotNone(final)
        self.assertTrue(final.json()["pair_correct"])
        self.assertTrue(final.json()["is_final"])
        self.assertFalse(final.json()["correct"])
        self.assertEqual(final.json()["xp_earned"], 0)
        self.assertEqual(final.json()["mistake_count"], 2)
        self.assertIsNone(final.json()["correct_answer"])
        self.assertEqual(final.json()["matched_pairs"], pairs)

        run_id_for_rest = run_id
        for remaining in self._exercises("L01")[1:]:
            response = self._answer_exercise(remaining, run_id_for_rest)
            self.assertEqual(response.status_code, 200, response.text)
        attempt = self.client.post(
            "/api/v1/lessons/L01/attempts", json={"run_id": run_id}
        )
        self.assertEqual(attempt.status_code, 200, attempt.text)
        matching_result = attempt.json()["results"][0]
        self.assertEqual(matching_result["mistake_count"], 2)
        self.assertIsNone(matching_result["correct_answer"])
        self.assertFalse(matching_result["correct"])

    def test_single_answer_retry_is_idempotent_and_returns_correct_option_id(self):
        exercise = self._exercises("L01")[1]
        wrong_option = next(
            option["id"]
            for option in exercise.options
            if option["id"] != exercise.answer_id
        )
        run_id = uuid.uuid4().hex
        submission_id = uuid.uuid4().hex
        payload = {
            "run_id": run_id,
            "submission_id": submission_id,
            "exercise_id": exercise.id,
            "selected_option_id": wrong_option,
        }
        path = f"/api/v1/lessons/{exercise.lesson_id}/answer"
        response = self.client.post(path, json=payload)
        self.assertEqual(response.status_code, 200, response.text)
        feedback = response.json()
        self.assertFalse(feedback["correct"])
        self.assertEqual(feedback["correct_option_id"], exercise.answer_id)
        self.assertTrue(feedback["correct_answer"]["newari"])
        self.assertTrue(feedback["correct_answer"]["romanization"])
        self.assertEqual(self.client.post(path, json=payload).json(), feedback)

        changed = {**payload, "selected_option_id": exercise.answer_id}
        self.assertEqual(self.client.post(path, json=changed).status_code, 409)

    def test_review_is_required_resumable_and_does_not_change_first_attempt_score(self):
        exercises = self._exercises("L01")
        incorrect = next(item for item in exercises if item.exercise_type != "matchWords")
        run_id = uuid.uuid4().hex
        for exercise in exercises:
            response = self._answer_exercise(
                exercise, run_id, correct=exercise.id != incorrect.id
            )
            self.assertEqual(response.status_code, 200, response.text)

        run_state = self.client.post("/api/v1/lessons/L01/start").json()
        self.assertEqual(run_state["run_id"], run_id)
        self.assertEqual(run_state["review_queue"], [incorrect.id])
        self.assertFalse(run_state["original_results"][incorrect.id])
        self.assertIn(incorrect.id, run_state["answered_exercise_ids"])

        blocked = self.client.post(
            "/api/v1/lessons/L01/attempts", json={"run_id": run_id}
        )
        self.assertEqual(blocked.status_code, 409)
        self.assertEqual(blocked.json()["detail"]["review_queue"], [incorrect.id])

        wrong_option = next(
            option["id"]
            for option in incorrect.options
            if option["id"] != incorrect.answer_id
        )
        wrong_review_payload = {
            "run_id": run_id,
            "submission_id": uuid.uuid4().hex,
            "exercise_id": incorrect.id,
            "phase": "review",
            "selected_option_id": wrong_option,
        }
        wrong_review = self.client.post(
            f"/api/v1/lessons/L01/answer", json=wrong_review_payload
        )
        self.assertEqual(wrong_review.status_code, 200, wrong_review.text)
        self.assertFalse(wrong_review.json()["review_complete"])
        duplicate_review = self.client.post(
            "/api/v1/lessons/L01/answer", json=wrong_review_payload
        )
        self.assertEqual(duplicate_review.status_code, 200)
        self.assertEqual(duplicate_review.json(), wrong_review.json())
        self.assertEqual(
            self.client.get(
                f"/api/v1/lessons/L01/runs/{run_id}/review-queue"
            ).json()["review_queue"],
            [incorrect.id],
        )

        right_review = self._review_exercise(incorrect, run_id)
        self.assertEqual(right_review.status_code, 200, right_review.text)
        self.assertTrue(right_review.json()["review_complete"])
        result_response = self.client.post(
            "/api/v1/lessons/L01/attempts", json={"run_id": run_id}
        )
        self.assertEqual(result_response.status_code, 200, result_response.text)
        result = result_response.json()
        self.assertEqual(result["correct_answers"], len(exercises) - 1)
        self.assertEqual(result["mistakes_corrected"], 1)
        self.assertEqual(result["mastered_exercises"], len(exercises))
        self.assertFalse(result["results"][incorrect.sequence - 1]["correct"])
        self.assertTrue(result["results"][incorrect.sequence - 1]["review_corrected"])
        self.assertEqual(
            result["results"][incorrect.sequence - 1]["review_attempts"], 2
        )

    def test_checkpoint_requires_eighty_percent_and_retry_credits_only_improvement(self):
        self._complete_prerequisites(["L01", "L02"])
        first, _, _ = self._complete_run("L03", correct_count=9)
        self.assertFalse(first["passed"])
        self.assertEqual(first["correct_answers"], 9)
        self.assertEqual(first["passing_threshold"], 80)
        self.assertFalse(first["completed"])
        self.assertEqual(first["credited_xp"], 28)
        town = {
            row["id"]: row["availability"]
            for row in self.client.get("/api/v1/courses/en_new/town-map").json()
        }
        self.assertEqual(town["L04"], "locked")

        passed, _, _ = self._complete_run("L03", correct_count=10)
        self.assertTrue(passed["passed"])
        self.assertTrue(passed["completed"])
        self.assertEqual(passed["earned_xp"], 32)
        self.assertEqual(passed["credited_xp"], 4)
        town = {
            row["id"]: row["availability"]
            for row in self.client.get("/api/v1/courses/en_new/town-map").json()
        }
        self.assertEqual(town["L04"], "available")

        replay, _, _ = self._complete_run("L03")
        self.assertEqual(replay["credited_xp"], 10)
        self.assertEqual(replay["stat_gains"], {})
        with self.Session() as db:
            self.assertEqual(
                db.query(LessonCompletion)
                .filter_by(user_id=self.user.id, lesson_id="L03")
                .count(),
                1,
            )


if __name__ == "__main__":
    unittest.main()
