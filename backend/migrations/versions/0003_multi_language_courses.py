"""Multi-language course architecture: languages, courses, units tables.

Adds Language, Course, and Unit tables. Links lessons to units and users to
active courses. Preserves all existing lessons, exercises, and attempts.
"""

import logging
import sqlalchemy as sa
from alembic import op

revision = "0003_multi_language_courses"
down_revision = "0002_user_activity_date"
branch_labels = None
depends_on = None

logger = logging.getLogger("alembic.runtime.migration")


def _table_exists(bind, table_name: str) -> bool:
    inspector = sa.inspect(bind)
    return table_name in inspector.get_table_names()


def _column_exists(bind, table_name: str, column_name: str) -> bool:
    inspector = sa.inspect(bind)
    if table_name not in inspector.get_table_names():
        return False
    return column_name in {col["name"] for col in inspector.get_columns(table_name)}


def upgrade():
    bind = op.get_bind()

    # ─── Pre-migration snapshot ───────────────────────────────
    lesson_count_before = bind.execute(
        sa.text("SELECT COUNT(*) FROM lessons")
    ).scalar()
    attempt_count_before = bind.execute(
        sa.text("SELECT COUNT(*) FROM attempts")
    ).scalar()
    user_count_before = bind.execute(
        sa.text("SELECT COUNT(*) FROM users")
    ).scalar()
    exercise_count_before = bind.execute(
        sa.text("SELECT COUNT(*) FROM exercises")
    ).scalar()
    logger.info("Pre-migration snapshot: %d lessons, %d exercises, %d attempts, %d users",
                lesson_count_before, exercise_count_before, attempt_count_before, user_count_before)

    # ─── Create languages table ───────────────────────────────
    if not _table_exists(bind, "languages"):
        logger.info("Creating languages table")
        op.create_table(
            "languages",
            sa.Column("id", sa.String(10), primary_key=True),
            sa.Column("name_english", sa.String(80), nullable=False),
            sa.Column("name_native", sa.String(80), nullable=False),
            sa.Column("script", sa.String(40), nullable=False),
            sa.Column("is_active", sa.Boolean, server_default=sa.true()),
        )

    # ─── Create courses table ─────────────────────────────────
    if not _table_exists(bind, "courses"):
        logger.info("Creating courses table")
        op.create_table(
            "courses",
            sa.Column("id", sa.String(40), primary_key=True),
            sa.Column("source_language_id", sa.String(10), sa.ForeignKey("languages.id"), nullable=False),
            sa.Column("target_language_id", sa.String(10), sa.ForeignKey("languages.id"), nullable=False),
            sa.Column("name", sa.String(120), nullable=False),
            sa.Column("description", sa.String(500), nullable=True),
            sa.Column("is_published", sa.Boolean, server_default=sa.false()),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
            sa.UniqueConstraint("source_language_id", "target_language_id", name="uq_source_target"),
        )

    # ─── Create units table ───────────────────────────────────
    if not _table_exists(bind, "units"):
        logger.info("Creating units table")
        op.create_table(
            "units",
            sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
            sa.Column("course_id", sa.String(40), sa.ForeignKey("courses.id"), nullable=False, index=True),
            sa.Column("sequence", sa.Integer, nullable=False),
            sa.Column("title", sa.String(120), nullable=False),
            sa.Column("description", sa.String(500), nullable=True),
            sa.UniqueConstraint("course_id", "sequence", name="uq_course_sequence"),
        )

    # ─── Add columns to lessons ───────────────────────────────
    if not _column_exists(bind, "lessons", "unit_id"):
        logger.info("Adding unit_id column to lessons")
        op.add_column("lessons", sa.Column("unit_id", sa.Integer, sa.ForeignKey("units.id"), nullable=True, index=True))
    if not _column_exists(bind, "lessons", "sequence"):
        logger.info("Adding sequence column to lessons")
        op.add_column("lessons", sa.Column("sequence", sa.Integer, nullable=True))
    if not _column_exists(bind, "lessons", "is_published"):
        logger.info("Adding is_published column to lessons")
        op.add_column("lessons", sa.Column("is_published", sa.Boolean, server_default=sa.false()))

    # ─── Add columns to exercises ──────────────────────────────
    if not _column_exists(bind, "exercises", "audio_key"):
        op.add_column("exercises", sa.Column("audio_key", sa.String(80), nullable=True))
    if not _column_exists(bind, "exercises", "sequence"):
        op.add_column("exercises", sa.Column("sequence", sa.Integer, nullable=True))

    # ─── Add column to users ───────────────────────────────────
    if not _column_exists(bind, "users", "active_course_id"):
        logger.info("Adding active_course_id column to users")
        op.add_column("users", sa.Column("active_course_id", sa.String(40), sa.ForeignKey("courses.id"), nullable=True, index=True))

    # ─── Seed languages ───────────────────────────────────────
    languages_data = [
        ("en", "English", "English", "Latin", True),
        ("ne", "Nepali", "नेपाली", "Devanagari", True),
        ("new", "Newari", "नेपाल भाषा", "Devanagari", True),
    ]
    for lang_id, name_en, name_nat, script, is_active in languages_data:
        existing = bind.execute(sa.text("SELECT id FROM languages WHERE id = :id"), {"id": lang_id}).scalar()
        if existing is None:
            bind.execute(sa.text(
                "INSERT INTO languages (id, name_english, name_native, script, is_active) "
                "VALUES (:id, :en, :nat, :script, :active)"
            ), {"id": lang_id, "en": name_en, "nat": name_nat, "script": script, "active": is_active})

    # ─── Seed courses ─────────────────────────────────────────
    courses_data = [
        ("en_ne", "en", "ne", "English → Nepali", "Learn Nepali starting from English"),
        ("ne_en", "ne", "en", "Nepali → English", "Learn English starting from Nepali"),
        ("en_new", "en", "new", "English → Newari", "Learn Newari starting from English"),
        ("new_en", "new", "en", "Newari → English", "Learn English starting from Newari"),
        ("ne_new", "ne", "new", "Nepali → Newari", "Learn Newari starting from Nepali"),
        ("new_ne", "new", "ne", "Newari → Nepali", "Learn Nepali starting from Newari"),
    ]
    for course_id, src, tgt, name, desc in courses_data:
        existing = bind.execute(sa.text("SELECT id FROM courses WHERE id = :id"), {"id": course_id}).scalar()
        if existing is None:
            if _column_exists(bind, "courses", "is_active"):
                bind.execute(sa.text(
                    "INSERT INTO courses (id, source_language_id, target_language_id, name, description, is_published, is_active) "
                    "VALUES (:id, :src, :tgt, :name, :desc, false, false)"
                ), {"id": course_id, "src": src, "tgt": tgt, "name": name, "desc": desc})
            else:
                bind.execute(sa.text(
                    "INSERT INTO courses (id, source_language_id, target_language_id, name, description, is_published) "
                    "VALUES (:id, :src, :tgt, :name, :desc, false)"
                ), {"id": course_id, "src": src, "tgt": tgt, "name": name, "desc": desc})

    # ─── Create legacy unit for existing lessons ──────────────
    legacy_unit = bind.execute(
        sa.text("SELECT id FROM units WHERE course_id = 'new_en' AND sequence = 0")
    ).scalar()
    if legacy_unit is None:
        if _column_exists(bind, "units", "curriculum_version"):
            bind.execute(sa.text(
                "INSERT INTO units "
                "(course_id, curriculum_version, sequence, title, description) "
                "VALUES ('new_en', 'legacy', 0, 'Legacy Content - Unverified', "
                "'Existing lessons preserved from before multi-language migration. "
                "Teaching direction not verified.')"
            ))
        else:
            bind.execute(sa.text(
                "INSERT INTO units (course_id, sequence, title, description) "
                "VALUES ('new_en', 0, 'Legacy Content - Unverified', "
                "'Existing lessons preserved from before multi-language migration. "
                "Teaching direction not verified.')"
            ))
        legacy_unit = bind.execute(
            sa.text("SELECT id FROM units WHERE course_id = 'new_en' AND sequence = 0")
        ).scalar()

    # ─── Assign existing lessons to legacy unit ────────────────
    existing_lesson_count = bind.execute(
        sa.text("SELECT COUNT(*) FROM lessons WHERE unit_id IS NULL")
    ).scalar()
    if existing_lesson_count > 0:
        logger.info("Migrating %d existing lessons to legacy unit (id=%s). "
                    "NOTE: new_en assignment is a TEMPORARY UNVERIFIED placeholder.",
                    existing_lesson_count, legacy_unit)
        # Assign sequence based on current id order
        lessons_without_unit = bind.execute(
            sa.text("SELECT id FROM lessons WHERE unit_id IS NULL ORDER BY id")
        ).fetchall()
        for seq, (lesson_id,) in enumerate(lessons_without_unit, start=1):
            bind.execute(sa.text(
                "UPDATE lessons SET unit_id = :unit_id, sequence = :seq, is_published = false "
                "WHERE id = :lesson_id"
            ), {"unit_id": legacy_unit, "seq": seq, "lesson_id": lesson_id})

    # ─── Backfill user active_course_id ────────────────────────
    users_to_backfill = bind.execute(
        sa.text("SELECT id, language_id FROM users WHERE active_course_id IS NULL")
    ).fetchall()
    logger.info("Backfilling active_course_id for %d users", len(users_to_backfill))

    lang_to_course = {
        "newari": "new_en",
        "nepali": "ne_en",
        "english": "en_ne",
    }
    for user_id, lang_id in users_to_backfill:
        course_id = lang_to_course.get(lang_id)
        if course_id is not None:
            bind.execute(sa.text(
                "UPDATE users SET active_course_id = :course_id WHERE id = :user_id"
            ), {"course_id": course_id, "user_id": user_id})
        else:
            # Unknown/unrecognised language_id → set NULL (already NULL) and log warning
            logger.warning("User id=%s has unrecognised language_id='%s', setting active_course_id=NULL",
                           user_id, lang_id)

    # ─── Post-migration validation ─────────────────────────────
    lesson_count_after = bind.execute(sa.text("SELECT COUNT(*) FROM lessons")).scalar()
    exercise_count_after = bind.execute(sa.text("SELECT COUNT(*) FROM exercises")).scalar()
    attempt_count_after = bind.execute(sa.text("SELECT COUNT(*) FROM attempts")).scalar()
    user_count_after = bind.execute(sa.text("SELECT COUNT(*) FROM users")).scalar()

    assert lesson_count_after == lesson_count_before, \
        f"Lesson count mismatch: before={lesson_count_before}, after={lesson_count_after}"
    assert exercise_count_after == exercise_count_before, \
        f"Exercise count mismatch: before={exercise_count_before}, after={exercise_count_after}"
    assert attempt_count_after == attempt_count_before, \
        f"Attempt count mismatch: before={attempt_count_before}, after={attempt_count_after}"
    assert user_count_after == user_count_before, \
        f"User count mismatch: before={user_count_before}, after={user_count_after}"

    # Verify recognised-language users have non-null active_course_id
    unbackfilled = bind.execute(sa.text(
        "SELECT COUNT(*) FROM users WHERE active_course_id IS NULL "
        "AND language_id IN ('newari', 'nepali', 'english')"
    )).scalar()
    assert unbackfilled == 0, \
        f"{unbackfilled} users with recognised language_id have NULL active_course_id"

    logger.info("Migration 0003 completed successfully - all integrity checks passed")


def downgrade():
    bind = op.get_bind()

    # Drop added columns from users
    if _column_exists(bind, "users", "active_course_id"):
        op.drop_index("ix_users_active_course_id", table_name="users") if _index_exists(bind, "users", "ix_users_active_course_id") else None
        op.drop_column("users", "active_course_id")

    # Drop added columns from exercises
    if _column_exists(bind, "exercises", "sequence"):
        op.drop_column("exercises", "sequence")
    if _column_exists(bind, "exercises", "audio_key"):
        op.drop_column("exercises", "audio_key")

    # Drop added columns from lessons
    if _column_exists(bind, "lessons", "is_published"):
        op.drop_column("lessons", "is_published")
    if _column_exists(bind, "lessons", "sequence"):
        op.drop_column("lessons", "sequence")
    if _column_exists(bind, "lessons", "unit_id"):
        op.drop_index("ix_lessons_unit_id", table_name="lessons") if _index_exists(bind, "lessons", "ix_lessons_unit_id") else None
        op.drop_column("lessons", "unit_id")

    # Drop tables in reverse dependency order
    if _table_exists(bind, "units"):
        op.drop_table("units")
    if _table_exists(bind, "courses"):
        op.drop_table("courses")
    if _table_exists(bind, "languages"):
        op.drop_table("languages")


def _index_exists(bind, table_name: str, index_name: str) -> bool:
    inspector = sa.inspect(bind)
    if table_name not in inspector.get_table_names():
        return False
    return index_name in {idx["name"] for idx in inspector.get_indexes(table_name)}
