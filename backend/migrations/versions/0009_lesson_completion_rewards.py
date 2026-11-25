"""Lesson completion and reward uniqueness (Stage 6).

Adds:
  * lesson_completions table: one record per user per lesson, recording
    whether the lesson was passed, the score, and XP earned. The unique
    constraint on (user_id, lesson_id) guarantees exactly one completion
    reward per lesson per user, even under concurrent submissions.
  * passing_score column on lessons: the minimum score (0-100) required
    to pass. Ordinary lessons require 100; checkpoints require 80.
  * passing_threshold column on attempts: the threshold that was in
    effect when the attempt was made, for historical audit.

Purely additive: no existing tables, columns, or records are modified or
removed. Historical attempts, XP, and streaks are preserved.
"""

import logging

import sqlalchemy as sa
from alembic import op

revision = "0009_lesson_completion_rewards"
down_revision = "0008_single_course_en_new"
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

    # ─── lesson_completions table ────────────────────────────────
    if not _table_exists(bind, "lesson_completions"):
        logger.info("Creating lesson_completions table")
        op.create_table(
            "lesson_completions",
            sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
            sa.Column(
                "user_id",
                sa.Integer,
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            sa.Column(
                "lesson_id",
                sa.String(40),
                sa.ForeignKey("lessons.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            sa.Column("score", sa.Float, nullable=False),
            sa.Column("passed", sa.Boolean, nullable=False, server_default=sa.false()),
            sa.Column("xp_earned", sa.Integer, nullable=False, server_default=sa.text("0")),
            sa.Column("correct_answers", sa.Integer, nullable=False, server_default=sa.text("0")),
            sa.Column("total_questions", sa.Integer, nullable=False, server_default=sa.text("0")),
            sa.Column(
                "completed_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
                nullable=False,
            ),
            sa.UniqueConstraint(
                "user_id", "lesson_id", name="uq_lesson_completion_user_lesson"
            ),
        )

    # ─── passing_score on lessons ────────────────────────────────
    if not _column_exists(bind, "lessons", "passing_score"):
        logger.info("Adding passing_score column to lessons")
        op.add_column(
            "lessons",
            sa.Column("passing_score", sa.Integer, nullable=False, server_default=sa.text("100")),
        )

    # ─── passing_threshold on attempts ───────────────────────────
    if not _column_exists(bind, "attempts", "passing_threshold"):
        logger.info("Adding passing_threshold column to attempts")
        op.add_column(
            "attempts",
            sa.Column("passing_threshold", sa.Integer, nullable=True),
        )
    if not _column_exists(bind, "attempts", "submission_hash"):
        op.add_column("attempts", sa.Column("submission_hash", sa.String(64), nullable=True))

    # Checkpoint thresholds are explicit in the blueprint. Existing exact
    # passes are trustworthy historical evidence; never add XP in this
    # backfill because historical rewards are already included in users.xp.
    op.execute(sa.text("UPDATE lessons SET passing_score = 80 WHERE is_checkpoint = TRUE"))
    op.execute(sa.text("""
        INSERT INTO lesson_completions
            (user_id, lesson_id, score, passed, xp_earned,
             correct_answers, total_questions, completed_at)
        SELECT a.user_id, a.lesson_id,
               CAST(a.correct_answers AS FLOAT) / a.total_questions,
               TRUE, 0, a.correct_answers, a.total_questions, a.completed_at
        FROM attempts a
        WHERE a.is_correct = TRUE AND a.total_questions > 0
          AND NOT EXISTS (
              SELECT 1 FROM lesson_completions c
              WHERE c.user_id = a.user_id AND c.lesson_id = a.lesson_id
          )
          AND a.id = (
              SELECT MIN(a2.id) FROM attempts a2
              WHERE a2.user_id = a.user_id AND a2.lesson_id = a.lesson_id
                AND a2.is_correct = TRUE AND a2.total_questions > 0
          )
    """))
    if "ix_attempts_unique_correct_per_user_lesson" in {
        idx["name"] for idx in sa.inspect(bind).get_indexes("attempts")
    }:
        op.drop_index("ix_attempts_unique_correct_per_user_lesson", table_name="attempts")

    logger.info("Migration 0009 completed successfully")


def downgrade():
    bind = op.get_bind()

    # ─── Drop passing_threshold on attempts ───────────────────────
    if _column_exists(bind, "attempts", "passing_threshold"):
        op.drop_column("attempts", "passing_threshold")
    if _column_exists(bind, "attempts", "submission_hash"):
        op.drop_column("attempts", "submission_hash")


    # ─── Drop passing_score on lessons ───────────────────────────
    if _column_exists(bind, "lessons", "passing_score"):
        op.drop_column("lessons", "passing_score")

    # ─── Drop lesson_completions table ────────────────────────────
    if _table_exists(bind, "lesson_completions"):
        logger.info("Dropping lesson_completions table")
        op.drop_table("lesson_completions")

    logger.info("Migration 0009 downgrade completed")
