"""Automated tests for the Newari vocabulary importer.

Run from the backend directory with:

    python -m unittest tests.test_vocabulary_importer -v

These tests use an in-memory SQLite database and the real
``newari_vocabulary.xlsx`` (read-only), so no PostgreSQL instance and no
source-file modification are required.
"""

from __future__ import annotations

import os
import unittest
from pathlib import Path
from tempfile import NamedTemporaryFile

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.database import Base
from app.models import VocabularyEntry
from app.vocabulary_importer import (
    PLANNED_UNITS,
    _stable_id,
    import_report,
    import_vocabulary,
    parse_workbook,
)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
XLSX_PATH = str(REPO_ROOT / "newari_vocabulary.xlsx")


def make_in_memory_session() -> Session:
    """Create an in-memory SQLite session with all tables created."""
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)()


def write_temp_xlsx(sheet_name: str, rows: list[list]) -> str:
    """Write a small workbook (openpyxl) to a temp file and return its path."""
    import openpyxl

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = sheet_name
    for r in rows:
        ws.append(r)
    notes = wb.create_sheet("Notes")
    notes.append(["Notes"])
    notes.append(["Test workbook."])
    tmp = NamedTemporaryFile(delete=False, suffix=".xlsx")
    wb.save(tmp.name)
    return tmp.name


class TestVocabularyImporter(unittest.TestCase):
    def test_inspects_all_worksheets(self):
        report = parse_workbook(XLSX_PATH)
        self.assertEqual(report.worksheets_inspected, ["Vocabulary", "Notes"])

    def test_header_columns(self):
        report = parse_workbook(XLSX_PATH)
        self.assertEqual(
            report.workbook_headers,
            ["Lessons", "Word in Newari (romanization)", "Word in English"],
        )

    def test_parses_all_real_entries(self):
        report = parse_workbook(XLSX_PATH)
        # 70 vocabulary rows + 1 non-empty "Total words" summary row =
        # 71 non-empty data rows. The truly-empty row is excluded.
        self.assertEqual(report.total_data_rows, 71)
        # The empty row is excluded at read time; the summary row is
        # skipped as a non-data row during parsing.
        self.assertEqual(report.skipped_non_data_rows, 1)
        self.assertEqual(report.valid_count, 70)
        self.assertEqual(report.invalid_count, 0)
        self.assertEqual(report.duplicate_count, 0)
        self.assertEqual(report.conflict_count, 0)

    def test_all_entries_have_romanization_and_map_to_units(self):
        report = parse_workbook(XLSX_PATH)
        self.assertEqual(len(report.missing_romanization), 0)
        self.assertEqual(len(report.unmapped_rows), 0)
        self.assertEqual(sum(report.by_unit.values()), 70)
        for unit in PLANNED_UNITS:
            self.assertIn(unit, report.by_unit)
            self.assertGreater(report.by_unit[unit], 0)

    def test_unit_breakdown_matches_first_introduction_lesson(self):
        report = parse_workbook(XLSX_PATH)
        expected = {
            "Greetings": 12,
            "Family": 16,
            "Numbers & Colors": 17,
            "Food & Drinks": 11,
            "Home & Routines": 14,
        }
        self.assertEqual(report.by_unit, expected)

    def test_source_worksheet_and_row_preserved(self):
        report = parse_workbook(XLSX_PATH)
        first = report.valid_entries[0]
        self.assertEqual(first.worksheet, "Vocabulary")
        # First data row is worksheet row 2.
        self.assertEqual(first.row, 2)
        for entry in report.valid_entries:
            self.assertGreaterEqual(entry.row, 2)
            self.assertEqual(entry.worksheet, "Vocabulary")

    def test_stable_ids_are_deterministic(self):
        report_a = parse_workbook(XLSX_PATH)
        report_b = parse_workbook(XLSX_PATH)
        ids_a = sorted(_stable_id(e.english, e.newari_script) for e in report_a.valid_entries)
        ids_b = sorted(_stable_id(e.english, e.newari_script) for e in report_b.valid_entries)
        self.assertEqual(ids_a, ids_b)
        self.assertEqual(len(set(ids_a)), len(ids_a))

    def test_unicode_preserved_exactly(self):
        report = parse_workbook(XLSX_PATH)
        hello = next(e for e in report.valid_entries if e.english == "Hello")
        self.assertEqual(hello.newari_script, "ज्वजलपा")
        self.assertEqual(hello.romanization, "jwajalapa")
        three = next(e for e in report.valid_entries if e.english == "Three")
        self.assertEqual(three.newari_script, "स्वँ")
        self.assertEqual(three.romanization, "swãṃ")
        one = next(e for e in report.valid_entries if e.english == "One")
        self.assertEqual(one.newari_script, "छ")

    def test_idempotent_import_produces_no_duplicates(self):
        session = make_in_memory_session()
        try:
            report1 = import_vocabulary(session, XLSX_PATH)
            count_after_first = session.query(VocabularyEntry).count()
            self.assertEqual(report1.imported_count, 70)
            self.assertEqual(count_after_first, 70)
            self.assertEqual(
                session.query(VocabularyEntry).filter_by(is_verified=False).count(), 70
            )

            report2 = import_vocabulary(session, XLSX_PATH)
            count_after_second = session.query(VocabularyEntry).count()
            self.assertEqual(report2.imported_count, 0)
            self.assertEqual(report2.already_existed_count, 70)
            self.assertEqual(count_after_second, 70)
        finally:
            session.close()

    def test_import_matches_report_and_preserves_content(self):
        session = make_in_memory_session()
        try:
            report = import_vocabulary(session, XLSX_PATH)
            db_count = session.query(VocabularyEntry).count()
            self.assertEqual(db_count, report.valid_count)
            self.assertEqual(db_count, 70)
            row = session.query(VocabularyEntry).filter_by(english_meaning="Mother").one()
            self.assertEqual(row.newari_script, "माँ")
            self.assertEqual(row.romanization, "māṃ")
            self.assertEqual(row.source_worksheet, "Vocabulary")
            self.assertEqual(row.unit, "Family")
            self.assertFalse(row.is_verified)
        finally:
            session.close()

    def test_reimport_does_not_overwrite_verified_vocabulary(self):
        session = make_in_memory_session()
        try:
            import_vocabulary(session, XLSX_PATH)
            row = session.query(VocabularyEntry).filter_by(
                english_meaning="Mother"
            ).one()
            row.newari_script = "reviewed script"
            row.romanization = "reviewed pronunciation"
            row.source_row = 999
            row.is_verified = True
            session.commit()

            report = import_vocabulary(session, XLSX_PATH)

            self.assertEqual(report.imported_count, 0)
            self.assertEqual(report.already_existed_count, 70)
            self.assertEqual(row.newari_script, "reviewed script")
            self.assertEqual(row.romanization, "reviewed pronunciation")
            self.assertEqual(row.source_row, 999)
            self.assertTrue(row.is_verified)
        finally:
            session.close()

    def test_dry_run_writes_nothing(self):
        session = make_in_memory_session()
        try:
            report = import_vocabulary(session, XLSX_PATH, dry_run=True)
            self.assertEqual(session.query(VocabularyEntry).count(), 0)
            self.assertEqual(report.imported_count, 70)
        finally:
            session.close()

    def test_duplicate_rows_detected(self):
        rows = [
            ["Lessons", "Word in Newari (romanization)", "Word in English"],
            ["1", "नमस्ते (namaste)", "Hello"],
            ["1", "नमस्ते (namaste)", "Hello"],  # exact duplicate
        ]
        path = write_temp_xlsx("Vocabulary", rows)
        try:
            report = parse_workbook(path)
            self.assertEqual(report.valid_count, 1)
            self.assertEqual(report.duplicate_count, 1)
            self.assertEqual(report.invalid_count, 0)
        finally:
            os.unlink(path)

    def test_invalid_rows_missing_fields(self):
        rows = [
            ["Lessons", "Word in Newari (romanization)", "Word in English"],
            ["1", None, "Hello"],  # missing Newari
            [None, "नमस्ते (namaste)", None],  # missing English
            ["1", "नमस्ते (namaste)", "Hello"],  # valid
        ]
        path = write_temp_xlsx("Vocabulary", rows)
        try:
            report = parse_workbook(path)
            self.assertEqual(report.valid_count, 1)
            self.assertEqual(report.invalid_count, 2)
            # Header + 3 data rows.
            self.assertEqual(report.total_data_rows, 3)
        finally:
            os.unlink(path)

    def test_conflicting_translations_detected(self):
        rows = [
            ["Lessons", "Word in Newari (romanization)", "Word in English"],
            ["1", "नमस्ते (namaste)", "Hello"],
            ["2", "सत् श्री अकाल (sat sri akal)", "Hello"],  # same English, different Newari
        ]
        path = write_temp_xlsx("Vocabulary", rows)
        try:
            report = parse_workbook(path)
            self.assertEqual(report.valid_count, 1)
            self.assertEqual(report.conflict_count, 1)
            self.assertEqual(report.duplicate_count, 0)
        finally:
            os.unlink(path)

    def test_missing_romanization_flagged_as_warning(self):
        rows = [
            ["Lessons", "Word in Newari (romanization)", "Word in English"],
            ["1", "नमस्ते", "Hello"],  # no parenthesized romanization
        ]
        path = write_temp_xlsx("Vocabulary", rows)
        try:
            report = parse_workbook(path)
            self.assertEqual(report.valid_count, 1)
            self.assertEqual(len(report.missing_romanization), 1)
            warning_codes = [i.code for i in report.issues]
            self.assertIn("missing_romanization", warning_codes)
        finally:
            os.unlink(path)

    def test_unmapped_lesson_numbers_flagged(self):
        rows = [
            ["Lessons", "Word in Newari (romanization)", "Word in English"],
            ["99", "नमस्ते (namaste)", "Hello"],  # lesson 99 not in plan
        ]
        path = write_temp_xlsx("Vocabulary", rows)
        try:
            report = parse_workbook(path)
            self.assertEqual(report.valid_count, 1)
            self.assertEqual(len(report.unmapped_rows), 1)
            self.assertEqual(report.by_unit["Greetings"], 0)
        finally:
            os.unlink(path)

    def test_vocabulary_table_is_separate_from_curriculum(self):
        session = make_in_memory_session()
        try:
            tables = {t.name for t in Base.metadata.tables.values()}
            self.assertIn("vocabulary_entries", tables)
            self.assertIn("lessons", tables)
            import_vocabulary(session, XLSX_PATH)
            self.assertEqual(session.query(VocabularyEntry).count(), 70)
        finally:
            session.close()


if __name__ == "__main__":
    unittest.main()
