"""SQLite migration coverage for preserving pre-curriculum learner data."""

import importlib.util
from pathlib import Path

from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import (
    Column,
    ForeignKey,
    Integer,
    MetaData,
    String,
    Table,
    UniqueConstraint,
    create_engine,
    inspect,
    text,
)


def _migration():
    path = (
        Path(__file__).parents[1]
        / "migrations"
        / "versions"
        / "0010_newari_curriculum_progress.py"
    )
    spec = importlib.util.spec_from_file_location("migration_0010", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    return migration


def test_upgrade_preserves_legacy_rows_and_adds_progress_tables():
    metadata = MetaData()
    Table("courses", metadata, Column("id", String, primary_key=True))
    Table("users", metadata, Column("id", Integer, primary_key=True))
    Table(
        "units",
        metadata,
        Column("id", Integer, primary_key=True),
        Column("course_id", String, ForeignKey("courses.id")),
        Column("sequence", Integer),
        Column("title", String),
        Column("description", String),
        UniqueConstraint("course_id", "sequence", name="uq_course_sequence"),
    )
    Table(
        "lessons",
        metadata,
        Column("id", String, primary_key=True),
        Column("unit_id", Integer, ForeignKey("units.id")),
    )
    Table(
        "exercises",
        metadata,
        Column("id", String, primary_key=True),
        Column("lesson_id", String, ForeignKey("lessons.id")),
    )
    Table(
        "attempts",
        metadata,
        Column("id", Integer, primary_key=True),
        Column("user_id", Integer, ForeignKey("users.id")),
        Column("lesson_id", String, ForeignKey("lessons.id")),
    )

    engine = create_engine("sqlite:///:memory:")
    metadata.create_all(engine)
    with engine.begin() as connection:
        connection.execute(text("INSERT INTO courses(id) VALUES ('en_new')"))
        connection.execute(text("INSERT INTO users(id) VALUES (17)"))
        connection.execute(
            text(
                "INSERT INTO units(id, course_id, sequence, title, description) "
                "VALUES (9, 'en_new', 1, 'Legacy unit', 'Keep existing content')"
            )
        )
        connection.execute(
            text("INSERT INTO lessons(id, unit_id) VALUES ('legacy-lesson', 9)")
        )
        connection.execute(
            text("INSERT INTO exercises(id, lesson_id) VALUES ('legacy-exercise', 'legacy-lesson')")
        )
        connection.execute(
            text(
                "INSERT INTO attempts(id, user_id, lesson_id) "
                "VALUES (23, 17, 'legacy-lesson')"
            )
        )

        migration = _migration()
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

        unit = connection.execute(
            text("SELECT title, curriculum_version FROM units WHERE id = 9")
        ).one()
        attempt = connection.execute(
            text("SELECT id, earned_xp FROM attempts WHERE id = 23")
        ).one()
        constraints = {
            item["name"] for item in inspect(connection).get_unique_constraints("units")
        }
        tables = set(inspect(connection).get_table_names())

        assert unit == ("Legacy unit", "legacy")
        assert attempt == (23, 0)
        assert "uq_course_version_sequence" in constraints
        assert "uq_course_sequence" not in constraints
        assert {"lesson_progress", "exercise_submissions"}.issubset(tables)

        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

    engine.dispose()
