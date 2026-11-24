"""Glossa curriculum seeder.

Idempotently seeds languages, courses, units, lessons, and exercises.
Preserves existing legacy lessons and attempts.
Also imports validated Newari vocabulary and seeds the Newari
curriculum blueprint (15 lessons, unpublished until verified).

Run with: python seed.py
"""

import logging
from pathlib import Path

from sqlalchemy import select

from app.database import SessionLocal, engine
from app.models import Course, Exercise, Language, Lesson, Unit
from app.vocabulary_importer import import_vocabulary
from app.curriculum_blueprint import seed_blueprint
from curriculum import UNIT_THEMES, generate_course_lessons, get_curriculum_coverage_report

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("seed")

# ─── Legacy lessons (preserved from original seed) ─────────────

LEGACY_LESSONS = [
    ("lesson_1", "Rice and Bread", "Match · 4 words", "matchWords", 20, 4, 1),
    ("lesson_2", "Around the House", "Fill in the blank · +20 XP", "fillBlank", 20, 4, 3),
    ("lesson_3", "Fruits and Veggies", "Picture to word", "pictureToWord", 20, 4, 4),
    ("lesson_4", "Grandma's Kitchen", "Word to picture", "wordToPicture", 20, 4, 5),
    ("lesson_5", "Family at Home", "Audio lesson", "matchWords", 25, 5, 6),
    ("lesson_6", "Festival Feast", "Speak and record", "fillBlank", 30, 6, 7),
    ("lesson_7", "Testing exercises", "Test and Test", "fillBlank", 30, 6, 7),
]

LEGACY_EXERCISES = [
    dict(id="mw_1", lesson_id="lesson_1", exercise_type="matchWords", instruction="Match the words",
         options=[{"id": "mw_d1", "text": "माँ", "is_devanagari": True}, {"id": "mw_e1", "text": "Mother"},
                  {"id": "mw_d2", "text": "ल", "is_devanagari": True}, {"id": "mw_e2", "text": "House"},
                  {"id": "mw_d3", "text": "छें", "is_devanagari": True}, {"id": "mw_e3", "text": "Water"},
                  {"id": "mw_d4", "text": "बजि", "is_devanagari": True}, {"id": "mw_e4", "text": "Beaten rice"}],
         pairs={"mw_d1": "mw_e1", "mw_d2": "mw_e2", "mw_d3": "mw_e3", "mw_d4": "mw_e4"}),
    dict(id="fb_1", lesson_id="lesson_2", exercise_type="fillBlank", instruction="Fill in the blank",
         prompt="दौ ___", prompt_hint="Yogurt and beaten rice",
         options=[{"id": "fb_a", "text": "बजि", "is_devanagari": True}, {"id": "fb_b", "text": "ल", "is_devanagari": True},
                 {"id": "fb_c", "text": "छें", "is_devanagari": True}], answer_id="fb_a"),
    dict(id="fb_2", lesson_id="lesson_2", exercise_type="fillBlank", instruction="Fill in the blank",
         prompt="___ खा", prompt_hint="Eating at home",
         options=[{"id": "fb2_a", "text": "ल", "is_devanagari": True}, {"id": "fb2_b", "text": "माँ", "is_devanagari": True},
                 {"id": "fb2_c", "text": "छें", "is_devanagari": True}], answer_id="fb2_a"),
    dict(id="ptw_1", lesson_id="lesson_3", exercise_type="pictureToWord", instruction="Name the picture",
         prompt="What is this called?", image_key="bowl",
         options=[{"id": "ptw_a", "text": "बजि", "is_devanagari": True}, {"id": "ptw_b", "text": "छें", "is_devanagari": True},
                 {"id": "ptw_c", "text": "ल", "is_devanagari": True}, {"id": "ptw_d", "text": "माँ", "is_devanagari": True}],
         answer_id="ptw_a"),
    dict(id="wtp_1", lesson_id="lesson_4", exercise_type="wordToPicture", instruction="Pick the picture",
         prompt="Which picture is this?",
         options=[{"id": "wtp_a", "text": "House", "image_key": "house"}, {"id": "wtp_b", "text": "Water", "image_key": "droplet"},
                  {"id": "wtp_c", "text": "Bowl", "image_key": "bowl"}, {"id": "wtp_d", "text": "Person", "image_key": "person"}],
         answer_id="wtp_a"),
    dict(id="fb5_1", lesson_id="lesson_5", exercise_type="fillBlank", instruction="Fill in the blank",
         prompt="___ खा", prompt_hint="Eating at home",
         options=[{"id": "fb5_a", "text": "ल", "is_devanagari": True}, {"id": "fb5_b", "text": "माँ", "is_devanagari": True},
                 {"id": "fb5_c", "text": "छें", "is_devanagari": True}], answer_id="fb5_a"),
    dict(id="fb6_1", lesson_id="lesson_6", exercise_type="fillBlank", instruction="Fill in the blank",
         prompt="दौ ___", prompt_hint="Yogurt and beaten rice",
         options=[{"id": "fb6_a", "text": "बजि", "is_devanagari": True}, {"id": "fb6_b", "text": "ल", "is_devanagari": True},
                 {"id": "fb6_c", "text": "छें", "is_devanagari": True}], answer_id="fb6_a"),
    dict(id="fb7_1", lesson_id="lesson_7", exercise_type="fillBlank", instruction="Fill in the blank",
         prompt="दौ ___", prompt_hint="Yogurt and beaten rice",
         options=[{"id": "fb6_a", "text": "बजि", "is_devanagari": True}, {"id": "fb6_b", "text": "ल", "is_devanagari": True},
                 {"id": "fb6_c", "text": "छें", "is_devanagari": True}], answer_id="fb6_a"),
]

COURSES = [
    ("en_new", "en", "new", "English → Newari", "Learn Newari starting from English"),
]

LANGUAGES = [
    ("en", "English", "English", "Latin", True),
    ("new", "Newari", "नेपाल भाषा", "Devanagari", True),
]


def seed():
    """Idempotently seed all curriculum data."""
    with SessionLocal() as db:
        # ─── Languages ─────────────────────────────────────────
        for lang_id, name_en, name_nat, script, is_active in LANGUAGES:
            if db.get(Language, lang_id) is None:
                db.add(Language(id=lang_id, name_english=name_en, name_native=name_nat,
                                script=script, is_active=is_active))
                logger.info("Created language: %s", lang_id)
        db.commit()

        # ─── Courses ────────────────────────────────────────────
        # Only en_new (English -> Newari) is active. Legacy course directions
        # are retired but their rows are preserved for historical data.
        published_courses = {"en_new"}
        active_courses = {"en_new"}
        for course_id, src, tgt, name, desc in COURSES:
            existing = db.get(Course, course_id)
            if existing is None:
                db.add(Course(
                    id=course_id, source_language_id=src, target_language_id=tgt,
                    name=name, description=desc,
                    is_published=course_id in published_courses,
                    is_active=course_id in active_courses,
                ))
                logger.info("Created course: %s (published=%s, active=%s)",
                            course_id, course_id in published_courses, course_id in active_courses)
            else:
                # Update published/active status for existing courses
                if course_id in published_courses and not existing.is_published:
                    existing.is_published = True
                    logger.info("Published course: %s", course_id)
                if course_id in active_courses and not existing.is_active:
                    existing.is_active = True
                    logger.info("Activated course: %s", course_id)
                if course_id not in active_courses and existing.is_active:
                    existing.is_active = False
                    logger.info("Retired course: %s", course_id)
        db.commit()

        # ─── Legacy lessons (preserve existing) ─────────────────
        # These are in the legacy unit created by migration 0003.
        # Only create them if they don't already exist (fresh install without migration).
        legacy_unit = db.scalar(
            select(Unit).where(Unit.course_id == "new_en", Unit.sequence == 0)
        )
        if legacy_unit is None:
            # Fresh install: create legacy unit
            legacy_unit = Unit(course_id="new_en", sequence=0,
                               title="Legacy Content - Unverified",
                               description="Existing lessons preserved from before multi-language migration.")
            db.add(legacy_unit)
            db.commit()
            db.refresh(legacy_unit)

        for lesson_data in LEGACY_LESSONS:
            existing = db.get(Lesson, lesson_data[0])
            if existing is None:
                db.add(Lesson(
                    id=lesson_data[0], unit_id=legacy_unit.id,
                    sequence=lesson_data[0][-1],  # Use as sequence
                    title=lesson_data[1], subtitle=lesson_data[2],
                    exercise_type=lesson_data[3], xp_reward=lesson_data[4],
                    word_count=lesson_data[5], required_level=lesson_data[6],
                    is_published=False,  # Legacy content is never published
                ))
        db.commit()

        for exercise_data in LEGACY_EXERCISES:
            existing = db.get(Exercise, exercise_data["id"])
            if existing is None:
                db.add(Exercise(**exercise_data))
        db.commit()

        # ─── Curriculum units and lessons ────────────────────────
        for course_id, src, tgt, name, desc in COURSES:
            # Create 10 units for this course (skip if they already exist)
            existing_units = list(db.scalars(
                select(Unit).where(Unit.course_id == course_id, Unit.sequence > 0).order_by(Unit.sequence)
            ).all())

            if len(existing_units) >= 10:
                logger.info("Course %s already has %d curriculum units, skipping", course_id, len(existing_units))
                units = existing_units
            else:
                units = []
                for seq in range(1, 11):
                    theme = UNIT_THEMES[seq - 1] if seq <= len(UNIT_THEMES) else f"Unit {seq}"
                    unit = Unit(
                        course_id=course_id, sequence=seq,
                        title=theme,
                        description=f"{theme} - {name}",
                    )
                    db.add(unit)
                    units.append(unit)
                db.commit()
                for u in units:
                    db.refresh(u)
                logger.info("Created 10 curriculum units for course: %s", course_id)

            # Generate and seed lessons
            generated_lessons = generate_course_lessons(course_id, units, src, tgt)
            for gl in generated_lessons:
                existing = db.get(Lesson, gl.lesson_id)
                if existing is None:
                    db.add(Lesson(
                        id=gl.lesson_id, unit_id=gl.unit_id, sequence=gl.sequence,
                        title=gl.title, subtitle=gl.subtitle,
                        exercise_type=gl.exercise_type, xp_reward=gl.xp_reward,
                        word_count=gl.word_count, required_level=gl.required_level,
                        is_published=gl.is_published,
                    ))
                elif existing.is_published != gl.is_published:
                    # Sync published status
                    existing.is_published = gl.is_published
            db.commit()

            # Generate and seed exercises
            for gl in generated_lessons:
                if not gl.exercises:
                    continue
                for ex_data in gl.exercises:
                    existing = db.get(Exercise, ex_data["id"])
                    if existing is None:
                        # Strip the 'id' and 'sequence' from the dict since they map to columns
                        ex = Exercise(
                            id=ex_data["id"],
                            lesson_id=gl.lesson_id,
                            exercise_type=ex_data["exercise_type"],
                            instruction=ex_data["instruction"],
                            prompt=ex_data.get("prompt"),
                            prompt_hint=ex_data.get("prompt_hint"),
                            image_key=ex_data.get("image_key"),
                            audio_key=ex_data.get("audio_key"),
                            sequence=ex_data.get("sequence"),
                            options=ex_data["options"],
                            answer_id=ex_data.get("answer_id"),
                            pairs=ex_data.get("pairs"),
                        )
                        db.add(ex)
            db.commit()

            logger.info("Seeded lessons and exercises for course: %s", course_id)

        # ─── Newari vocabulary import + curriculum blueprint ─────
        # Import validated vocabulary (idempotent, no duplicates).
        xlsx_path = Path(__file__).resolve().parent.parent / "newari_vocabulary.xlsx"
        vocab_report = import_vocabulary(db, str(xlsx_path))
        logger.info(
            "Vocabulary import: %d created, %d already existed, %d total in DB",
            vocab_report.imported_count, vocab_report.already_existed_count,
            vocab_report.imported_count + vocab_report.already_existed_count,
        )

        # Seed the 15-lesson Newari blueprint for en_new (unpublished).
        blueprint_report = seed_blueprint(db, course_id="en_new")
        logger.info(
            "Newari blueprint: %d lessons created, %d existed; "
            "%d exercises created, %d existed; %d vocab links created",
            blueprint_report["lessons_created"], blueprint_report["lessons_existed"],
            blueprint_report["exercises_created"], blueprint_report["exercises_existed"],
            blueprint_report["vocab_links_created"],
        )

        # ─── Coverage report ────────────────────────────────────
        report = get_curriculum_coverage_report()
        logger.info("=== Curriculum Coverage Report ===")
        for cid, data in report.items():
            logger.info(
                "  %s: %d units, %d lessons (%d with exercises, %d published, %d awaiting verification)",
                cid, data["units_created"], data["lesson_slots_created"],
                data["lessons_with_exercises"], data["lessons_published"],
                data["lessons_awaiting_verification"],
            )
        logger.info("=== Seeding complete ===")


if __name__ == "__main__":
    seed()
