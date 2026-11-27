"""Pure progression calculations sourced from the authoritative lesson JSON."""

from __future__ import annotations

from collections.abc import Iterable
from math import floor
from typing import Any

from app.curriculum_blueprint import load_curriculum


def compute_hero_stats(completed_lesson_ids: Iterable[str]) -> dict[str, int]:
    curriculum = load_curriculum()
    progression = curriculum["progression"]
    stats = dict(progression["base_stats"])
    lessons = {lesson["id"]: lesson for lesson in curriculum["lessons"]}
    for lesson_id in set(completed_lesson_ids):
        lesson = lessons.get(lesson_id)
        if lesson is None:
            continue
        for stat, gain in lesson.get("stat_gains", {}).items():
            stats[stat] = stats.get(stat, 0) + int(gain)
    return stats


def earned_xp(results: Iterable[dict[str, Any]]) -> int:
    """Sum source exercise XP only for answers finalized as correct."""
    return sum(int(result.get("xp", 0)) for result in results if result.get("correct"))


def credited_xp(
    earned: int, previous_best: int, *, completed_before: bool
) -> int:
    if completed_before:
        return floor(earned * float(load_curriculum()["progression"]["rules"]["replay_xp_multiplier"]))
    return max(0, earned - previous_best)


def lesson_passed(lesson: dict[str, Any], correct: int, total: int) -> bool:
    if total <= 0:
        return False
    if not lesson.get("is_checkpoint"):
        return True
    threshold = float(
        lesson.get("pass_threshold")
        or load_curriculum()["progression"]["rules"]["checkpoint_pass_threshold"]
    )
    return correct / total >= threshold


def xp_to_next_level(level: int) -> int:
    return 100 + 25 * (max(level, 1) - 1)


def level_state(total_xp: int) -> tuple[int, int, int]:
    """Return (level, XP earned within level, XP required to reach next)."""
    level = 1
    remaining = max(total_xp, 0)
    required = xp_to_next_level(level)
    while remaining >= required:
        remaining -= required
        level += 1
        required = xp_to_next_level(level)
    return level, remaining, required


def hero_class(level: int) -> str:
    if level <= 2:
        return "Traveler"
    if level <= 4:
        return "Speaker"
    if level <= 6:
        return "Guardian"
    return "Master"
