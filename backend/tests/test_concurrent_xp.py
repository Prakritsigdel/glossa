"""In-memory regression tests for run idempotency constraints."""

import unittest

from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models import Attempt, Lesson, User


class TestAttemptIdempotency(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, expire_on_commit=False)
        with self.Session() as db:
            db.add_all(
                [
                    User(
                        id=1,
                        name="First learner",
                        email="first@example.com",
                        password_hash="unused",
                    ),
                    User(
                        id=2,
                        name="Second learner",
                        email="second@example.com",
                        password_hash="unused",
                    ),
                    Lesson(
                        id="lesson-one",
                        title="Lesson one",
                        subtitle="Unit",
                        exercise_type="fillBlank",
                    ),
                    Lesson(
                        id="lesson-two",
                        title="Lesson two",
                        subtitle="Unit",
                        exercise_type="fillBlank",
                    ),
                ]
            )
            db.commit()

    def tearDown(self):
        self.engine.dispose()

    def _attempt(self, user_id, lesson_id, key):
        return Attempt(
            user_id=user_id,
            lesson_id=lesson_id,
            attempt_number=1,
            idempotency_key=key,
            is_correct=False,
            correct_answers=0,
            total_questions=1,
            xp_earned=0,
            earned_xp=0,
        )

    def test_duplicate_run_key_for_same_user_is_rejected(self):
        with self.Session() as db:
            db.add(self._attempt(1, "lesson-one", "same-run"))
            db.commit()

        with self.Session() as db:
            db.add(self._attempt(1, "lesson-one", "same-run"))
            with self.assertRaises(IntegrityError):
                db.commit()

    def test_run_key_cannot_be_reused_for_another_lesson_by_same_user(self):
        with self.Session() as db:
            db.add(self._attempt(1, "lesson-one", "same-run"))
            db.commit()

        with self.Session() as db:
            db.add(self._attempt(1, "lesson-two", "same-run"))
            with self.assertRaises(IntegrityError):
                db.commit()

    def test_run_key_is_scoped_to_the_user(self):
        with self.Session() as db:
            db.add_all(
                [
                    self._attempt(1, "lesson-one", "shared-run"),
                    self._attempt(2, "lesson-one", "shared-run"),
                ]
            )
            db.commit()
            self.assertEqual(db.query(Attempt).count(), 2)


if __name__ == "__main__":
    unittest.main()
