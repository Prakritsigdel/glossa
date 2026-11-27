"""Persist lesson-run ownership for account isolation."""

import sqlalchemy as sa
from alembic import op

revision = "0011_account_owned_lesson_runs"
down_revision = "0010_newari_curriculum_progress"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    metadata = sa.MetaData()
    submissions = sa.Table(
        "exercise_submissions",
        metadata,
        sa.Column("run_id", sa.String(64)),
        sa.Column("user_id", sa.Integer()),
        sa.Column("lesson_id", sa.String(40)),
        sa.Column("created_at", sa.DateTime(timezone=True)),
    )
    attempts = sa.Table(
        "attempts",
        metadata,
        sa.Column("idempotency_key", sa.String(64)),
        sa.Column("user_id", sa.Integer()),
        sa.Column("lesson_id", sa.String(40)),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
    )

    legacy_runs = {}
    for row in bind.execute(
        sa.select(
            submissions.c.run_id,
            submissions.c.user_id,
            submissions.c.lesson_id,
            sa.func.min(submissions.c.created_at).label("started_at"),
        ).group_by(
            submissions.c.run_id,
            submissions.c.user_id,
            submissions.c.lesson_id,
        )
    ):
        owner = (row.user_id, row.lesson_id)
        previous = legacy_runs.get(row.run_id)
        if previous is None:
            legacy_runs[row.run_id] = (owner, row.started_at)
        elif previous[0] != owner:
            legacy_runs[row.run_id] = (previous[0], previous[1], owner)
    for row in bind.execute(
        sa.select(
            attempts.c.idempotency_key,
            attempts.c.user_id,
            attempts.c.lesson_id,
            attempts.c.completed_at,
        ).where(attempts.c.idempotency_key.is_not(None))
    ):
        owner = (row.user_id, row.lesson_id)
        previous = legacy_runs.get(row.idempotency_key)
        if previous is None:
            legacy_runs[row.idempotency_key] = (owner, row.completed_at)
        elif previous[0] != owner:
            legacy_runs[row.idempotency_key] = (previous[0], previous[1], owner)

    collisions = [
        run_id
        for run_id, value in legacy_runs.items()
        if len(value) == 3
    ]
    if collisions:
        raise RuntimeError(
            "Cannot migrate lesson runs: existing run IDs are shared across "
            f"accounts or lessons ({len(collisions)} collision(s))."
        )

    if "lesson_runs" not in sa.inspect(bind).get_table_names():
        op.create_table(
            "lesson_runs",
            sa.Column("run_id", sa.String(64), primary_key=True),
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
                "started_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
        )
        op.create_index("ix_lesson_runs_user_id", "lesson_runs", ["user_id"])
        op.create_index("ix_lesson_runs_lesson_id", "lesson_runs", ["lesson_id"])
        op.create_index(
            "ix_lesson_runs_user_lesson_started",
            "lesson_runs",
            ["user_id", "lesson_id", "started_at"],
        )

    rows = [
        {
            "run_id": run_id,
            "user_id": owner[0],
            "lesson_id": owner[1],
            "started_at": started_at,
        }
        for run_id, (owner, started_at) in legacy_runs.items()
    ]
    if rows:
        bind.execute(sa.table(
            "lesson_runs",
            sa.column("run_id", sa.String(64)),
            sa.column("user_id", sa.Integer()),
            sa.column("lesson_id", sa.String(40)),
            sa.column("started_at", sa.DateTime(timezone=True)),
        ).insert(), rows)


def downgrade():
    op.drop_table("lesson_runs")
