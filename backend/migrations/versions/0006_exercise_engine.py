"""Exercise engine schema extensions for Stage 3.

Adds structured fields to the exercises table to support all seven
exercise types (matchWords, fillBlank, pictureToWord, wordToPicture,
translate, wordOrder, dialogueComplete) without exposing correct answers
in the public API.

Also modifies the attempts table to support legitimate retries:
- Removes the unique(user_id, lesson_id) constraint that blocked retries.
- Adds attempt_number, idempotency_key, and is_correct fields.
- Preserves all historical attempt records and XP.

Purely additive where possible; no existing curriculum records are modified.
"""

import logging

import sqlalchemy as sa
from alembic import op

revision = "0006_exercise_engine"
down_revision = "0005_curriculum_blueprint"
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
        c["name"] for c in inspector.get_check_constraints(table_name)
    } | {c["name"] for c in inspector.get_unique_constraints(table_name)}


def upgrade():
    bind = op.get_bind()

    # ─── New columns on exercises ────────────────────────────────
    new_exercise_columns = [
        ("newari_script", sa.String(200), True),
        ("romanization", sa.String(200), True),
        ("word_tiles", sa.JSON(), True),
        ("dialogue_structure", sa.JSON(), True),
        ("illustration_id", sa.String(80), True),
        ("correct_answer_config", sa.JSON(), True),
        ("vocabulary_reference", sa.JSON(), True),
    ]
    for col_name, col_type, nullable in new_exercise_columns:
        if not _column_exists(bind, "exercises", col_name):
            logger.info("Adding column %s to exercises", col_name)
            op.add_column("exercises", sa.Column(col_name, col_type, nullable=nullable))

    # ─── Attempts: support retries ───────────────────────────────
    # Remove unique(user_id, lesson_id) to allow multiple attempts.
    if _constraint_exists(bind, "attempts", "uq_user_lesson_attempt"):
        logger.info("Dropping uq_user_lesson_attempt constraint from attempts")
        op.drop_constraint("uq_user_lesson_attempt", "attempts", type_="unique")

    # New attempt columns.
    new_attempt_columns = [
        ("attempt_number", sa.Integer(), False, sa.text("1")),
        ("idempotency_key", sa.String(64), True, None),
        ("is_correct", sa.Boolean(), False, sa.text("false")),
    ]
    for col_name, col_type, nullable, server_default in new_attempt_columns:
        if not _column_exists(bind, "attempts", col_name):
            logger.info("Adding column %s to attempts", col_name)
            op.add_column(
                "attempts",
                sa.Column(col_name, col_type, nullable=nullable, server_default=server_default),
            )

    # Unique idempotency key for duplicate submission protection.
    if not _constraint_exists(bind, "attempts", "uq_attempts_idempotency_key"):
        logger.info("Creating unique constraint on attempts.idempotency_key")
        op.create_unique_constraint(
            "uq_attempts_idempotency_key", "attempts", ["idempotency_key"]
        )

    logger.info("Migration 0006 completed successfully")


def downgrade():
    bind = op.get_bind()

    # Remove idempotency key constraint.
    if _constraint_exists(bind, "attempts", "uq_attempts_idempotency_key"):
        op.drop_constraint("uq_attempts_idempotency_key", "attempts", type_="unique")

    # Drop new attempt columns.
    for col_name in ("is_correct", "idempotency_key", "attempt_number"):
        if _column_exists(bind, "attempts", col_name):
            op.drop_column("attempts", col_name)

    # Restore unique(user_id, lesson_id).
    if not _constraint_exists(bind, "attempts", "uq_user_lesson_attempt"):
        op.create_unique_constraint("uq_user_lesson_attempt", "attempts", ["user_id", "lesson_id"])

    # Drop new exercise columns.
    for col_name in (
        "vocabulary_reference",
        "correct_answer_config",
        "illustration_id",
        "dialogue_structure",
        "word_tiles",
        "romanization",
        "newari_script",
    ):
        if _column_exists(bind, "exercises", col_name):
            op.drop_column("exercises", col_name)

    logger.info("Migration 0006 downgrade completed")
