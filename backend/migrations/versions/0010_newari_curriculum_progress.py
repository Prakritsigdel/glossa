"""Additive schema for the JSON-driven Newari curriculum and per-answer flow."""

import sqlalchemy as sa
from alembic import op

revision = "0010_newari_curriculum_progress"
down_revision = "0009_lesson_completion_rewards"
branch_labels = None
depends_on = None


def _columns(table_name: str) -> set[str]:
    return {column["name"] for column in sa.inspect(op.get_bind()).get_columns(table_name)}


def _tables() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def _drop_unit_constraint(bind, name: str) -> None:
    if bind.dialect.name == "sqlite":
        with op.batch_alter_table("units") as batch_op:
            batch_op.drop_constraint(name, type_="unique")
    else:
        op.drop_constraint(name, "units", type_="unique")


def _replace_unit_sequence_constraint(bind, drop_name: str, create_name: str) -> None:
    if bind.dialect.name == "sqlite":
        with op.batch_alter_table("units") as batch_op:
            batch_op.drop_constraint(drop_name, type_="unique")
            batch_op.create_unique_constraint(
                create_name, ["course_id", "curriculum_version", "sequence"]
            )
        return
    op.drop_constraint(drop_name, "units", type_="unique")
    op.create_unique_constraint(
        create_name,
        "units",
        ["course_id", "curriculum_version", "sequence"],
    )


def upgrade():
    bind = op.get_bind()
    tables = _tables()

    if "curriculum_version" not in _columns("units"):
        op.add_column(
            "units",
            sa.Column(
                "curriculum_version",
                sa.String(40),
                nullable=False,
                server_default="legacy",
            ),
        )
    constraints = {
        item["name"]
        for item in sa.inspect(bind).get_unique_constraints("units")
        if item.get("name")
    }
    if "uq_course_sequence" in constraints:
        if "uq_course_version_sequence" in constraints:
            _drop_unit_constraint(bind, "uq_course_sequence")
        else:
            _replace_unit_sequence_constraint(
                bind, "uq_course_sequence", "uq_course_version_sequence"
            )
    elif "uq_course_version_sequence" not in constraints:
        op.create_unique_constraint(
            "uq_course_version_sequence", "units",
            ["course_id", "curriculum_version", "sequence"],
        )

    if "content_data" not in _columns("lessons"):
        op.add_column("lessons", sa.Column("content_data", sa.JSON(), nullable=True))
    if "xp" not in _columns("exercises"):
        op.add_column(
            "exercises",
            sa.Column("xp", sa.Integer(), nullable=False, server_default=sa.text("0")),
        )
    if "content_data" not in _columns("exercises"):
        op.add_column("exercises", sa.Column("content_data", sa.JSON(), nullable=True))
    if "earned_xp" not in _columns("attempts"):
        op.add_column(
            "attempts",
            sa.Column("earned_xp", sa.Integer(), nullable=False, server_default=sa.text("0")),
        )
    if "result_payload" not in _columns("attempts"):
        op.add_column("attempts", sa.Column("result_payload", sa.JSON(), nullable=True))

    if "lesson_progress" not in tables:
        op.create_table(
            "lesson_progress",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "lesson_id",
                sa.String(40),
                sa.ForeignKey("lessons.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("best_earned_xp", sa.Integer(), nullable=False, server_default=sa.text("0")),
            sa.Column("best_correct_answers", sa.Integer(), nullable=False, server_default=sa.text("0")),
            sa.Column("attempt_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint(
                "user_id", "lesson_id", name="uq_lesson_progress_user_lesson"
            ),
        )
        op.create_index("ix_lesson_progress_user_id", "lesson_progress", ["user_id"])
        op.create_index("ix_lesson_progress_lesson_id", "lesson_progress", ["lesson_id"])

    if "exercise_submissions" not in tables:
        op.create_table(
            "exercise_submissions",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "lesson_id",
                sa.String(40),
                sa.ForeignKey("lessons.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "exercise_id",
                sa.String(40),
                sa.ForeignKey("exercises.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("run_id", sa.String(64), nullable=False),
            sa.Column("selected_answer", sa.JSON(), nullable=False),
            sa.Column("matched_pairs", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
            sa.Column("missed_word_ids", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
            sa.Column("correct", sa.Boolean(), nullable=True),
            sa.Column("is_final", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("result_payload", sa.JSON(), nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
            sa.UniqueConstraint(
                "user_id", "lesson_id", "run_id", "exercise_id",
                name="uq_exercise_submission_run",
            ),
        )
        op.create_index("ix_exercise_submissions_user_id", "exercise_submissions", ["user_id"])
        op.create_index("ix_exercise_submissions_lesson_id", "exercise_submissions", ["lesson_id"])


def downgrade():
    tables = _tables()
    if "exercise_submissions" in tables:
        op.drop_table("exercise_submissions")
    if "lesson_progress" in tables:
        op.drop_table("lesson_progress")

    for column in ("result_payload", "earned_xp"):
        if column in _columns("attempts"):
            op.drop_column("attempts", column)
    if "content_data" in _columns("exercises"):
        op.drop_column("exercises", "content_data")
    if "xp" in _columns("exercises"):
        op.drop_column("exercises", "xp")
    if "content_data" in _columns("lessons"):
        op.drop_column("lessons", "content_data")

    constraints = {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_unique_constraints("units")
        if item.get("name")
    }
    if "uq_course_version_sequence" in constraints:
        if "uq_course_sequence" in constraints:
            _drop_unit_constraint(bind, "uq_course_version_sequence")
        else:
            if bind.dialect.name == "sqlite":
                with op.batch_alter_table("units") as batch_op:
                    batch_op.drop_constraint(
                        "uq_course_version_sequence", type_="unique"
                    )
                    batch_op.create_unique_constraint(
                        "uq_course_sequence", ["course_id", "sequence"]
                    )
            else:
                op.drop_constraint(
                    "uq_course_version_sequence", "units", type_="unique"
                )
                op.create_unique_constraint(
                    "uq_course_sequence", "units", ["course_id", "sequence"]
                )
    elif "uq_course_sequence" not in constraints:
        op.create_unique_constraint(
            "uq_course_sequence", "units", ["course_id", "sequence"]
        )
    if "curriculum_version" in _columns("units"):
        op.drop_column("units", "curriculum_version")
