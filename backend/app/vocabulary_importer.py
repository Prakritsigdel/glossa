"""Reusable importer for the Newari vocabulary workbook.

Reads ``newari_vocabulary.xlsx``, normalizes and validates every row,
generates stable vocabulary identifiers, maps entries to the five
planned course units, and imports them idempotently into the database.

Linguistic guarantees:
  * No Newari vocabulary is fabricated, substituted or generated.
  * Nepali translations are never used in place of Newari.
  * Unicode text is preserved exactly as it appears in the workbook.
  * No audio functionality is introduced.
  * Every imported entry is stored ``is_verified = False`` (unpublished)
    and must be reviewed by a native speaker before lessons are published.

Design notes:
  * Vocabulary entries are a validated data layer, separate from the
    curriculum (units/lessons/exercises). No curriculum records are
    created, modified or removed by this module.
  * Import is idempotent: re-importing the same workbook produces no
    duplicate records because every entry derives a deterministic,
    content-based identifier.
"""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass, field
from typing import Any

import openpyxl
from sqlalchemy.orm import Session

from app.models import VocabularyEntry

# Fixed UUID namespace so vocabulary ids are deterministic and stable
# across repeated imports of the same content.
VOCAB_ID_NAMESPACE = uuid.UUID("8f1c2d3e-4f5a-6b7c-8d9e-0f1a2b3c4d5e")

# The five units planned by newari_course_plan.md, in order.
PLANNED_UNITS = [
    "Greetings",
    "Family",
    "Numbers & Colors",
    "Food & Drinks",
    "Home & Routines",
]

# Mapping from course-plan lesson number (1-15) to unit. The workbook's
# "Lessons" column lists every lesson where a word is used; the first
# number is where the word is introduced.
UNIT_BY_LESSON: dict[int, str] = {
    1: "Greetings",
    2: "Greetings",
    3: "Greetings",
    4: "Family",
    5: "Family",
    6: "Family",
    7: "Numbers & Colors",
    8: "Numbers & Colors",
    9: "Numbers & Colors",
    10: "Food & Drinks",
    11: "Food & Drinks",
    12: "Food & Drinks",
    13: "Home & Routines",
    14: "Home & Routines",
    15: "Home & Routines",
}

# Matches "Devanagari (romanization)", e.g. "ज्वजलपा (jwajalapa)".
_NEWARI_CELL_RE = re.compile(r"^(?P<script>.+?)\s*\((?P<roman>[^)]*)\)\s*$")

# Header names expected on the Vocabulary worksheet (case-insensitive,
# whitespace-tolerant comparison).
EXPECTED_HEADERS = ["Lessons", "Word in Newari (romanization)", "Word in English"]


@dataclass
class ImportIssue:
    """A single validation finding for one row."""

    row: int
    level: str  # "error" or "warning"
    code: str  # e.g. "missing_field", "duplicate", "conflict", "invalid_row"
    message: str
    field: str | None = None


@dataclass
class RawRow:
    """A single raw worksheet row before normalization/validation."""

    row: int
    worksheet: str
    lessons: str | None
    newari_cell: str | None
    english: str | None


@dataclass
class ParsedEntry:
    """A row that has been normalized and split into its fields."""

    row: int
    worksheet: str
    english: str | None
    newari_script: str | None
    romanization: str | None
    lesson_numbers_raw: str | None
    lesson_numbers: list[int]


@dataclass
class ImportReport:
    """The complete result of parsing + (optionally) importing a workbook."""

    source_file: str
    worksheets_inspected: list[str] = field(default_factory=list)
    workbook_headers: list[str] = field(default_factory=list)

    # Counts
    total_data_rows: int = 0
    skipped_non_data_rows: int = 0

    # Results
    valid_entries: list[ParsedEntry] = field(default_factory=list)
    invalid_rows: list[dict[str, Any]] = field(default_factory=list)
    duplicate_rows: list[dict[str, Any]] = field(default_factory=list)
    conflicts: list[dict[str, Any]] = field(default_factory=list)
    issues: list[ImportIssue] = field(default_factory=list)

    # Derived views
    by_unit: dict[str, int] = field(default_factory=lambda: {u: 0 for u in PLANNED_UNITS})
    missing_romanization: list[ParsedEntry] = field(default_factory=list)
    unmapped_rows: list[ParsedEntry] = field(default_factory=list)

    # Import outcome (set by import_report)
    imported_count: int = 0
    already_existed_count: int = 0

    @property
    def valid_count(self) -> int:
        return len(self.valid_entries)

    @property
    def invalid_count(self) -> int:
        return len(self.invalid_rows)

    @property
    def duplicate_count(self) -> int:
        return len(self.duplicate_rows)

    @property
    def conflict_count(self) -> int:
        return len(self.conflicts)

    @property
    def total_issues(self) -> int:
        return len(self.issues)


def _clean(value: Any) -> str | None:
    """Strip whitespace; preserve Unicode and internal content exactly."""
    if value is None:
        return None
    text = str(value).strip()
    return text if text != "" else None


def _parse_lesson_numbers(raw: str | None) -> list[int]:
    """Parse '1, 3, 15' -> [1, 3, 15]; '6' -> [6]; None/blank -> []."""
    if not raw:
        return []
    numbers: list[int] = []
    for part in str(raw).split(","):
        part = part.strip()
        if not part:
            continue
        try:
            numbers.append(int(part))
        except ValueError:
            continue
    return numbers


def _map_unit(lesson_numbers: list[int]) -> str | None:
    """Map the first introduction lesson number to a planned unit."""
    for lesson in lesson_numbers:
        unit = UNIT_BY_LESSON.get(lesson)
        if unit is not None:
            return unit
    return None


def _stable_id(english: str, newari_script: str) -> str:
    """Content-based, deterministic vocabulary identifier."""
    key = f"{english}\u0000{newari_script}"
    return str(uuid.uuid5(VOCAB_ID_NAMESPACE, key))


def _split_newari_cell(value: str) -> tuple[str, str | None]:
    """Split 'Devanagari (romanization)' into (script, romanization).

    Returns (whole_value, None) when no parenthesized romanization is
    present; the caller decides whether that is an error or warning.
    """
    match = _NEWARI_CELL_RE.match(value)
    if match:
        return match.group("script").strip(), match.group("roman").strip()
    return value.strip(), None


def _iter_worksheet_rows(worksheet) -> tuple[list[RawRow], list[str | None]]:
    """Read every row of a worksheet into (rows, header)."""
    rows: list[RawRow] = []
    # Read header from row 1.
    header = [_clean(cell.value) for cell in worksheet[1]]
    for row_idx, row in enumerate(
        worksheet.iter_rows(min_row=2, values_only=True), start=2
    ):
        # Skip fully empty rows.
        if all(cell is None for cell in row):
            continue
        lessons = _clean(row[0]) if len(row) > 0 else None
        newari_cell = _clean(row[1]) if len(row) > 1 else None
        english = _clean(row[2]) if len(row) > 2 else None
        rows.append(
            RawRow(
                row=row_idx,
                worksheet=worksheet.title,
                lessons=lessons,
                newari_cell=newari_cell,
                english=english,
            )
        )
    return rows, header


def _is_summary_or_non_data_row(raw: RawRow) -> bool:
    """True for summary/total rows and other non-vocabulary rows."""
    if raw.lessons is None and raw.newari_cell is None and raw.english is None:
        return True
    if (
        raw.lessons is None
        and raw.newari_cell is not None
        and raw.newari_cell.lower() in {"total words", "total"}
    ):
        return True
    return False


def parse_workbook(path: str) -> ImportReport:
    """Parse and validate the workbook without touching the database.

    Returns an ImportReport describing every row: valid entries, invalid
    rows, duplicates, conflicts, missing fields and source references.
    """
    report = ImportReport(source_file=path)
    workbook = openpyxl.load_workbook(path, data_only=True)
    report.worksheets_inspected = list(workbook.sheetnames)

    vocab_ws = None
    for name in workbook.sheetnames:
        if name.lower() == "vocabulary":
            vocab_ws = workbook[name]
            break

    if vocab_ws is None:
        report.issues.append(
            ImportIssue(
                row=0,
                level="error",
                code="missing_worksheet",
                message="No 'Vocabulary' worksheet found in workbook.",
            )
        )
        return report

    rows, header = _iter_worksheet_rows(vocab_ws)
    report.workbook_headers = [h for h in header if h]

    # Validate that the Vocabulary sheet uses the expected columns.
    normalized_header = [h.lower() if h else "" for h in header]
    expected_lower = [h.lower() for h in EXPECTED_HEADERS]
    if normalized_header[: len(EXPECTED_HEADERS)] != expected_lower:
        report.issues.append(
            ImportIssue(
                row=1,
                level="warning",
                code="unexpected_headers",
                message=(
                    "Vocabulary worksheet headers do not match expected "
                    f"{EXPECTED_HEADERS}; found {report.workbook_headers}."
                ),
            )
        )

    report.total_data_rows = len(rows)

    # ---- Per-row parse + field validation ----
    parsed: list[ParsedEntry] = []
    seen_pairs: set[tuple[str, str]] = set()
    english_to_newari: dict[str, str] = {}
    newari_to_english: dict[str, str] = {}

    for raw in rows:
        if _is_summary_or_non_data_row(raw):
            report.skipped_non_data_rows += 1
            report.issues.append(
                ImportIssue(
                    row=raw.row,
                    level="warning",
                    code="non_data_row",
                    message="Skipped non-vocabulary row (empty or summary row).",
                )
            )
            continue

        entry_errors: list[ImportIssue] = []

        # Required fields: English meaning and Newari script.
        if raw.english is None:
            entry_errors.append(
                ImportIssue(
                    row=raw.row,
                    level="error",
                    code="missing_field",
                    message="Missing required field: Word in English.",
                    field="english",
                )
            )
        if raw.newari_cell is None:
            entry_errors.append(
                ImportIssue(
                    row=raw.row,
                    level="error",
                    code="missing_field",
                    message="Missing required field: Word in Newari (romanization).",
                    field="newari",
                )
            )

        if entry_errors:
            report.invalid_rows.append(
                {
                    "row": raw.row,
                    "worksheet": raw.worksheet,
                    "lessons": raw.lessons,
                    "newari_cell": raw.newari_cell,
                    "english": raw.english,
                    "errors": [e.code for e in entry_errors],
                }
            )
            report.issues.extend(entry_errors)
            continue

        # Split Newari cell into script + romanization.
        newari_script, romanization = _split_newari_cell(raw.newari_cell)

        if newari_script == "":
            entry_errors.append(
                ImportIssue(
                    row=raw.row,
                    level="error",
                    code="invalid_row",
                    message="Newari cell contains no readable Newari script.",
                    field="newari",
                )
            )
            report.invalid_rows.append(
                {
                    "row": raw.row,
                    "worksheet": raw.worksheet,
                    "lessons": raw.lessons,
                    "newari_cell": raw.newari_cell,
                    "english": raw.english,
                    "errors": [e.code for e in entry_errors],
                }
            )
            report.issues.extend(entry_errors)
            continue

        lesson_numbers = _parse_lesson_numbers(raw.lessons)
        unit = _map_unit(lesson_numbers)

        entry = ParsedEntry(
            row=raw.row,
            worksheet=raw.worksheet,
            english=raw.english,
            newari_script=newari_script,
            romanization=romanization,
            lesson_numbers_raw=raw.lessons,
            lesson_numbers=lesson_numbers,
        )

        # Missing romanization is a warning (course plan requires it under
        # every Devanagari word), not a hard failure.
        if romanization is None:
            entry_errors.append(
                ImportIssue(
                    row=raw.row,
                    level="warning",
                    code="missing_romanization",
                    message="No romanization found in Newari cell.",
                    field="romanization",
                )
            )
            report.missing_romanization.append(entry)

        if unit is None:
            entry_errors.append(
                ImportIssue(
                    row=raw.row,
                    level="warning",
                    code="unmapped_unit",
                    message=f"Lesson numbers {raw.lessons!r} do not map to a planned unit.",
                    field="lessons",
                )
            )
            report.unmapped_rows.append(entry)

        report.issues.extend(entry_errors)

        # ---- Duplicate / conflict detection among valid rows ----
        pair = (entry.english, entry.newari_script)
        if pair in seen_pairs:
            report.duplicate_rows.append(
                {
                    "row": raw.row,
                    "worksheet": raw.worksheet,
                    "english": entry.english,
                    "newari_script": entry.newari_script,
                    "lessons": raw.lessons,
                }
            )
            report.issues.append(
                ImportIssue(
                    row=raw.row,
                    level="warning",
                    code="duplicate",
                    message=f"Duplicate translation '{entry.english}' = '{entry.newari_script}'.",
                )
            )
            continue

        conflict_reason = None
        existing_newari = english_to_newari.get(entry.english)
        if existing_newari is not None and existing_newari != entry.newari_script:
            conflict_reason = (
                f"Conflicting translation for '{entry.english}': "
                f"'{existing_newari}' vs '{entry.newari_script}'."
            )
        existing_english = newari_to_english.get(entry.newari_script)
        if existing_english is not None and existing_english != entry.english:
            conflict_reason = (
                f"Conflicting meaning for '{entry.newari_script}': "
                f"'{existing_english}' vs '{entry.english}'."
            )

        if conflict_reason is not None:
            report.conflicts.append(
                {
                    "row": raw.row,
                    "worksheet": raw.worksheet,
                    "english": entry.english,
                    "newari_script": entry.newari_script,
                    "lessons": raw.lessons,
                    "reason": conflict_reason,
                }
            )
            report.issues.append(
                ImportIssue(
                    row=raw.row,
                    level="warning",
                    code="conflict",
                    message=conflict_reason,
                )
            )
            continue

        seen_pairs.add(pair)
        english_to_newari[entry.english] = entry.newari_script
        newari_to_english[entry.newari_script] = entry.english
        parsed.append(entry)

    report.valid_entries = parsed

    # ---- Unit tallies for valid (importable) entries ----
    for unit in PLANNED_UNITS:
        report.by_unit[unit] = 0
    for entry in parsed:
        unit = _map_unit(entry.lesson_numbers)
        if unit in report.by_unit:
            report.by_unit[unit] += 1

    return report


def import_report(
    db: Session, report: ImportReport, dry_run: bool = False
) -> ImportReport:
    """Persist a parsed ImportReport idempotently.

    Existing unverified entries (matched by stable id) are refreshed in
    place. Verified entries are immutable to workbook imports. New entries
    are inserted ``is_verified = False``. Returns the report with
    ``imported_count`` / ``already_existed_count`` populated.

    Set ``dry_run=True`` to validate without writing.
    """
    imported = 0
    already_existed = 0

    for entry in report.valid_entries:
        vid = _stable_id(entry.english, entry.newari_script)
        existing = db.get(VocabularyEntry, vid)
        if existing is None:
            if not dry_run:
                db.add(
                    VocabularyEntry(
                        id=vid,
                        source_worksheet=entry.worksheet,
                        source_row=entry.row,
                        unit=_map_unit(entry.lesson_numbers),
                        english_meaning=entry.english,
                        newari_script=entry.newari_script,
                        romanization=entry.romanization,
                        lesson_numbers=entry.lesson_numbers_raw,
                        is_verified=False,
                    )
                )
            imported += 1
        else:
            # A reviewed entry is authoritative; imports may not replace it.
            if not dry_run and not existing.is_verified:
                existing.source_worksheet = entry.worksheet
                existing.source_row = entry.row
                existing.unit = _map_unit(entry.lesson_numbers)
                existing.english_meaning = entry.english
                existing.newari_script = entry.newari_script
                existing.romanization = entry.romanization
                existing.lesson_numbers = entry.lesson_numbers_raw
            already_existed += 1

    if not dry_run:
        db.commit()

    report.imported_count = imported
    report.already_existed_count = already_existed
    return report


def import_vocabulary(
    db: Session, path: str, dry_run: bool = False
) -> ImportReport:
    """Convenience: parse ``path`` and import the report in one call."""
    report = parse_workbook(path)
    return import_report(db, report, dry_run=dry_run)
