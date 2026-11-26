"""Idempotently seed the active English-to-Newari pilot curriculum.

Historical courses and lesson rows are preserved, but startup never creates
or republishes the retired generated curriculum.
"""

import logging
from pathlib import Path

from sqlalchemy import select

from app.database import SessionLocal
from app.models import Course, Language, Unit
from app.curriculum_blueprint import (
    PLANNED_UNITS,
    get_curriculum_coverage_report,
    seed_blueprint,
)
from app.vocabulary_importer import import_vocabulary

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


def _vocabulary_path() -> Path:
    candidates = (
        Path("/newari_vocabulary.xlsx"),
        Path(__file__).resolve().parent.parent / "newari_vocabulary.xlsx",
    )
    return next((path for path in candidates if path.is_file()), candidates[-1])


def seed() -> None:
    """Seed active course metadata, vocabulary, and the unpublished blueprint."""
    with SessionLocal() as db:
        for language_id, english, native, script in LANGUAGES:
            if db.get(Language, language_id) is None:
                db.add(Language(
                    id=language_id,
                    name_english=english,
                    name_native=native,
                    script=script,
                    is_active=True,
                ))
        db.flush()

        course = db.get(Course, ACTIVE_COURSE["id"])
        if course is None:
            course = Course(**ACTIVE_COURSE, is_published=True, is_active=True)
            db.add(course)
        else:
            course.name = ACTIVE_COURSE["name"]
            course.description = ACTIVE_COURSE["description"]
            course.is_published = True
            course.is_active = True

        # Retired course rows remain intact and cannot be reactivated by seeding.
        for other in db.scalars(select(Course).where(Course.id != "en_new")):
            if other.is_active:
                other.is_active = False
        db.commit()

        units_by_sequence = {
            unit.sequence: unit
            for unit in db.scalars(
                select(Unit).where(
                    Unit.course_id == "en_new",
                    Unit.sequence.between(1, len(PLANNED_UNITS)),
                )
            )
        }
        for sequence, title in enumerate(PLANNED_UNITS, start=1):
            unit = units_by_sequence.get(sequence)
            if unit is None:
                unit = Unit(course_id="en_new", sequence=sequence, title=title)
                db.add(unit)
            else:
                unit.title = title
            unit.description = f"{title} · English to Newari pilot"
        db.commit()

        vocab_report = import_vocabulary(db, str(_vocabulary_path()))
        blueprint_report = seed_blueprint(db, course_id="en_new")
        logger.info(
            "Vocabulary import: %d new, %d existing, %d total",
            vocab_report.imported_count,
            vocab_report.already_existed_count,
            vocab_report.imported_count + vocab_report.already_existed_count,
        )
        logger.info(
            "Active blueprint seed: %d lessons created, %d existing; "
            "%d exercises created, %d existing; %d vocabulary links created",
            blueprint_report["lessons_created"],
            blueprint_report["lessons_existed"],
            blueprint_report["exercises_created"],
            blueprint_report["exercises_existed"],
            blueprint_report["vocab_links_created"],
        )
        coverage = get_curriculum_coverage_report(db)
        logger.info("=== Curriculum Coverage Report ===")
        logger.info("  Active blueprint: %s", coverage["active_blueprint"])
        logger.info("  Preserved historical records: %s", coverage["historical_records"])


if __name__ == "__main__":
    seed()
