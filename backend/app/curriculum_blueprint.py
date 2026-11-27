"""Load and idempotently seed the authoritative JSON Newari curriculum."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models import Exercise, Lesson, Unit

CURRICULUM_VERSION = "newari_v2"
ACTIVE_EXERCISE_TYPES = {
    "matchWords",
    "fillBlank",
    "pictureToWord",
    "wordToPicture",
}
SUPPORTED_ILLUSTRATION_KEYS = {"person", "house", "droplet", "bowl"}


def _content_path() -> Path:
    return Path(__file__).resolve().parents[2] / "newari_lessons_content.json"


@lru_cache(maxsize=1)
def load_curriculum() -> dict[str, Any]:
    path = _content_path()
    if not path.is_file():
        raise FileNotFoundError(f"Authoritative curriculum JSON not found: {path}")
    curriculum = json.loads(path.read_text(encoding="utf-8"))
    validate_curriculum(curriculum)
    return curriculum


def validate_curriculum(curriculum: dict[str, Any]) -> None:
    units = curriculum.get("units")
    words = curriculum.get("words")
    lessons = curriculum.get("lessons")
    if not isinstance(units, list) or not isinstance(words, list) or not isinstance(lessons, list):
        raise ValueError("Curriculum must contain units, words, and lessons arrays")
    if len({unit["id"] for unit in units}) != len(units):
        raise ValueError("Curriculum contains duplicate unit ids")
    if len({word["id"] for word in words}) != len(words):
        raise ValueError("Curriculum contains duplicate word ids")
    if len({lesson["id"] for lesson in lessons}) != len(lessons):
        raise ValueError("Curriculum contains duplicate lesson ids")

    unit_ids = {unit["id"] for unit in units}
    word_ids = {word["id"] for word in words}
    exercise_ids: set[str] = set()
    total_exercises = total_xp = 0
    for lesson in lessons:
        if lesson["unit_id"] not in unit_ids:
            raise ValueError(f"{lesson['id']} references an unknown unit")
        if not set(lesson.get("new_word_ids", []) + lesson.get("review_word_ids", [])).issubset(word_ids):
            raise ValueError(f"{lesson['id']} references an unknown vocabulary id")
        exercises = lesson.get("exercises")
        if not isinstance(exercises, list) or len(exercises) != lesson.get("exercise_count"):
            raise ValueError(f"{lesson['id']} exercise count does not match its content")
        if sum(int(exercise["xp"]) for exercise in exercises) != lesson["xp_max"]:
            raise ValueError(f"{lesson['id']} exercise XP does not match xp_max")
        total_xp += lesson["xp_max"]
        total_exercises += len(exercises)
        for exercise in exercises:
            exercise_id = exercise["id"]
            if exercise_id in exercise_ids:
                raise ValueError(f"{exercise_id} is duplicated in the curriculum")
            exercise_ids.add(exercise_id)
            if exercise.get("type") not in ACTIVE_EXERCISE_TYPES:
                raise ValueError(f"{exercise_id} has unsupported active type")
            target_word_id = exercise.get("target_word_id")
            if target_word_id and target_word_id not in word_ids:
                raise ValueError(f"{exercise_id} references an unknown word")
            if exercise["type"] == "matchWords":
                pairs = exercise.get("pairs")
                if not isinstance(pairs, list) or len(pairs) < 2:
                    raise ValueError(f"{exercise_id} requires at least two pairs")
                if not all(isinstance(pair, dict) for pair in pairs):
                    raise ValueError(f"{exercise_id} contains an invalid pair")
                pair_word_ids = [pair.get("word_id") for pair in pairs]
                if any(word_id not in word_ids for word_id in pair_word_ids):
                    raise ValueError(f"{exercise_id} references an unknown pair word")
                if len(set(pair_word_ids)) != len(pair_word_ids):
                    raise ValueError(f"{exercise_id} contains duplicate pair words")
            else:
                options = exercise.get("options")
                answer_index = exercise.get("answer_index")
                if not isinstance(options, list) or not options:
                    raise ValueError(f"{exercise_id} has no options")
                if not all(isinstance(option, dict) for option in options):
                    raise ValueError(f"{exercise_id} contains an invalid option")
                if not isinstance(answer_index, int) or not 0 <= answer_index < len(options):
                    raise ValueError(f"{exercise_id} has an invalid answer_index")
                rendered = [
                    (option.get("text"), option.get("roman"), option.get("image_key"))
                    for option in options
                ]
                if len(rendered) != len(set(map(json.dumps, rendered))):
                    raise ValueError(f"{exercise_id} contains duplicate options")
                if exercise["type"] == "fillBlank":
                    sentence = (exercise.get("layout") or {}).get("sentence")
                    blanks = (
                        [
                            part
                            for part in sentence
                            if isinstance(part, dict) and part.get("blank") is True
                        ]
                        if isinstance(sentence, list)
                        else []
                    )
                    if len(blanks) != 1:
                        raise ValueError(f"{exercise_id} must have exactly one blank")
                elif exercise["type"] == "pictureToWord":
                    if target_word_id not in word_ids:
                        raise ValueError(f"{exercise_id} has no valid target word")
                    if exercise.get("image_key") not in SUPPORTED_ILLUSTRATION_KEYS:
                        raise ValueError(
                            f"{exercise_id} references an unsupported illustration"
                        )
                elif exercise["type"] == "wordToPicture":
                    if target_word_id not in word_ids:
                        raise ValueError(f"{exercise_id} has no valid target word")
                    if any(
                        option.get("image_key") not in SUPPORTED_ILLUSTRATION_KEYS
                        for option in options
                    ):
                        raise ValueError(
                            f"{exercise_id} contains an unsupported illustration"
                        )
            if exercise.get("planned_type") and exercise["type"] != "fillBlank":
                raise ValueError(f"{exercise_id} planned fallback must remain fillBlank")

    expected = curriculum.get("progression", {}).get("totals", {})
    if expected.get("exercises") != total_exercises or expected.get("xp_max") != total_xp:
        raise ValueError("Curriculum totals do not match the lesson content")


def _word_maps(curriculum: dict[str, Any]) -> tuple[dict[str, dict], dict[str, str]]:
    words = {word["id"]: word for word in curriculum["words"]}
    image_by_word: dict[str, str] = {}
    for lesson in curriculum["lessons"]:
        for exercise in lesson["exercises"]:
            if exercise["type"] == "pictureToWord":
                if exercise.get("image_key") not in SUPPORTED_ILLUSTRATION_KEYS:
                    raise ValueError(f"{exercise['id']} references an unsupported illustration")
                image_by_word[exercise["target_word_id"]] = exercise["image_key"]
            elif exercise["type"] == "wordToPicture":
                target = exercise["target_word_id"]
                correct_image = exercise["options"][exercise["answer_index"]]["image_key"]
                if correct_image not in SUPPORTED_ILLUSTRATION_KEYS:
                    raise ValueError(f"{exercise['id']} references an unsupported illustration")
                image_by_word[target] = correct_image
    return words, image_by_word


def _word_id_for_option(option: dict, words: dict[str, dict]) -> str | None:
    for word_id, word in words.items():
        if (
            option.get("text") in (word["newari"], word["english"])
            and (not option.get("roman") or option["roman"] == word["roman"])
        ):
            return word_id
    return None


def _exercise_record(
    source: dict[str, Any],
    lesson_id: str,
    sequence: int,
    words: dict[str, dict],
    image_by_word: dict[str, str],
) -> Exercise:
    exercise_id = source["id"]
    exercise_type = source["type"]
    target_id = source.get("target_word_id")
    target = words.get(target_id)
    options: list[dict[str, Any]] = []
    pairs: dict[str, str] = {}
    correct_answer_config: dict[str, Any] = {}
    image_key = source.get("image_key")
    prompt = source.get("prompt")
    romanization = target["roman"] if target and source.get("show_roman_under_prompt") else None
    newari_script = target["newari"] if target else None

    if exercise_type == "matchWords":
        pair_words: dict[str, str] = {}
        for pair in source["pairs"]:
            dev_id = f"{exercise_id}-D-{pair['word_id']}"
            eng_id = f"{exercise_id}-E-{pair['word_id']}"
            options.extend(
                [
                    {
                        "id": dev_id,
                        "text": pair["newari"],
                        "is_devanagari": True,
                        "romanization": pair["roman"],
                        "word_id": pair["word_id"],
                    },
                    {
                        "id": eng_id,
                        "text": pair["english"],
                        "is_devanagari": False,
                        "word_id": pair["word_id"],
                    },
                ]
            )
            pairs[dev_id] = eng_id
            pair_words[dev_id] = pair["word_id"]
        correct_answer_config = {"pairs": pairs, "word_ids_by_devanagari": pair_words}
    elif exercise_type == "wordToPicture":
        target = words[target_id]
        for index, option in enumerate(source["options"]):
            word_id = next(
                (candidate_id for candidate_id, key in image_by_word.items()
                 if key == option["image_key"]),
                None,
            )
            word = words.get(word_id) if word_id else None
            if word is None:
                raise ValueError(f"{exercise_id} image has no matching curriculum word")
            options.append(
                {
                    "id": f"{exercise_id}-O{index + 1}",
                    "text": word["newari"],
                    "is_devanagari": True,
                    "romanization": word["roman"],
                    "image_key": option["image_key"],
                    "word_id": word_id,
                }
            )
        newari_script = target["newari"]
        romanization = target["roman"]
        correct_answer_config = {
            "correct_option_id": options[source["answer_index"]]["id"]
        }
    else:
        for index, option in enumerate(source["options"]):
            word_id = _word_id_for_option(option, words)
            is_devanagari = bool(option.get("roman"))
            options.append(
                {
                    "id": f"{exercise_id}-O{index + 1}",
                    "text": option.get("text") or "",
                    "is_devanagari": is_devanagari,
                    "romanization": option.get("roman"),
                    "image_key": option.get("image_key"),
                    "word_id": word_id,
                }
            )
        correct_answer_config = {
            "correct_option_id": options[source["answer_index"]]["id"]
        }
        if exercise_type == "pictureToWord":
            image_key = source["image_key"]

    content = dict(source)
    if exercise_type == "fillBlank":
        layout = dict(source["layout"])
        tile = dict(layout["tile"])
        tile_image = image_by_word.get(target_id)
        if tile_image:
            tile["image_key"] = tile_image
        layout["tile"] = tile
        content["layout"] = layout

    return Exercise(
        id=exercise_id,
        lesson_id=lesson_id,
        exercise_type=exercise_type,
        instruction={
            "matchWords": "Match each Newari word to its meaning",
            "fillBlank": "Fill in the blank",
            "pictureToWord": "Name the picture",
            "wordToPicture": "Pick the picture",
        }[exercise_type],
        prompt=prompt,
        image_key=image_key,
        sequence=sequence,
        xp=int(source["xp"]),
        options=options,
        answer_id=correct_answer_config.get("correct_option_id"),
        pairs=pairs or None,
        newari_script=newari_script,
        romanization=romanization,
        correct_answer_config=correct_answer_config,
        vocabulary_reference={"word_ids": [target_id]} if target_id else None,
        content_data=content,
    )


def seed_curriculum(db: Session, course_id: str = "en_new") -> dict[str, int]:
    """Upsert JSON content without changing legacy lessons or learner records."""
    curriculum = load_curriculum()
    words, image_by_word = _word_maps(curriculum)
    unit_rows: dict[str, Unit] = {}
    created_units = created_lessons = created_exercises = 0

    for unit_sequence, unit_data in enumerate(curriculum["units"], start=1):
        unit = db.scalar(
            select(Unit).where(
                Unit.course_id == course_id,
                Unit.curriculum_version == CURRICULUM_VERSION,
                Unit.sequence == unit_sequence,
            )
        )
        if unit is None:
            unit = Unit(
                course_id=course_id,
                curriculum_version=CURRICULUM_VERSION,
                sequence=unit_sequence,
                title=unit_data["title"],
                description=unit_data["title"],
            )
            db.add(unit)
            db.flush()
            created_units += 1
        else:
            unit.title = unit_data["title"]
        unit_rows[unit_data["id"]] = unit

    for lesson_data in curriculum["lessons"]:
        unit = unit_rows[lesson_data["unit_id"]]
        lesson = db.get(Lesson, lesson_data["id"])
        local_sequence = (int(lesson_data["number"]) - 1) % 3 + 1
        if lesson is not None and (
            lesson.content_data is None
            or lesson.unit_id is None
            or db.get(Unit, lesson.unit_id).curriculum_version != CURRICULUM_VERSION
        ):
            raise ValueError(
                f"Lesson id {lesson.id} already belongs to historical content; "
                "refusing to overwrite it"
            )
        if lesson is None:
            lesson = Lesson(
                id=lesson_data["id"],
                unit_id=unit.id,
                sequence=local_sequence,
                title=lesson_data["title"],
                subtitle=unit.title,
                exercise_type=lesson_data["exercises"][0]["type"],
                xp_reward=int(lesson_data["xp_max"]),
                word_count=len(lesson_data["new_word_ids"]),
                required_level=1,
                is_published=bool(lesson_data["is_published"]),
                is_checkpoint=bool(lesson_data["is_checkpoint"]),
                passing_score=round(float(lesson_data.get("pass_threshold") or 0) * 100),
                content_data={
                    key: value for key, value in lesson_data.items()
                    if key != "exercises"
                },
            )
            db.add(lesson)
            db.flush()
            created_lessons += 1
        else:
            lesson.unit_id = unit.id
            lesson.sequence = local_sequence
            lesson.title = lesson_data["title"]
            lesson.subtitle = unit.title
            lesson.exercise_type = lesson_data["exercises"][0]["type"]
            lesson.xp_reward = int(lesson_data["xp_max"])
            lesson.word_count = len(lesson_data["new_word_ids"])
            lesson.is_published = bool(lesson_data["is_published"])
            lesson.is_checkpoint = bool(lesson_data["is_checkpoint"])
            lesson.passing_score = round(float(lesson_data.get("pass_threshold") or 0) * 100)
            lesson.content_data = {
                key: value for key, value in lesson_data.items()
                if key != "exercises"
            }

        existing_ids = set(
            db.scalars(select(Exercise.id).where(Exercise.lesson_id == lesson.id)).all()
        )
        expected_ids = {exercise["id"] for exercise in lesson_data["exercises"]}
        if existing_ids - expected_ids:
            raise ValueError(
                f"{lesson.id} has stored exercises absent from the source JSON; "
                "refusing to delete historical exercise records"
            )
        for sequence, exercise_data in enumerate(lesson_data["exercises"], start=1):
            exercise = db.get(Exercise, exercise_data["id"])
            if exercise is not None and (
                exercise.lesson_id != lesson.id or exercise.content_data is None
            ):
                raise ValueError(
                    f"Exercise id {exercise.id} already belongs to historical content; "
                    "refusing to overwrite it"
                )
            if exercise is None:
                exercise = _exercise_record(
                    exercise_data, lesson.id, sequence, words, image_by_word
                )
                db.add(exercise)
                created_exercises += 1
            else:
                rebuilt = _exercise_record(
                    exercise_data, lesson.id, sequence, words, image_by_word
                )
                for field in (
                    "exercise_type", "instruction", "prompt", "image_key", "sequence",
                    "xp", "options", "answer_id", "pairs", "newari_script",
                    "romanization", "correct_answer_config", "vocabulary_reference",
                    "content_data",
                ):
                    setattr(exercise, field, getattr(rebuilt, field))

    return {
        "units_created": created_units,
        "lessons_created": created_lessons,
        "exercises_created": created_exercises,
        "unit_count": len(curriculum["units"]),
        "lesson_count": len(curriculum["lessons"]),
        "exercise_count": sum(lesson["exercise_count"] for lesson in curriculum["lessons"]),
        "word_count": len(curriculum["words"]),
        "xp_max": sum(lesson["xp_max"] for lesson in curriculum["lessons"]),
    }


def active_lessons_query():
    return (
        select(Lesson)
        .join(Unit, Lesson.unit_id == Unit.id)
        .where(
            Unit.course_id == "en_new",
            Unit.curriculum_version == CURRICULUM_VERSION,
        )
        .options(selectinload(Lesson.exercises), selectinload(Lesson.unit))
        .order_by(Unit.sequence, Lesson.sequence)
    )


def active_lesson_ids() -> list[str]:
    return [lesson["id"] for lesson in load_curriculum()["lessons"]]


def exercise_count(lesson: Lesson) -> int:
    return len(lesson.exercises or [])
