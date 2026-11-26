"""Stage 6 progression and server-side scoring tests using synthetic SQLite data."""

import unittest
import os
import tempfile

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base
from app.main import app, current_user, db_session
from app.models import (
    Course, Exercise, Language, Lesson, LessonCompletion, Unit, User,
)


class TestStage6Progression(unittest.TestCase):
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
                Language(id="ne", name_english="Nepali", name_native="Nepali", script="Devanagari"),
            ])
            db.add_all([
                Course(
                    id="en_new", source_language_id="en", target_language_id="new",
                    name="English to Newari", description="Synthetic test course",
                    is_published=False, is_active=True,
                ),
                Course(
                    id="en_ne", source_language_id="en", target_language_id="ne",
                    name="Retired course", description="Historical only",
                    is_published=False, is_active=False,
                ),
            ])
            db.flush()
            units = []
            for unit_number in range(1, 6):
                unit = Unit(
                    course_id="en_new", sequence=unit_number,
                    title=f"Unit {unit_number}", description="Synthetic unit",
                )
                db.add(unit)
                units.append(unit)
            db.add(Unit(
                course_id="en_new", sequence=6, title="Legacy unit",
                description="Excluded from current progression",
            ))
            db.flush()
            self.lesson_ids = []
            for unit_number, unit in enumerate(units, start=1):
                for position in range(1, 4):
                    plan_number = (unit_number - 1) * 3 + position
                    lesson_id = f"en_new_u{unit_number}_l{position}"
                    self.lesson_ids.append(lesson_id)
                    db.add(Lesson(
                        id=lesson_id, unit_id=unit.id, sequence=position,
                        title=f"Lesson {plan_number}", subtitle="Synthetic planned lesson",
                        exercise_type="fillBlank", xp_reward=20, word_count=4,
                        required_level=1, is_published=False,
                        is_checkpoint=position == 3,
                        passing_score=80 if position == 3 else 100,
                    ))
            db.add(Lesson(
                id="legacy_en_new_lesson", unit_id=units[0].id, sequence=4,
                title="Legacy lesson", subtitle="Must be excluded",
                exercise_type="fillBlank", xp_reward=20, word_count=1,
                required_level=1, is_published=True,
            ))
            self.user = User(
                id=1, name="Synthetic learner", email="stage6@example.test",
                password_hash="unused", active_course_id="en_new",
            )
            db.add(self.user)
            db.commit()

        app.dependency_overrides[db_session] = self._db_override
        app.dependency_overrides[current_user] = lambda: self.user
        self.client = TestClient(app)

    def tearDown(self):
        self.client.close()
        app.dependency_overrides.pop(db_session, None)
        app.dependency_overrides.pop(current_user, None)
        self.engine.dispose()

    def _db_override(self):
        db = self.Session()
        try:
            yield db
        finally:
            db.close()

    def _set_published(self, *lesson_ids, published=True):
        with self.Session() as db:
            for lesson_id in lesson_ids:
                db.get(Lesson, lesson_id).is_published = published
            db.commit()

    def _add_five_fillblank_exercises(self, lesson_id):
        with self.Session() as db:
            for sequence in range(1, 6):
                exercise_id = f"{lesson_id}_e{sequence}"
                db.add(Exercise(
                    id=exercise_id, lesson_id=lesson_id,
                    exercise_type="fillBlank", instruction="Choose the test option",
                    sequence=sequence,
                    options=[
                        {"id": f"{exercise_id}_yes", "text": "test-correct"},
                        {"id": f"{exercise_id}_no", "text": "test-wrong"},
                    ],
                    answer_id=f"{exercise_id}_yes",
                ))
            db.commit()

    def _answers(self, lesson_id, correct_count):
        return [
            {
                "exercise_id": f"{lesson_id}_e{sequence}",
                "selected_option_id": (
                    f"{lesson_id}_e{sequence}_{'yes' if sequence <= correct_count else 'no'}"
                ),
            }
            for sequence in range(1, 6)
        ]

    def _complete(self, lesson_id, score_count, key=None):
        payload = {"answers": self._answers(lesson_id, score_count)}
        if key is not None:
            payload["idempotency_key"] = key
        return self.client.post(f"/api/v1/lessons/{lesson_id}/attempts", json=payload)

    def _add_completion(self, lesson_id):
        with self.Session() as db:
            db.add(LessonCompletion(
                user_id=1, lesson_id=lesson_id, score=1.0, passed=True,
                xp_earned=20, correct_answers=5, total_questions=5,
            ))
            db.commit()

    def test_fifteen_slots_legacy_isolation_zero_publication_and_metadata(self):
        response = self.client.get("/api/v1/courses/en_new/town-map")
        self.assertEqual(response.status_code, 200)
        rows = response.json()
        self.assertEqual(len(rows), 15)
        self.assertEqual(sum(row["planned_exercise_count"] for row in rows), 111)
        self.assertEqual(sum(row["populated_exercise_count"] for row in rows), 0)
        self.assertTrue(all(not row["is_published"] for row in rows))
        self.assertNotIn("legacy_en_new_lesson", {row["id"] for row in rows})
        self.assertEqual(rows[0]["availability"], "unavailable")

        metadata = self.client.get("/api/v1/courses")
        self.assertEqual(metadata.status_code, 200)
        self.assertEqual([row["id"] for row in metadata.json()], ["en_new"])
        self.assertEqual(self.client.get("/api/v1/lessons?course_id=en_new").json(), [])

        units = self.client.get("/api/v1/courses/en_new/units")
        self.assertEqual(units.status_code, 200)
        self.assertEqual(len(units.json()), 5)
        self.assertEqual([unit["total_lessons"] for unit in units.json()], [3] * 5)

    def test_all_seven_exercise_types_complete_through_isolated_http_api(self):
        """Synthetic, test-only tokens exercise the full API contract in SQLite."""
        lesson_id = self.lesson_ids[0]
        fixtures = [
            Exercise(
                id="stage8_test_match", lesson_id=lesson_id,
                exercise_type="matchWords", instruction="TEST ONLY: match tokens",
                sequence=1, options=[
                    {"id": "m_d1", "text": "TEST-A", "is_devanagari": True,
                     "romanization": "fixture-a"},
                    {"id": "m_e1", "text": "TEST-EN-A"},
                    {"id": "m_d2", "text": "TEST-B", "is_devanagari": True,
                     "romanization": "fixture-b"},
                    {"id": "m_e2", "text": "TEST-EN-B"},
                ], pairs={"m_d1": "m_e1", "m_d2": "m_e2"},
                correct_answer_config={"pairs": {"m_d1": "m_e1", "m_d2": "m_e2"}},
            ),
            Exercise(
                id="stage8_test_fill", lesson_id=lesson_id,
                exercise_type="fillBlank", instruction="TEST ONLY: select token",
                sequence=2, options=[
                    {"id": "f_yes", "text": "TEST-CORRECT", "is_devanagari": True,
                     "romanization": "fixture-correct"},
                    {"id": "f_no", "text": "TEST-DISTRACTOR", "is_devanagari": True,
                     "romanization": "fixture-distractor"},
                ], answer_id="f_yes",
                correct_answer_config={"correct_option_id": "f_yes"},
            ),
            Exercise(
                id="stage8_test_picture_word", lesson_id=lesson_id,
                exercise_type="pictureToWord", instruction="TEST ONLY: identify image",
                sequence=3, image_key="droplet", options=[
                    {"id": "p_yes", "text": "TEST-WATER", "is_devanagari": True,
                     "romanization": "fixture-water"},
                    {"id": "p_no", "text": "TEST-OTHER", "is_devanagari": True,
                     "romanization": "fixture-other"},
                ], answer_id="p_yes",
                correct_answer_config={"correct_option_id": "p_yes"},
            ),
            Exercise(
                id="stage8_test_word_picture", lesson_id=lesson_id,
                exercise_type="wordToPicture", instruction="TEST ONLY: match image",
                sequence=4, prompt="TEST-WORD", newari_script="TEST-WORD",
                romanization="fixture-word", options=[
                    {"id": f"w_{key}", "text": f"TEST-{key}", "image_key": key}
                    for key in ("house", "droplet", "bowl", "person")
                ], answer_id="w_droplet",
                correct_answer_config={"correct_option_id": "w_droplet"},
            ),
            Exercise(
                id="stage8_test_translate", lesson_id=lesson_id,
                exercise_type="translate", instruction="TEST ONLY: choose word tile",
                sequence=5, prompt="TEST-ENGLISH", options=[],
                word_tiles=[
                    {"id": f"t_{index}", "text": f"TEST-TOKEN-{index}",
                     "is_devanagari": True, "romanization": f"fixture-{index}"}
                    for index in range(1, 5)
                ],
                correct_answer_config={"correct_sequence": ["t_2"],
                                       "alternative_sequences": []},
            ),
            Exercise(
                id="stage8_test_word_order", lesson_id=lesson_id,
                exercise_type="wordOrder", instruction="TEST ONLY: arrange tokens",
                sequence=6, options=[],
                word_tiles=[
                    {"id": "o_1", "text": "TEST-SUBJECT", "is_devanagari": True,
                     "romanization": "fixture-subject"},
                    {"id": "o_2", "text": "TEST-VERB", "is_devanagari": True,
                     "romanization": "fixture-verb"},
                ],
                correct_answer_config={"correct_sequence": ["o_1", "o_2"],
                                       "alternative_sequences": []},
            ),
            Exercise(
                id="stage8_test_dialogue", lesson_id=lesson_id,
                exercise_type="dialogueComplete", instruction="TEST ONLY: choose response",
                sequence=7, options=[
                    {"id": "d_yes", "text": "TEST-RESPONSE", "is_devanagari": True,
                     "romanization": "fixture-response"},
                    {"id": "d_no", "text": "TEST-DISTRACTOR", "is_devanagari": True,
                     "romanization": "fixture-distractor"},
                ], answer_id="d_yes",
                correct_answer_config={"correct_option_id": "d_yes"},
                dialogue_structure=[
                    {"speaker": "A", "text": "TEST PROMPT", "missing": False},
                    {"speaker": "B", "text": "", "missing": True},
                ],
            ),
        ]
        with self.Session() as db:
            db.add_all(fixtures)
            db.get(Lesson, lesson_id).is_published = True
            db.commit()

        response = self.client.get(f"/api/v1/lessons/{lesson_id}/exercises")
        self.assertEqual(response.status_code, 200)
        payloads = response.json()
        self.assertEqual({row["exercise_type"] for row in payloads}, {
            "matchWords", "fillBlank", "pictureToWord", "wordToPicture",
            "translate", "wordOrder", "dialogueComplete",
        })
        public_by_type = {row["exercise_type"]: row for row in payloads}
        self.assertIsNone(public_by_type["translate"]["newari_script"])
        self.assertIsNone(public_by_type["translate"]["romanization"])
        self.assertIsNone(public_by_type["wordOrder"]["romanization"])
        self.assertIsNone(public_by_type["wordToPicture"]["newari_script"])
        self.assertEqual(public_by_type["wordToPicture"]["romanization"], "fixture-word")

        answers = [
            {"exercise_id": "stage8_test_match", "selected_pairs": {"m_d1": "m_e1", "m_d2": "m_e2"}},
            {"exercise_id": "stage8_test_fill", "selected_option_id": "f_yes"},
            {"exercise_id": "stage8_test_picture_word", "selected_option_id": "p_yes"},
            {"exercise_id": "stage8_test_word_picture", "selected_option_id": "w_droplet"},
            {"exercise_id": "stage8_test_translate", "selected_tile_ids": ["t_2"]},
            {"exercise_id": "stage8_test_word_order", "selected_tile_ids": ["o_1", "o_2"]},
            {"exercise_id": "stage8_test_dialogue", "selected_option_id": "d_yes"},
        ]
        for answer in answers:
            checked = self.client.post(
                f"/api/v1/lessons/{lesson_id}/answer",
                json={"exercise_id": answer["exercise_id"], **{
                    key: value for key, value in answer.items()
                    if key != "exercise_id"
                }},
            )
            self.assertEqual(checked.status_code, 200, checked.text)
            self.assertTrue(checked.json()["correct"])

        completed = self.client.post(
            f"/api/v1/lessons/{lesson_id}/attempts",
            json={"answers": answers, "idempotency_key": "stage8-seven-type-fixture"},
        )
        self.assertEqual(completed.status_code, 200, completed.text)
        self.assertTrue(completed.json()["passed"])
        self.assertEqual(completed.json()["total_questions"], 7)

    def test_sequential_unlocks_require_published_completed_prerequisites(self):
        l1, l2, l3, l4 = self.lesson_ids[:4]
        self._set_published(l1, l2, l3, l4)
        rows = {row["id"]: row for row in self.client.get("/api/v1/courses/en_new/town-map").json()}
        self.assertEqual(rows[l1]["availability"], "available")
        self.assertEqual(rows[l2]["availability"], "locked")
        self.assertEqual(rows[l4]["availability"], "locked")

        self._add_completion(l1)
        rows = {row["id"]: row for row in self.client.get("/api/v1/courses/en_new/town-map").json()}
        self.assertEqual(rows[l1]["availability"], "completed")
        self.assertEqual(rows[l2]["availability"], "available")
        self.assertEqual(rows[l3]["availability"], "locked")
        self._add_completion(l2)
        self.assertEqual(
            {row["id"]: row["availability"] for row in self.client.get("/api/v1/courses/en_new/town-map").json()}[l3],
            "available",
        )

        self._set_published(l3, published=False)
        self._add_completion(l3)
        rows = {row["id"]: row["availability"] for row in self.client.get("/api/v1/courses/en_new/town-map").json()}
        self.assertEqual(rows[l3], "unavailable")
        self.assertEqual(rows[l4], "locked")
        self._set_published(l3, published=True)
        rows = {row["id"]: row["availability"] for row in self.client.get("/api/v1/courses/en_new/town-map").json()}
        self.assertEqual(rows[l4], "available")

    def test_locked_and_unpublished_exercise_routes_reject_access(self):
        l1, l2 = self.lesson_ids[:2]
        self._add_five_fillblank_exercises(l1)
        self._add_five_fillblank_exercises(l2)
        self._set_published(l2)
        self.assertEqual(self.client.get(f"/api/v1/lessons/{l2}/exercises").status_code, 403)
        self.assertEqual(self.client.post(
            f"/api/v1/lessons/{l2}/answer",
            json={"exercise_id": f"{l2}_e1", "selected_option_id": f"{l2}_e1_yes"},
        ).status_code, 403)
        self.assertEqual(self._complete(l2, 5).status_code, 403)
        self.assertEqual(self.client.get(f"/api/v1/lessons/{l1}/exercises").status_code, 403)
        self.assertEqual(self.client.get("/api/v1/lessons/legacy_en_new_lesson/exercises").status_code, 403)

    def test_ordinary_lessons_require_exactly_one_hundred_percent(self):
        lesson_id = self.lesson_ids[0]
        self._add_five_fillblank_exercises(lesson_id)
        self._set_published(lesson_id, self.lesson_ids[1])
        failed = self._complete(lesson_id, 4)
        self.assertEqual(failed.status_code, 200)
        self.assertFalse(failed.json()["passed"])
        self.assertEqual(failed.json()["score"], 0.8)
        self.assertEqual(failed.json()["xp_earned"], 0)
        self.assertEqual(
            self.client.get("/api/v1/courses/en_new/units").json()[0]["cleared_lessons"],
            0,
        )
        with self.Session() as db:
            self.assertEqual(db.query(LessonCompletion).filter_by(user_id=1, lesson_id=lesson_id).count(), 0)
            self.assertEqual(db.get(User, 1).xp, 0)

        passed = self._complete(lesson_id, 5)
        self.assertEqual(passed.status_code, 200)
        self.assertTrue(passed.json()["passed"])
        self.assertEqual(passed.json()["score"], 1.0)
        self.assertEqual(passed.json()["xp_earned"], 20)
        self.assertEqual(
            self.client.get("/api/v1/courses/en_new/units").json()[0]["cleared_lessons"],
            1,
        )
        rows = {row["id"]: row["availability"] for row in self.client.get("/api/v1/courses/en_new/town-map").json()}
        self.assertEqual(rows[self.lesson_ids[1]], "available")

    def test_checkpoint_exact_eighty_passes_and_failed_attempt_is_retryable(self):
        lesson_id = self.lesson_ids[2]
        next_lesson_id = self.lesson_ids[3]
        self._add_five_fillblank_exercises(lesson_id)
        self._set_published(self.lesson_ids[0], self.lesson_ids[1], lesson_id, next_lesson_id)
        self._add_completion(self.lesson_ids[0])
        self._add_completion(self.lesson_ids[1])

        failed = self._complete(lesson_id, 3)
        self.assertEqual(failed.status_code, 200)
        self.assertFalse(failed.json()["passed"])
        self.assertEqual(failed.json()["xp_earned"], 0)
        self.assertEqual(
            {row["id"]: row["availability"] for row in self.client.get("/api/v1/courses/en_new/town-map").json()}[next_lesson_id],
            "locked",
        )

        passed = self._complete(lesson_id, 4)
        self.assertEqual(passed.status_code, 200)
        self.assertTrue(passed.json()["passed"])
        self.assertFalse(passed.json()["is_correct"])
        self.assertEqual(passed.json()["passing_threshold"], 80)
        self.assertEqual(passed.json()["score"], 0.8)
        self.assertEqual(passed.json()["xp_earned"], 20)
        self.assertEqual(
            {row["id"]: row["availability"] for row in self.client.get("/api/v1/courses/en_new/town-map").json()}[next_lesson_id],
            "available",
        )
        retry = self._complete(lesson_id, 5)
        self.assertEqual(retry.status_code, 200)
        self.assertEqual(retry.json()["xp_earned"], 0)

    def test_capstone_completes_course_only_after_all_fifteen(self):
        capstone_id = self.lesson_ids[-1]
        self._add_five_fillblank_exercises(capstone_id)
        self._set_published(*self.lesson_ids)
        for lesson_id in self.lesson_ids[:-1]:
            self._add_completion(lesson_id)
        before = self.client.get("/api/v1/courses/en_new/progress").json()
        self.assertEqual(before["completed_lessons"], 14)
        self.assertFalse(before["is_complete"])

        response = self._complete(capstone_id, 4)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["passed"])
        after = self.client.get("/api/v1/courses/en_new/progress").json()
        self.assertEqual(after["completed_lessons"], 15)
        self.assertTrue(after["is_complete"])

    def test_completed_progression_survives_database_reopen(self):
        """A file-backed isolated database models application process restart."""
        handle, path = tempfile.mkstemp(prefix="glossa-stage6-restart-", suffix=".db")
        os.close(handle)
        engine = create_engine(f"sqlite:///{path}")
        try:
            Base.metadata.create_all(engine)
            Session = sessionmaker(bind=engine, expire_on_commit=False)
            with Session() as db:
                db.add(User(id=41, name="Persistence", email="persist@example.test",
                            password_hash="unused", active_course_id="en_new",
                            xp=240, level=3, streak=7))
                db.flush()
                db.add(LessonCompletion(user_id=41, lesson_id=self.lesson_ids[0],
                                        score=1.0, passed=True, xp_earned=20,
                                        correct_answers=5, total_questions=5))
                db.commit()
            engine.dispose()

            # Recreate engine and session as a restarted backend process would.
            engine = create_engine(f"sqlite:///{path}")
            Session = sessionmaker(bind=engine)
            with Session() as db:
                user = db.get(User, 41)
                completion = db.scalar(select(LessonCompletion).where(
                    LessonCompletion.user_id == 41,
                    LessonCompletion.lesson_id == self.lesson_ids[0],
                ))
                self.assertEqual((user.xp, user.level, user.streak), (240, 3, 7))
                self.assertIsNotNone(completion)
                self.assertTrue(completion.passed)
                self.assertEqual(completion.xp_earned, 20)
        finally:
            engine.dispose()
            os.unlink(path)


if __name__ == "__main__":
    unittest.main()
