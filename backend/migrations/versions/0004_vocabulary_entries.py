"""Vocabulary entries table for the English -> Newari vocabulary import.

Adds a validated, non-curriculum vocabulary data layer. The table is
purely additive: no existing tables or columns are modified, and no
existing curriculum records are touched. Every imported entry is stored
unverified (is_verified = False) and must be reviewed by a native
speaker before any lesson is published.
"""

import logging

import sqlalchemy as sa
from alembic import op

revision = "0004_vocabulary_entries"
down_revision = "0003_multi_language_courses"
branch_labels = None
depends_on = None

logger = logging.getLogger("alembic.runtime.migration")


def _table_exists(bind, table_name: str) -> bool:
    return table_name in sa.inspect(bind).get_table_names()


def upgrade():
    bind = op.get_bind()

    if _table_exists(bind, "vocabulary_entries"):
        logger.info("Table vocabulary_entries already exists, skipping")
        return

    logger.info("Creating vocabulary_entries table")
    op.create_table(
        "vocabulary_entries",
        sa.Column("id", sa.String(40), primary_key=True),
        sa.Column("source_worksheet", sa.String(80), nullable=False),
        sa.Column("source_row", sa.Integer, nullable=False),
        sa.Column("unit", sa.String(120), nullable=True, index=True),
        sa.Column("english_meaning", sa.String(200), nullable=False, index=True),
        sa.Column("newari_script", sa.String(200), nullable=False),
        sa.Column("romanization", sa.String(200), nullable=True),
        sa.Column("lesson_numbers", sa.String(100), nullable=True),
        sa.Column("is_verified", sa.Boolean, server_default=sa.false(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "english_meaning",
            "newari_script",
            name="uq_vocabulary_english_newari",
        ),
    )
    logger.info("Created vocabulary_entries table")


def downgrade():
    bind = op.get_bind()
    if _table_exists(bind, "vocabulary_entries"):
        logger.info("Dropping vocabulary_entries table")
        op.drop_table("vocabulary_entries")
