"""Publication-readiness and concurrent-XP protection schema (Stage 3.1).

Adds:
  * Lesson verification flags: vocabulary_verified, sentence_verified,
    dialogue_verified, illustration_verified (all default False).
  * Partial unique index on attempts (user_id, lesson_id) WHERE is_correct
    = True, ensuring only one fully-correct attempt can award XP per
    user+lesson (defense-in-depth against concurrent duplicate rewards).
  * Composite unique constraint on attempts (user_id, idempotency_key) so
    idempotency keys are scoped to the authenticated user.

Purely additive: no existing data is modified, no existing constraints are
removed, and no curriculum records are touched.
"""

import logging

import sqlalchemy as sa
from alembic import op

revision = "0007_publication_and_xp_protection"
down_revision = "0006_exercise_engine"
branch_labels = None
depends_on = None

logger = logging.getLogger("alembic.runtime.migration")


def _table_exists(bind, table_name: str) -> bool:
    return table_name in sa.inspect(bind).get_table_names()


def _column_exists(bind, table_name: str, column_name: str) -> bool:
    if table_name not in sa.inspect(bind).get_table_names():
        return False
    return column_name in {col["name"] for col in sa.inspect(bind).get_columns(table_name)}


def _index_exists(bind, table_name: str, index_name: str) -> bool:
    inspector = sa.inspect(bind)
    if table_name not in inspector.get_table_names():
        return False
    return index_name in {idx["name"] for idx in inspector.get_indexes(table_name)}


def _constraint_exists(bind, table_name: str, constraint_name: str) -> bool:
    inspector = sa.inspect(bind)
    if table_name not in inspector.get_table_names():
        return False
    return constraint_name in {
        c["name"] for c in inspector.get_unique_constraints(table_name)
    }


def upgrade():
    bind = op.get_bind()

    # Expand alembic_version.version_num to accommodate longer revision IDs
    op.alter_column(
        "alembic_version", "version_num",
        type_=sa.String(64),
        existing_type=sa.String(32),
        existing_nullable=False,
    )

    # ─── Lesson verification flags ───────────────────────────────
    new_lesson_columns = [
        ("vocabulary_verified", sa.Boolean(), False, sa.text("false")),
        ("sentence_verified", sa.Boolean(), False, sa.text("false")),
        ("dialogue_verified", sa.Boolean(), False, sa.text("false")),
        ("illustration_verified", sa.Boolean(), False, sa.text("false")),
    ]
    for col_name, col_type, nullable, server_default in new_lesson_columns:
        if not _column_exists(bind, "lessons", col_name):
            logger.info("Adding column %s to lessons", col_name)
            op.add_column(
                "lessons",
                sa.Column(col_name, col_type, nullable=nullable, server_default=server_default),
            )

    # ─── Attempts: scope idempotency key to user ─────────────────
    # The existing uq_attempts_idempotency_key is on idempotency_key alone.
    # Replace with composite (user_id, idempotency_key).
    if _constraint_exists(bind, "attempts", "uq_attempts_idempotency_key"):
        logger.info("Dropping uq_attempts_idempotency_key constraint from attempts")
        op.drop_constraint("uq_attempts_idempotency_key", "attempts", type_="unique")

    if not _constraint_exists(bind, "attempts", "uq_attempts_user_idempotency_key"):
        logger.info("Creating unique constraint on attempts (user_id, idempotency_key)")
        op.create_unique_constraint(
            "uq_attempts_user_idempotency_key",
            "attempts",
            ["user_id", "idempotency_key"],
        )

    # ─── Concurrent XP protection ────────────────────────────────
    # Partial unique index: only one fully-correct attempt per user+lesson.
    if not _index_exists(bind, "attempts", "ix_attempts_unique_correct_per_user_lesson"):
        logger.info(
            "Creating partial unique index on attempts (user_id, lesson_id) WHERE is_correct"
        )
        op.create_index(
            "ix_attempts_unique_correct_per_user_lesson",
            "attempts",
            ["user_id", "lesson_id"],
            unique=True,
            postgresql_where=sa.text("is_correct = true"),
        )

    logger.info("Migration 0007 completed successfully")


def downgrade():
    bind = op.get_bind()

    # Revert alembic_version.column length
    op.alter_column(
        "alembic_version", "version_num",
        type_=sa.String(32),
        existing_type=sa.String(64),
        existing_nullable=False,
    )

    # Drop partial unique index.
    if _index_exists(bind, "attempts", "ix_attempts_unique_correct_per_user_lesson"):
        op.drop_index(
            "ix_attempts_unique_correct_per_user_lesson",
            table_name="attempts",
            postgresql_where=sa.text("is_correct = true"),
        )

    # Restore global idempotency key constraint.
    if _constraint_exists(bind, "attempts", "uq_attempts_user_idempotency_key"):
        op.drop_constraint("uq_attempts_user_idempotency_key", "attempts", type_="unique")
    if not _constraint_exists(bind, "attempts", "uq_attempts_idempotency_key"):
        op.create_unique_constraint(
            "uq_attempts_idempotency_key", "attempts", ["idempotency_key"]
        )

    # Drop lesson verification columns.
    for col_name in (
        "illustration_verified",
        "dialogue_verified",
        "sentence_verified",
        "vocabulary_verified",
    ):
        if _column_exists(bind, "lessons", col_name):
            op.drop_column("lessons", col_name)

    logger.info("Migration 0007 downgrade completed")
