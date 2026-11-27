"""Backfill and collision checks for account-owned lesson-run identifiers."""

import importlib.util
from datetime import datetime, timezone
from pathlib import Path

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    MetaData,
    String,
    Table,
    create_engine,
    inspect,
    select,
)


def _migration():
    path = (
        Path(__file__).parents[1]
        / "migrations"
        / "versions"
        / "0011_account_owned_lesson_runs.py"
    )
    spec = importlib.util.spec_from_file_location("migration_0011", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    return migration


def _legacy_schema(engine):
    metadata = MetaData()
    Table("users", metadata, Column("id", Integer, primary_key=True))
    Table("lessons", metadata, Column("id", String, primary_key=True))
    Table(
        "exercise_submissions",
        metadata,
        Column("run_id", String(64)),
        Column("user_id", Integer, ForeignKey("users.id")),
        Column("lesson_id", String(40), ForeignKey("lessons.id")),
        Column("created_at", DateTime(timezone=True), nullable=False),
    )
    Table(
        "attempts",
        metadata,
        Column("idempotency_key", String(64)),
        Column("user_id", Integer, ForeignKey("users.id")),
        Column("lesson_id", String(40), ForeignKey("lessons.id")),
        Column("completed_at", DateTime(timezone=True), nullable=False),
    )
    metadata.create_all(engine)


def test_upgrade_preserves_run_owners_and_incomplete_runs():
    engine = create_engine("sqlite:///:memory:")
    _legacy_schema(engine)
    started = datetime(2026, 1, 1, tzinfo=timezone.utc)
    completed = datetime(2026, 1, 2, tzinfo=timezone.utc)
    with engine.begin() as connection:
        connection.execute(
            Table("users", MetaData(), autoload_with=connection).insert(),
            [{"id": 11}, {"id": 12}],
        )
        connection.execute(
            Table("lessons", MetaData(), autoload_with=connection).insert(),
            [{"id": "L01"}],
        )
        submissions = Table(
            "exercise_submissions", MetaData(), autoload_with=connection
        )
        attempts = Table("attempts", MetaData(), autoload_with=connection)
        connection.execute(
            submissions.insert(),
            [
                {
                    "run_id": "unfinished-a",
                    "user_id": 11,
                    "lesson_id": "L01",
                    "created_at": started,
                }
            ],
        )
        connection.execute(
            attempts.insert(),
            [
                {
                    "idempotency_key": "completed-b",
                    "user_id": 12,
                    "lesson_id": "L01",
                    "completed_at": completed,
                }
            ],
        )
        migration = _migration()
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

        runs = Table("lesson_runs", MetaData(), autoload_with=connection)
        rows = connection.execute(
            select(runs.c.run_id, runs.c.user_id, runs.c.lesson_id)
        ).all()
        assert set(rows) == {
            ("unfinished-a", 11, "L01"),
            ("completed-b", 12, "L01"),
        }
        assert "lesson_runs" in inspect(connection).get_table_names()
    engine.dispose()


def test_upgrade_refuses_ambiguous_legacy_run_owners_without_dropping_data():
    engine = create_engine("sqlite:///:memory:")
    _legacy_schema(engine)
    started = datetime(2026, 1, 1, tzinfo=timezone.utc)
    with engine.begin() as connection:
        connection.execute(
            Table("users", MetaData(), autoload_with=connection).insert(),
            [{"id": 11}, {"id": 12}],
        )
        connection.execute(
            Table("lessons", MetaData(), autoload_with=connection).insert(),
            [{"id": "L01"}],
        )
        submissions = Table(
            "exercise_submissions", MetaData(), autoload_with=connection
        )
        connection.execute(
            submissions.insert(),
            [
                {
                    "run_id": "ambiguous",
                    "user_id": user_id,
                    "lesson_id": "L01",
                    "created_at": started,
                }
                for user_id in (11, 12)
            ],
        )
        migration = _migration()
        with Operations.context(MigrationContext.configure(connection)):
            with pytest.raises(RuntimeError, match="shared across accounts"):
                migration.upgrade()

        assert "lesson_runs" not in inspect(connection).get_table_names()
        assert connection.execute(select(submissions.c.run_id)).scalars().all() == [
            "ambiguous",
            "ambiguous",
        ]
    engine.dispose()
