"""Exercise engine for all seven Glossa exercise types.

Provides reusable, type-specific answer validation that distinguishes:
  * A valid correct answer
  * A valid incorrect answer
  * A structurally invalid submission

Incorrect learner answers are ordinary learning outcomes, not server
failures. Malformed submissions return appropriate validation errors.

No correct-answer information is exposed through validation results
beyond whether the submission was correct or incorrect.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class ValidationResult:
    """Result of validating a single exercise answer."""

    valid: bool  # Structurally well-formed submission
    correct: bool  # Answer is correct (only meaningful when valid=True)
    error: str | None = None  # Human-readable error when valid=False


# ═════════════════════════════════════════════════════════════════════
# 1. matchWords
# ═════════════════════════════════════════════════════════════════════

def validate_matchwords(
    submitted: dict[str, str],
    correct_pairs: dict[str, str],
) -> ValidationResult:
    """Validate a matchWords submission.

    submitted: mapping of devanagari option id -> english option id
    correct_pairs: server-side mapping of devanagari id -> english id
    """
    if not isinstance(submitted, dict):
        return ValidationResult(valid=False, correct=False, error="Submission must be an object of pairs.")

    # Reject unknown identifiers (either side)
    valid_dev_ids = set(correct_pairs.keys())
    valid_eng_ids = set(correct_pairs.values())

    for dev_id, eng_id in submitted.items():
        if dev_id not in valid_dev_ids:
            return ValidationResult(
                valid=False, correct=False,
                error=f"Unknown devanagari option id: {dev_id}",
            )
        if eng_id not in valid_eng_ids:
            return ValidationResult(
                valid=False, correct=False,
                error=f"Unknown english option id: {eng_id}",
            )

    # Reject duplicate pair usage (same english matched to multiple devanagari,
    # or same devanagari matched to multiple english)
    submitted_dev_ids = set(submitted.keys())
    submitted_eng_ids = set(submitted.values())
    if len(submitted_dev_ids) != len(submitted):
        return ValidationResult(
            valid=False, correct=False,
            error="Duplicate devanagari option in pairs.",
        )
    if len(submitted_eng_ids) != len(submitted):
        return ValidationResult(
            valid=False, correct=False,
            error="Duplicate english option in pairs.",
        )

    # Reject missing pairs (every required item must be matched)
    if submitted_dev_ids != valid_dev_ids:
        missing = valid_dev_ids - submitted_dev_ids
        return ValidationResult(
            valid=False, correct=False,
            error=f"Missing pairs for: {sorted(missing)}",
        )

    # Server-side correctness check
    correct = all(
        correct_pairs.get(dev_id) == eng_id
        for dev_id, eng_id in submitted.items()
    )
    return ValidationResult(valid=True, correct=correct)


# ═════════════════════════════════════════════════════════════════════
# 2. fillBlank
# ═════════════════════════════════════════════════════════════════════

def validate_fillblank(
    selected_option_id: str | None,
    correct_option_id: str | None,
    valid_option_ids: set[str],
) -> ValidationResult:
    """Validate a fillBlank submission."""
    if selected_option_id is None:
        return ValidationResult(
            valid=False, correct=False,
            error="No answer option selected.",
        )
    if selected_option_id not in valid_option_ids:
        return ValidationResult(
            valid=False, correct=False,
            error=f"Unknown option id: {selected_option_id}",
        )
    correct = selected_option_id == correct_option_id
    return ValidationResult(valid=True, correct=correct)


# ═════════════════════════════════════════════════════════════════════
# 3. pictureToWord
# ═════════════════════════════════════════════════════════════════════

def validate_picture_to_word(
    selected_option_id: str | None,
    correct_option_id: str | None,
    valid_option_ids: set[str],
) -> ValidationResult:
    """Validate a pictureToWord submission."""
    return validate_fillblank(
        selected_option_id, correct_option_id, valid_option_ids
    )


# ═════════════════════════════════════════════════════════════════════
# 4. wordToPicture
# ═════════════════════════════════════════════════════════════════════

def validate_word_to_picture(
    selected_option_id: str | None,
    correct_option_id: str | None,
    valid_option_ids: set[str],
) -> ValidationResult:
    """Validate a wordToPicture submission."""
    return validate_fillblank(
        selected_option_id, correct_option_id, valid_option_ids
    )


# ═════════════════════════════════════════════════════════════════════
# 5. translate
# ═════════════════════════════════════════════════════════════════════

def validate_translate(
    submitted_tile_ids: list[str] | None,
    correct_sequence: list[str],
    valid_tile_ids: set[str],
    alternative_sequences: list[list[str]] | None = None,
) -> ValidationResult:
    """Validate a translate submission (ordered word tiles).

    submitted_tile_ids: ordered list of tile ids submitted by the learner
    correct_sequence: server-side ordered list of correct tile ids
    valid_tile_ids: set of all valid tile ids for this exercise
    alternative_sequences: optional list of alternative correct sequences
    """
    if submitted_tile_ids is None:
        return ValidationResult(
            valid=False, correct=False,
            error="No tiles submitted.",
        )
    if not isinstance(submitted_tile_ids, list):
        return ValidationResult(
            valid=False, correct=False,
            error="Submission must be a list of tile ids.",
        )

    # Reject unknown tile ids
    for tile_id in submitted_tile_ids:
        if tile_id not in valid_tile_ids:
            return ValidationResult(
                valid=False, correct=False,
                error=f"Unknown tile id: {tile_id}",
            )

    # Reject duplicate tile-instance usage (repeated words use distinct tiles)
    if len(submitted_tile_ids) != len(set(submitted_tile_ids)):
        return ValidationResult(
            valid=False, correct=False,
            error="Duplicate tile instance used.",
        )

    # Reject missing required tiles
    if set(submitted_tile_ids) != set(correct_sequence):
        missing = set(correct_sequence) - set(submitted_tile_ids)
        extra = set(submitted_tile_ids) - set(correct_sequence)
        msg_parts = []
        if missing:
            msg_parts.append(f"Missing tiles: {sorted(missing)}")
        if extra:
            msg_parts.append(f"Extra tiles: {sorted(extra)}")
        return ValidationResult(valid=False, correct=False, error="; ".join(msg_parts))

    # Check correctness against correct sequence and alternatives
    all_correct_sequences = [correct_sequence] + (alternative_sequences or [])
    correct = any(
        submitted_tile_ids == seq for seq in all_correct_sequences
    )
    return ValidationResult(valid=True, correct=correct)


# ═════════════════════════════════════════════════════════════════════
# 6. wordOrder
# ═════════════════════════════════════════════════════════════════════

def validate_word_order(
    submitted_tile_ids: list[str] | None,
    correct_sequence: list[str],
    valid_tile_ids: set[str],
    alternative_sequences: list[list[str]] | None = None,
) -> ValidationResult:
    """Validate a wordOrder submission (scrambled Newari words).

    Distinguishes from translate: wordOrder begins with Newari words,
    not an English prompt. Same structural validation as translate.
    """
    return validate_translate(
        submitted_tile_ids, correct_sequence, valid_tile_ids,
        alternative_sequences,
    )


# ═════════════════════════════════════════════════════════════════════
# 7. dialogueComplete
# ═════════════════════════════════════════════════════════════════════

def validate_dialogue_complete(
    selected_option_id: str | None,
    correct_option_id: str | None,
    valid_option_ids: set[str],
    dialogue_structure: list[dict] | None = None,
) -> ValidationResult:
    """Validate a dialogueComplete submission.

    selected_option_id: id of the selected response option
    correct_option_id: server-side id of the correct response
    valid_option_ids: set of all valid response option ids
    dialogue_structure: optional dialogue structure for structural validation
    """
    if selected_option_id is None:
        return ValidationResult(
            valid=False, correct=False,
            error="No response option selected.",
        )
    if selected_option_id not in valid_option_ids:
        return ValidationResult(
            valid=False, correct=False,
            error=f"Unknown response option id: {selected_option_id}",
        )

    # Validate dialogue structure if provided
    if dialogue_structure is not None:
        if not isinstance(dialogue_structure, list) or len(dialogue_structure) < 2:
            return ValidationResult(
                valid=False, correct=False,
                error="Dialogue must contain at least two lines.",
            )

    correct = selected_option_id == correct_option_id
    return ValidationResult(valid=True, correct=correct)


# ═════════════════════════════════════════════════════════════════════
# Unified dispatcher
# ═════════════════════════════════════════════════════════════════════

EXERCISE_VALIDATORS = {
    "matchWords": validate_matchwords,
    "fillBlank": validate_fillblank,
    "pictureToWord": validate_picture_to_word,
    "wordToPicture": validate_word_to_picture,
    "translate": validate_translate,
    "wordOrder": validate_word_order,
    "dialogueComplete": validate_dialogue_complete,
}

ALL_EXERCISE_TYPES = list(EXERCISE_VALIDATORS.keys())


def validate_exercise(
    exercise_type: str,
    submitted: Any,
    exercise: dict[str, Any],
) -> ValidationResult:
    """Unified dispatcher for exercise answer validation.

    exercise: dict with exercise configuration fields including
    correct_answer_config, options, pairs, word_tiles, etc.
    """
    if exercise_type not in EXERCISE_VALIDATORS:
        return ValidationResult(
            valid=False, correct=False,
            error=f"Unknown exercise type: {exercise_type}",
        )

    config = exercise.get("correct_answer_config") or {}
    options = exercise.get("options") or []
    valid_option_ids = {o["id"] for o in options if isinstance(o, dict) and "id" in o}

    if exercise_type == "matchWords":
        correct_pairs = config.get("pairs") or exercise.get("pairs") or {}
        return validate_matchwords(submitted, correct_pairs)

    if exercise_type in ("fillBlank", "pictureToWord", "wordToPicture"):
        correct_option_id = config.get("correct_option_id") or exercise.get("answer_id")
        return EXERCISE_VALIDATORS[exercise_type](
            submitted, correct_option_id, valid_option_ids
        )

    if exercise_type == "dialogueComplete":
        correct_option_id = config.get("correct_option_id") or exercise.get("answer_id")
        return EXERCISE_VALIDATORS[exercise_type](
            submitted, correct_option_id, valid_option_ids,
            dialogue_structure=exercise.get("dialogue_structure"),
        )

    if exercise_type in ("translate", "wordOrder"):
        correct_sequence = config.get("correct_sequence") or []
        valid_tile_ids = {
            t["id"] for t in (exercise.get("word_tiles") or []) if isinstance(t, dict) and "id" in t
        }
        alternative_sequences = config.get("alternative_sequences") or []
        return EXERCISE_VALIDATORS[exercise_type](
            submitted, correct_sequence, valid_tile_ids, alternative_sequences
        )

    return ValidationResult(
        valid=False, correct=False,
        error=f"No validator for exercise type: {exercise_type}",
    )
