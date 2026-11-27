"""Idempotently seed the active Newari curriculum from its source JSON."""

import logging

from app.curriculum_blueprint import CURRICULUM_VERSION, seed_curriculum
from app.database import SessionLocal
from app.models import Course, Language

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("seed")

LANGUAGES = (
    ("en", "English", "English", "Latin"),
    ("new", "Newari", "नेपाल भाषा", "Devanagari"),
)
ACTIVE_COURSE = {
    "id": "en_new",
    "source_language_id": "en",
    "target_language_id": "new",
    "name": "English → Newari",
    "description": "Learn Newari starting from English",
}


def seed() -> None:
    """Create missing metadata and import curriculum in one transaction."""
    with SessionLocal() as db:
        try:
            for language_id, english, native, script in LANGUAGES:
                if db.get(Language, language_id) is None:
                    db.add(
                        Language(
                            id=language_id,
                            name_english=english,
                            name_native=native,
                            script=script,
                            is_active=True,
                        )
                    )
            db.flush()

            course = db.get(Course, ACTIVE_COURSE["id"])
            if course is None:
                course = Course(**ACTIVE_COURSE, is_published=True, is_active=True)
                db.add(course)
            else:
                course.name = ACTIVE_COURSE["name"]
                course.description = ACTIVE_COURSE["description"]
                course.is_active = True
            db.flush()

            report = seed_curriculum(db, course_id=ACTIVE_COURSE["id"])
            db.commit()
        except Exception:
            db.rollback()
            raise

    logger.info(
        "Seeded %s: %d units, %d lessons, %d exercises, %d words, %d XP max "
        "(created %d lessons and %d exercises)",
        CURRICULUM_VERSION,
        report["unit_count"],
        report["lesson_count"],
        report["exercise_count"],
        report["word_count"],
        report["xp_max"],
        report["lessons_created"],
        report["exercises_created"],
    )


if __name__ == "__main__":
    seed()
