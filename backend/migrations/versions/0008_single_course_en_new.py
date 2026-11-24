"""Single-course English->Newari migration (Stage 5).

Adds:
  * is_active flag on courses table (default True).
  * Retires legacy course directions (en_ne, ne_en, new_en, ne_new, new_ne)
    by setting is_active = False.
  * Sets en_new (English -> Newari) as active.
  * Backfills existing users with NULL active_course_id to en_new.

Purely additive where possible; no existing tables, columns, or records are
deleted. Historical attempts, lessons, exercises, and user progress are
preserved.

A new `is_active` column on courses distinguishes the single active course
(en_new) from retired legacy course directions. Course availability for
learning is gated on is_active=True at the API layer.
"""

import logging

import sqlalchemy as sa
from alembic import op

revision = "0008_single_course_en_new"
down_revision = "0007_publication_and_xp_protection"
branch_labels = None
depends_on = None

logger = logging.getLogger("alembic.runtime.migration")


def _table_exists(bind, table_name: str) -> bool:
    return table_name in sa.inspect(bind).get_table_names()


def _column_exists(bind, table_name: str, column_name: str) -> bool:
    if table_name not in sa.inspect(bind).get_table_names():
        return False
    return column_name in {col["name"] for col in sa.inspect(bind).get_columns(table_name)}


def _constraint_exists(bind, table_name: str, constraint_name: str) -> bool:
    inspector = sa.inspect(bind)
    if table_name not in inspector.get_table_names():
        return False
    return constraint_name in {
        c["name"] for c in inspector.get_unique_constraints(table_name)
    }


def upgrade():
    bind = op.get_bind()

    # ─── Add is_active column to courses ─────────────────────────
    if not _column_exists(bind, "courses", "is_active"):
        logger.info("Adding is_active column to courses")
        op.add_column(
            "courses",
            sa.Column("is_active", sa.Boolean, server_default=sa.true(), nullable=False),
        )

    # ─── Retire legacy course directions ─────────────────────────
    # en_new (English -> Newari) remains active. All other course directions
    # are retired from normal learning access but their rows (and all
    # associated lessons, exercises, attempts, units) are preserved.
    logger.info("Retiring legacy course directions; keeping en_new active")
    bind.execute(
        sa.text(
            "UPDATE courses SET is_active = false WHERE id IN "
            "('en_ne', 'ne_en', 'new_en', 'ne_new', 'new_ne')"
        )
    )
    # Ensure en_new is active
    bind.execute(
        sa.text("UPDATE courses SET is_active = true WHERE id = 'en_new'")
    )

    # ─── Backfill existing users to en_new ───────────────────────
    # Users with NULL active_course_id get assigned to en_new.
    # Users already pointing at a retired course are repointed to en_new.
    logger.info("Backfilling existing users to en_new course")
    bind.execute(
        sa.text(
            "UPDATE users SET active_course_id = 'en_new' "
            "WHERE active_course_id IS NULL OR active_course_id IN "
            "('en_ne', 'ne_en', 'new_en', 'ne_new', 'new_ne')"
        )
    )

    logger.info("Migration 0008 completed successfully")


def downgrade():
    bind = op.get_bind()

    # Re-activate all retired courses
    bind.execute(
        sa.text("UPDATE courses SET is_active = true WHERE id IN "
            "('en_ne', 'ne_en', 'new_en', 'ne_new', 'new_ne', 'en_new')")
    )

    # Drop is_active column
    if _column_exists(bind, "courses", "is_active"):
        op.drop_column("courses", "is_active")

    logger.info("Migration 0008 downgrade completed")
