"""Curriculum blueprint for the English -> Newari pilot course (15 lessons).

Defines the complete 15-lesson blueprint from newari_course_plan.md with
111 planned exercise slots. Generates lesson and exercise records only
for exercise types supported by the available imported vocabulary:

  * matchWords  - Devanagari <-> English word pairs
  * fillBlank   - single-word answers with distractors
  * translate   - build the Newari answer from word tiles

Exercise types that require content we do NOT have are skipped
(never fabricated):
  * pictureToWord / wordToPicture - no illustration keys in the workbook
  * wordOrder / dialogueComplete  - no sentences or dialogue content

All generated content is unpublished (is_published=False) and must pass
native-speaker verification before activation. New lesson IDs use the
``en_new_u<unit>_l<lesson>`` scheme so the new curriculum cannot inherit
unrelated historical lesson completion records from legacy lessons
(which use ids like ``lesson_1`` ... ``lesson_7``).

Does not modify the existing Nepali curriculum or any legacy records.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from sqlalchemy.orm import Session

from app.models import (
    Exercise, Lesson, LessonVocabulary, Unit, VocabularyEntry,
)

# The five planned units, in course-plan order.
PLANNED_UNITS = [
    "Greetings",
    "Family",
    "Numbers & Colors",
    "Food & Drinks",
    "Home & Routines",
]

# Unit -> course-plan unit sequence (1-5) for the en_new course.
UNIT_SEQUENCE = {unit: idx + 1 for idx, unit in enumerate(PLANNED_UNITS)}

# Course-plan lesson number (1-15) -> unit name.
LESSON_TO_UNIT: dict[int, str] = {
    1: "Greetings", 2: "Greetings", 3: "Greetings",
    4: "Family", 5: "Family", 6: "Family",
    7: "Numbers & Colors", 8: "Numbers & Colors", 9: "Numbers & Colors",
    10: "Food & Drinks", 11: "Food & Drinks", 12: "Food & Drinks",
    13: "Home & Routines", 14: "Home & Routines", 15: "Home & Routines",
}

# Lesson numbers that are checkpoints / capstone (course plan Lesson Map).
CHECKPOINT_LESSONS = {3, 6, 9, 12, 15}

# Planned exercise-type sequence per lesson (course plan Lesson Map).
# Total planned slots: 5+6+7+6+7+8+6+7+8+7+8+9+8+9+10 = 111.
EXERCISE_SEQUENCES: dict[int, list[str]] = {
    1: ["matchWords", "fillBlank", "matchWords", "fillBlank", "pictureToWord"],
    2: ["matchWords", "fillBlank", "fillBlank", "pictureToWord", "matchWords", "fillBlank"],
    3: ["matchWords", "fillBlank", "fillBlank", "fillBlank", "translate", "translate", "dialogueComplete"],
    4: ["matchWords", "pictureToWord", "pictureToWord", "wordToPicture", "wordToPicture", "fillBlank"],
    5: ["matchWords", "wordToPicture", "wordToPicture", "pictureToWord", "fillBlank", "fillBlank", "matchWords"],
    6: ["matchWords", "pictureToWord", "wordToPicture", "fillBlank", "fillBlank", "translate", "translate", "wordOrder"],
    7: ["matchWords", "matchWords", "pictureToWord", "pictureToWord", "fillBlank", "fillBlank"],
    8: ["matchWords", "pictureToWord", "pictureToWord", "wordToPicture", "wordToPicture", "fillBlank", "fillBlank"],
    9: ["matchWords", "fillBlank", "fillBlank", "fillBlank", "translate", "translate", "wordOrder", "wordOrder"],
    10: ["matchWords", "pictureToWord", "pictureToWord", "wordToPicture", "wordToPicture", "fillBlank", "fillBlank"],
    11: ["matchWords", "fillBlank", "fillBlank", "fillBlank", "wordOrder", "wordOrder", "translate", "translate"],
    12: ["matchWords", "fillBlank", "fillBlank", "translate", "translate", "wordOrder", "wordOrder", "dialogueComplete", "dialogueComplete"],
    13: ["matchWords", "pictureToWord", "pictureToWord", "wordToPicture", "fillBlank", "fillBlank", "fillBlank", "translate"],
    14: ["matchWords", "fillBlank", "fillBlank", "fillBlank", "wordOrder", "wordOrder", "translate", "translate", "dialogueComplete"],
    15: ["matchWords", "fillBlank", "fillBlank", "pictureToWord", "translate", "translate", "wordOrder", "wordOrder", "dialogueComplete", "dialogueComplete"],
}

# Exercise types we can actually generate from imported vocabulary alone.
SUPPORTED_EXERCISE_TYPES = {"matchWords", "fillBlank", "translate"}

# Lesson titles (course plan Lesson Map).
LESSON_TITLES: dict[int, str] = {
    1: "First Words",
    2: "Meeting Someone",
    3: "Checkpoint: Greetings",
    4: "Close Family",
    5: "More People",
    6: "Checkpoint: Family",
    7: "Numbers 1-5",
    8: "Colors and Objects",
    9: "Checkpoint: Counting Things",
    10: "Basic Foods",
    11: "Eating and Drinking",
    12: "Checkpoint: At the Table",
    13: "Home and Places",
    14: "Daily Actions",
    15: "Capstone: A Day in Newari",
}

# Lesson subtitles.
LESSON_SUBTITLES: dict[int, str] = {
    1: "Hello, thank you, goodbye, yes/no",
    2: "How are you, I am fine, name, friend",
    3: "Review only — checkpoint",
    4: "Mother, father, sister, brother",
    5: "Son, daughter, family, person",
    6: "Review plus \"this is my...\"",
    7: "Counting words",
    8: "Colors and objects",
    9: "Numbers 6-10, \"two red bowls\"",
    10: "Rice, water, tea, milk, etc.",
    11: "Verbs: eat, drink, want",
    12: "Offering, asking, polite phrases",
    13: "Home, work, rest, clean",
    14: "Go, come, sleep, work",
    15: "Everything so far",
}


@dataclass
class WordPair:
    """A single Newari <-> English vocabulary pair."""

    newari_script: str
    english_meaning: str
    romanization: str | None = None


@dataclass
class GeneratedExercise:
    """A single exercise ready for database insertion."""

    id: str
    lesson_id: str
    exercise_type: str
    instruction: str
    sequence: int
    prompt: str | None = None
    prompt_hint: str | None = None
    image_key: str | None = None
    audio_key: str | None = None
    options: list[dict[str, Any]] | None = None
    answer_id: str | None = None
    pairs: dict[str, str] | None = None
    newari_script: str | None = None
    romanization: str | None = None
    correct_answer_config: dict[str, Any] | None = None
    word_tiles: list[dict[str, Any]] | None = None
    dialogue_structure: list[dict[str, Any]] | None = None


@dataclass
class GeneratedLesson:
    """A single lesson ready for database insertion."""

    lesson_id: str
    unit_id: int
    sequence: int
    title: str
    subtitle: str
    exercise_type: str
    xp_reward: int
    word_count: int
    required_level: int
    is_published: bool
    is_checkpoint: bool
    exercises: list[GeneratedExercise] = field(default_factory=list)
    introduced_vocab: list[WordPair] = field(default_factory=list)
    reviewed_vocab: list[WordPair] = field(default_factory=list)


def _make_match_exercise(ex_id: str, lesson_id: str, sequence: int,
                         pairs: list[WordPair]) -> GeneratedExercise | None:
    """Create a matchWords exercise from Newari <-> English word pairs."""
    if len(pairs) < 2:
        return None
    options = []
    pair_map: dict[str, str] = {}
    for i, pair in enumerate(pairs):
        d_id = f"{ex_id}_d{i + 1}"
        e_id = f"{ex_id}_e{i + 1}"
        options.append({"id": d_id, "text": pair.newari_script, "is_devanagari": True})
        options.append({"id": e_id, "text": pair.english_meaning})
        pair_map[d_id] = e_id
    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="matchWords",
        instruction="Match the words", sequence=sequence,
        options=options, pairs=pair_map,
        correct_answer_config={"pairs": pair_map},
    )


def _make_fillblank_exercise(ex_id: str, lesson_id: str, sequence: int,
                             answer: WordPair, distractors: list[WordPair]) -> GeneratedExercise | None:
    """Create a fillBlank exercise: show English hint, pick the Newari word."""
    if not distractors:
        return None
    options = [{"id": f"{ex_id}_a", "text": answer.newari_script, "is_devanagari": True}]
    for i, distractor in enumerate(distractors):
        options.append({"id": f"{ex_id}_d{i + 1}", "text": distractor.newari_script, "is_devanagari": True})
    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="fillBlank",
        instruction="Fill in the blank",
        prompt=f"___ ({answer.english_meaning})", prompt_hint=answer.english_meaning,
        sequence=sequence, options=options, answer_id=f"{ex_id}_a",
        correct_answer_config={"correct_option_id": f"{ex_id}_a"},
        newari_script=answer.newari_script,
        romanization=answer.romanization,
    )


def _make_translate_exercise(ex_id: str, lesson_id: str, sequence: int,
                             target: WordPair) -> GeneratedExercise | None:
    """Create a translate exercise: build Newari from word tiles."""
    # Each character is a tile; repeated characters get distinct tile IDs
    tiles = []
    tile_ids = []
    for i, ch in enumerate(target.newari_script):
        tile_id = f"{ex_id}_t{i + 1}"
        tiles.append({
            "id": tile_id,
            "text": ch,
            "is_devanagari": True,
        })
        tile_ids.append(tile_id)

    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="translate",
        instruction=f"Build the Newari word for '{target.english_meaning}'",
        prompt=target.english_meaning, prompt_hint=target.romanization,
        sequence=sequence,
        word_tiles=tiles,
        newari_script=target.newari_script,
        romanization=target.romanization,
        correct_answer_config={
            "correct_sequence": tile_ids,
            "alternative_sequences": [],
        },
    )


def _lesson_id(course_id: str, unit_sequence: int, lesson_seq: int) -> str:
    """Stable, unique lesson id that cannot collide with legacy ids."""
    return f"{course_id}_u{unit_sequence}_l{lesson_seq}"


def _exercise_id(lesson_id: str, exercise_type: str, index: int) -> str:
    return f"{lesson_id}_{exercise_type}{index}"


def _parse_lesson_numbers_str(raw: str | None) -> list[int]:
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


def vocabulary_for_lesson(db: Session, lesson_number: int
                          ) -> tuple[list[WordPair], list[WordPair]]:
    """Split vocabulary into (introduced, reviewed) for a given lesson number.

    A word is introduced in the first lesson listed in its ``lesson_numbers``;
    it is reviewed in every subsequent lesson listed. Reads directly from
    the database rows to preserve the workbook's lesson assignments.
    """
    introduced: list[WordPair] = []
    reviewed: list[WordPair] = []
    rows = db.query(VocabularyEntry).all()
    for row in rows:
        nums = _parse_lesson_numbers_str(row.lesson_numbers)
        if not nums:
            continue
        pair = WordPair(
            newari_script=row.newari_script,
            english_meaning=row.english_meaning,
            romanization=row.romanization,
        )
        if nums[0] == lesson_number:
            introduced.append(pair)
        elif lesson_number in nums:
            reviewed.append(pair)
    return introduced, reviewed


def generate_blueprint_lessons(db: Session, course_id: str,
                               units: list[Unit]) -> list[GeneratedLesson]:
    """Generate the 15-lesson Newari blueprint from imported vocabulary.

    For each course-plan lesson (1-15), determines which vocabulary is
    introduced and reviewed, then generates exercises only for supported
    types. Lessons with zero supported exercises are still created as
    unpublished shells.
    """
    lessons: list[GeneratedLesson] = []

    for course_plan_lesson in range(1, 16):
        unit_name = LESSON_TO_UNIT[course_plan_lesson]
        unit_sequence = UNIT_SEQUENCE[unit_name]
        # Find the Unit row matching this course_id and sequence.
        unit_row = next((u for u in units
                         if u.course_id == course_id and u.sequence == unit_sequence), None)
        if unit_row is None:
            continue

        lesson_seq_in_unit = ((course_plan_lesson - 1) % 3) + 1
        lesson_id = _lesson_id(course_id, unit_sequence, lesson_seq_in_unit)
        is_checkpoint = course_plan_lesson in CHECKPOINT_LESSONS

        introduced, reviewed = vocabulary_for_lesson(db, course_plan_lesson)
        all_available = introduced + reviewed

        # Dedup by English meaning, preserving order.
        seen: set[str] = set()
        unique_available: list[WordPair] = []
        for pair in all_available:
            if pair.english_meaning not in seen:
                seen.add(pair.english_meaning)
                unique_available.append(pair)

        exercise_types = EXERCISE_SEQUENCES[course_plan_lesson]
        exercises: list[GeneratedExercise] = []

        # Allocate distinct words to each exercise slot where possible.
        word_index = 0
        for slot_idx, ex_type in enumerate(exercise_types, start=1):
            if ex_type not in SUPPORTED_EXERCISE_TYPES:
                # Cannot fabricate picture/word-order/dialogue content.
                continue

            ex_id = _exercise_id(lesson_id, ex_type, slot_idx)

            if ex_type == "matchWords":
                pairs = unique_available[word_index:word_index + 4]
                word_index += len(pairs)
                ex = _make_match_exercise(ex_id, lesson_id, slot_idx, pairs)
            elif ex_type == "fillBlank":
                if word_index + 1 >= len(unique_available):
                    break
                answer = unique_available[word_index]
                word_index += 1
                distractors = unique_available[word_index:word_index + 3]
                word_index += len(distractors)
                if not distractors:
                    continue
                ex = _make_fillblank_exercise(ex_id, lesson_id, slot_idx, answer, distractors)
            elif ex_type == "translate":
                if word_index >= len(unique_available):
                    break
                target = unique_available[word_index]
                word_index += 1
                ex = _make_translate_exercise(ex_id, lesson_id, slot_idx, target)
            else:
                continue

            if ex is not None:
                exercises.append(ex)

        # Primary exercise type: first supported type, or first planned type.
        primary_type = next((t for t in exercise_types if t in SUPPORTED_EXERCISE_TYPES),
                            exercise_types[0])

        lesson = GeneratedLesson(
            lesson_id=lesson_id,
            unit_id=unit_row.id,
            sequence=lesson_seq_in_unit,
            title=LESSON_TITLES[course_plan_lesson],
            subtitle=LESSON_SUBTITLES[course_plan_lesson],
            exercise_type=primary_type,
            xp_reward=20,
            word_count=len(unique_available),
            required_level=1,
            is_published=False,
            is_checkpoint=is_checkpoint,
            exercises=exercises,
            introduced_vocab=introduced,
            reviewed_vocab=reviewed,
        )
        lessons.append(lesson)

    return lessons


def seed_blueprint(db: Session, course_id: str = "en_new") -> dict[str, int]:
    """Insert the 15-lesson blueprint into the database idempotently.

    Creates lesson records, exercise records, and lesson_vocabulary links.
    All content is is_published=False. Re-running produces no duplicate
    lessons or exercises (matched by stable id).
    """
    from app.models import Course

    course = db.get(Course, course_id)
    if course is None:
        raise ValueError(f"Course {course_id} not found")

    units = list(db.query(Unit).filter(Unit.course_id == course_id).all())
    if not units:
        raise ValueError(f"No units found for course {course_id}")

    generated = generate_blueprint_lessons(db, course_id, units)

    lessons_created = 0
    lessons_existed = 0
    exercises_created = 0
    exercises_existed = 0
    vocab_links_created = 0

    for gl in generated:
        existing = db.get(Lesson, gl.lesson_id)
        if existing is None:
            db.add(Lesson(
                id=gl.lesson_id, unit_id=gl.unit_id, sequence=gl.sequence,
                title=gl.title, subtitle=gl.subtitle,
                exercise_type=gl.exercise_type, xp_reward=gl.xp_reward,
                word_count=gl.word_count, required_level=gl.required_level,
                is_published=gl.is_published, is_checkpoint=gl.is_checkpoint,
            ))
            lessons_created += 1
        else:
            # Sync non-content fields; never touch attempts/history.
            existing.is_checkpoint = gl.is_checkpoint
            existing.is_published = gl.is_published
            existing.exercise_type = gl.exercise_type
            existing.word_count = gl.word_count
            lessons_existed += 1

        # Create / sync exercises for this lesson.
        existing_ex_ids = {
            e.id for e in db.query(Exercise).filter(Exercise.lesson_id == gl.lesson_id).all()
        }
        for ex in gl.exercises:
            if ex.id in existing_ex_ids:
                exercises_existed += 1
                continue
            db.add(Exercise(
                id=ex.id, lesson_id=ex.lesson_id,
                exercise_type=ex.exercise_type, instruction=ex.instruction,
                prompt=ex.prompt, prompt_hint=ex.prompt_hint,
                image_key=ex.image_key, audio_key=ex.audio_key,
                sequence=ex.sequence, options=ex.options,
                answer_id=ex.answer_id, pairs=ex.pairs,
                newari_script=ex.newari_script,
                romanization=ex.romanization,
                correct_answer_config=ex.correct_answer_config,
                word_tiles=ex.word_tiles,
                dialogue_structure=ex.dialogue_structure,
            ))
            exercises_created += 1

        # Create lesson_vocabulary links for introduced + reviewed vocab.
        all_vocab = gl.introduced_vocab + gl.reviewed_vocab
        for idx, pair in enumerate(all_vocab):
            # Find the vocabulary entry id.
            row = (db.query(VocabularyEntry)
                   .filter_by(english_meaning=pair.english_meaning,
                              newari_script=pair.newari_script).first())
            if row is None:
                continue
            role = "introduced" if pair in gl.introduced_vocab else "reviewed"
            existing_link = (db.query(LessonVocabulary)
                             .filter_by(lesson_id=gl.lesson_id,
                                        vocabulary_entry_id=row.id, role=role).first())
            if existing_link is None:
                db.add(LessonVocabulary(
                    lesson_id=gl.lesson_id,
                    vocabulary_entry_id=row.id,
                    role=role, sequence=idx + 1,
                ))
                vocab_links_created += 1

    db.commit()

    return {
        "lessons_created": lessons_created,
        "lessons_existed": lessons_existed,
        "exercises_created": exercises_created,
        "exercises_existed": exercises_existed,
        "vocab_links_created": vocab_links_created,
        "total_lessons": len(generated),
        "total_planned_exercises": sum(len(EXERCISE_SEQUENCES[i]) for i in range(1, 16)),
        "total_created_exercises": exercises_created,
    }
