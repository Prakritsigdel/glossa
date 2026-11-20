"""Track the last UTC date on which a user completed a lesson."""

from datetime import timedelta

import sqlalchemy as sa
from alembic import op

revision = "0002_user_activity_date"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade():
    # The initial migration creates tables from current ORM metadata, so a
    # fresh install may already include this column. Existing databases need
    # the ALTER TABLE below.
    bind = op.get_bind()
    columns = {column["name"] for column in sa.inspect(bind).get_columns("users")}
    if "last_activity_date" not in columns:
        op.add_column("users", sa.Column("last_activity_date", sa.Date(), nullable=True))

    # Recover existing streaks from completed lesson history. Attempts are
    # converted to UTC dates to match the streak calculation in the API.
    activity_rows = bind.execute(sa.text("""
        SELECT user_id, (completed_at AT TIME ZONE 'UTC')::date AS activity_date
        FROM attempts
        GROUP BY user_id, (completed_at AT TIME ZONE 'UTC')::date
        ORDER BY user_id, activity_date DESC
    """)).all()
    dates_by_user = {}
    for user_id, activity_date in activity_rows:
        dates_by_user.setdefault(user_id, []).append(activity_date)

    for user_id, activity_dates in dates_by_user.items():
        last_date = activity_dates[0]
        streak = 1
        for previous, next_date in zip(activity_dates, activity_dates[1:]):
            if next_date == previous - timedelta(days=1):
                streak += 1
            else:
                break
        bind.execute(
            sa.text("UPDATE users SET last_activity_date = :last_date, streak = :streak WHERE id = :user_id"),
            {"last_date": last_date, "streak": streak, "user_id": user_id},
        )


def downgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("users")}
    if "last_activity_date" in columns:
        op.drop_column("users", "last_activity_date")
