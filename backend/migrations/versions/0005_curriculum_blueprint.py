"""Curriculum blueprint for the English -> Newari pilot course.

Adds:
  * is_checkpoint flag on lessons (course plan section 6: checkpoint /
    capstone lessons for unlock gating and special styling).
  * lesson_vocabulary association table linking lessons to validated
    vocabulary entries, with a role column distinguishing introduced
    vs reviewed vocabulary.

This migration is purely additive: no existing tables or columns are
modified, and no existing curriculum records are touched. All new
curriculum content remains unpublished until native-speaker verification.
"""

import logging

import sqlalchemy as sa
from alembic import op

revision = "0005_curriculum_blueprint"
down_revision = "0004_vocabulary_entries"
branch_labels = None
depends_on = None

logger = logging.getLogger("alembic.runtime.migration")


def _table_exists(bind, table_name: str) -> bool:
    return table_name in sa.inspect(bind).get_table_names()


def _column_exists(bind, table_name: str, column_name: str) -> bool:
    if table_name not in sa.inspect(bind).get_table_names():
        return False
    return column_name in {col["name"] for col in sa.inspect(bind).get_columns(table_name)}


def upgrade():
    bind = op.get_bind()

    # ─── is_checkpoint on lessons ────────────────────────────────
    if not _column_exists(bind, "lessons", "is_checkpoint"):
        logger.info("Adding is_checkpoint column to lessons")
        op.add_column(
            "lessons",
            sa.Column("is_checkpoint", sa.Boolean, server_default=sa.false(), nullable=False),
        )

    # ─── lesson_vocabulary association table ─────────────────────
    if not _table_exists(bind, "lesson_vocabulary"):
        logger.info("Creating lesson_vocabulary table")
        op.create_table(
            "lesson_vocabulary",
            sa.Column(
                "lesson_id",
                sa.String(40),
                sa.ForeignKey("lessons.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "vocabulary_entry_id",
                sa.String(40),
                sa.ForeignKey("vocabulary_entries.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("role", sa.String(20), nullable=False),
            sa.Column("sequence", sa.Integer, nullable=False, server_default=sa.text("1")),
            sa.PrimaryKeyConstraint(
                "lesson_id", "vocabulary_entry_id", "role",
                name="pk_lesson_vocabulary",
            ),
        )
        op.create_index(
            "ix_lesson_vocabulary_lesson_id",
            "lesson_vocabulary",
            ["lesson_id"],
        )
        op.create_index(
            "ix_lesson_vocabulary_vocab_entry_id",
            "lesson_vocabulary",
            ["vocabulary_entry_id"],
        )
    logger.info("Migration 0005 completed successfully")


def downgrade():
    bind = op.get_bind()

    if _table_exists(bind, "lesson_vocabulary"):
        logger.info("Dropping lesson_vocabulary table")
        op.drop_table("lesson_vocabulary")

    if _column_exists(bind, "lessons", "is_checkpoint"):
        logger.info("Dropping is_checkpoint column from lessons")
        op.drop_column("lessons", "is_checkpoint")
