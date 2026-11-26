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
SUPPORTED_EXERCISE_TYPES = {
    "matchWords", "fillBlank", "pictureToWord", "wordToPicture", "translate",
    "wordOrder", "dialogueComplete",
}
ILLUSTRATION_KEY_BY_ENGLISH = {
    "Hello": "hello", "Thank you": "thanks", "Yes": "yes", "No": "no",
    "Good": "good", "Well / fine": "fine", "I": "self", "You": "you",
    "Name": "name", "What": "what", "Who": "who",
    "You (plural / formal)": "formal_people",
    "Mother": "mother", "Father": "father", "Elder sister": "elder_sister",
    "Elder brother": "elder_brother", "Younger brother": "younger_brother",
    "Younger sister": "younger_sister", "Son": "son", "Daughter": "daughter",
    "Child": "child", "Person": "person", "Woman": "woman", "Man": "man",
    "One": "number_1", "Two": "number_2", "Three": "number_3",
    "Four": "number_4", "Five": "number_5", "Six": "number_6",
    "Seven": "number_7", "Eight": "number_8", "Nine": "number_9",
    "Ten": "number_10", "How many": "how_many", "Red": "red",
    "White": "white", "House / home": "house", "Water": "droplet",
    "Bowl": "bowl", "Paper / book": "book", "Cooked rice": "cooked_rice",
    "Tea": "tea", "Meat": "meat", "Fish": "fish", "Beaten rice": "beaten_rice",
    "To eat": "to_eat", "To drink": "to_drink", "To give": "to_give",
    "To take": "to_take", "Big": "big", "Small": "small", "Door": "door",
    "Road": "road", "Place": "place", "Work": "work", "Fire": "fire",
    "Where": "where", "To read / study": "to_read", "To go": "to_go",
    "To come": "to_come", "To do": "to_do", "To sit / stay": "to_sit",
    "To see": "to_see", "Today": "today", "To write": "to_write",
}
SUPPORTED_ILLUSTRATION_KEYS = set(ILLUSTRATION_KEY_BY_ENGLISH.values())
PICTURE_TO_WORD_TARGETS = {
    1: ["Hello"], 2: ["Name"], 4: ["Mother", "Father"],
    5: ["Child"], 6: ["Person"], 7: ["One", "Two"],
    8: ["House / home", "Bowl"], 10: ["Cooked rice", "Tea"],
    13: ["Door", "Road"], 15: ["Water"],
}
WORD_TO_PICTURE_TARGETS = {
    4: ["Elder sister", "Elder brother"], 5: ["Woman", "Man"],
    6: ["Person"], 8: ["House / home", "Paper / book"],
    10: ["Meat", "Fish"], 13: ["Place"],
}

# ── wordOrder phrase definitions ──────────────────────────────────
# Each entry: (English prompt, [ordered Newari words], [ordered romanizations])
# These are simple 2-3 word phrases built from imported vocabulary.
# Content is provisional/developmental and must pass native-speaker verification.
WORD_ORDER_PHRASES: dict[int, list[tuple[str, list[str], list[str]]]] = {
    6: [  # Checkpoint: Family — "This is my..."
        ("This is my mother", ["थ्व", "जिगु", "माँ"], ["thwa", "jigu", "māṃ"]),
    ],
    9: [  # Checkpoint: Counting Things — "two red bowls"
        ("two red bowls", ["नि", "ह्यूँ", "कचा"], ["ni", "hyūṃ", "kachā"]),
        ("one white house", ["छ", "तुयु", "छेँ"], ["chha", "tuyu", "chhẽ"]),
    ],
    11: [  # Eating and Drinking
        ("eat cooked rice", ["जा", "नेगु"], ["jā", "negu"]),
        ("drink tea", ["चा", "त्वनेगु"], ["chā", "twanegu"]),
    ],
    12: [  # Checkpoint: At the Table
        ("give water", ["लः", "बियेगु"], ["laḥ", "biyegu"]),
        ("take cooked rice", ["जा", "कायेगु"], ["jā", "kāyegu"]),
    ],
    14: [  # Daily Actions
        ("go to work", ["ज्या", "वनेगु"], ["jyā", "wanegu"]),
        ("come today", ["थौँ", "वयेगु"], ["thau", "wayegu"]),
    ],
    15: [  # Capstone: A Day in Newari
        ("read a book", ["पौ", "ब्वनेगु"], ["pau", "bwanegu"]),
        ("write today", ["थौँ", "च्वयेगु"], ["thau", "chwayegu"]),
    ],
}

# ── dialogueComplete definitions ──────────────────────────────────
# Each entry: (dialogue_lines, correct_option_index, option_texts)
# dialogue_lines: list of {speaker, text, romanization?, missing?}
# Content is provisional/developmental and must pass native-speaker verification.
DIALOGUE_CONTENT: dict[int, list[dict[str, Any]]] = {
    3: [{  # Checkpoint: Greetings
        "dialogue": [
            {"speaker": "A", "text": "ज्वजलपा", "romanization": "jwajalapa"},
            {"speaker": "B", "text": "___", "missing": True},
            {"speaker": "A", "text": "सुभाय्", "romanization": "subhāy"},
        ],
        "options": [
            {"text": "ज्वजलपा", "romanization": "jwajalapa", "correct": True},
            {"text": "मखु", "romanization": "makhu"},
            {"text": "छु", "romanization": "chhu"},
            {"text": "सु", "romanization": "su"},
        ],
    }],
    12: [  # Checkpoint: At the Table
        {
            "dialogue": [
                {"speaker": "A", "text": "चा त्वनेगु?", "romanization": "chā twanegu?"},
                {"speaker": "B", "text": "___", "missing": True},
                {"speaker": "A", "text": "सुभाय्", "romanization": "subhāy"},
            ],
            "options": [
                {"text": "खः", "romanization": "khaḥ", "correct": True},
                {"text": "मखु", "romanization": "makhu"},
                {"text": "ला", "romanization": "lā"},
                {"text": "लः", "romanization": "laḥ"},
            ],
        },
        {
            "dialogue": [
                {"speaker": "A", "text": "छु नेगु?", "romanization": "chhu negu?"},
                {"speaker": "B", "text": "___", "missing": True},
            ],
            "options": [
                {"text": "जा", "romanization": "jā", "correct": True},
                {"text": "चा", "romanization": "chā"},
                {"text": "लः", "romanization": "laḥ"},
                {"text": "पौ", "romanization": "pau"},
            ],
        },
    ],
    14: [{  # Daily Actions
        "dialogue": [
            {"speaker": "A", "text": "थौँ गन वनेगु?", "romanization": "thau gana wanegu?"},
            {"speaker": "B", "text": "___", "missing": True},
            {"speaker": "A", "text": "बांलाः", "romanization": "bāṅlāḥ"},
        ],
        "options": [
            {"text": "ज्या वनेगु", "romanization": "jyā wanegu", "correct": True},
            {"text": "चा त्वनेगु", "romanization": "chā twanegu"},
            {"text": "थौँ", "romanization": "thau"},
            {"text": "मखु", "romanization": "makhu"},
        ],
    }],
    15: [  # Capstone: A Day in Newari
        {
            "dialogue": [
                {"speaker": "A", "text": "ज्वजलपा! छि भिं?", "romanization": "jwajalapa! chhi bhiṃ?"},
                {"speaker": "B", "text": "___", "missing": True},
                {"speaker": "A", "text": "बांलाः! थौँ पौ ब्वनेगु।", "romanization": "bāṅlāḥ! thau pau bwanegu."},
            ],
            "options": [
                {"text": "भिं", "romanization": "bhiṃ", "correct": True},
                {"text": "मखु", "romanization": "makhu"},
                {"text": "छु", "romanization": "chhu"},
                {"text": "ला", "romanization": "lā"},
            ],
        },
        {
            "dialogue": [
                {"speaker": "A", "text": "लः बियेगु?", "romanization": "laḥ biyegu?"},
                {"speaker": "B", "text": "___", "missing": True},
            ],
            "options": [
                {"text": "खः, सुभाय्", "romanization": "khaḥ, subhāy", "correct": True},
                {"text": "मखु", "romanization": "makhu"},
                {"text": "ज्या", "romanization": "jyā"},
                {"text": "गन", "romanization": "gana"},
            ],
        },
    ],
}

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
    vocabulary_id: str | None = None


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
    illustration_id: str | None = None
    audio_key: str | None = None
    options: list[dict[str, Any]] | None = None
    answer_id: str | None = None
    pairs: dict[str, str] | None = None
    newari_script: str | None = None
    romanization: str | None = None
    correct_answer_config: dict[str, Any] | None = None
    word_tiles: list[dict[str, Any]] | None = None
    dialogue_structure: list[dict[str, Any]] | None = None
    vocabulary_reference: dict[str, Any] | None = None


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
        options.append({"id": d_id, "text": pair.newari_script, "is_devanagari": True, "romanization": pair.romanization})
        options.append({"id": e_id, "text": pair.english_meaning})
        pair_map[d_id] = e_id
    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="matchWords",
        instruction="Match the words", sequence=sequence,
        options=options, pairs=pair_map,
        correct_answer_config={"pairs": pair_map},
        vocabulary_reference={
            "entry_ids": [pair.vocabulary_id for pair in pairs if pair.vocabulary_id],
            "source_worksheet": "Vocabulary",
        },
    )


def _make_fillblank_exercise(ex_id: str, lesson_id: str, sequence: int,
                             answer: WordPair, distractors: list[WordPair]) -> GeneratedExercise | None:
    """Create a fillBlank exercise: show English hint, pick the Newari word."""
    if not distractors:
        return None
    options = [{"id": f"{ex_id}_a", "text": answer.newari_script, "is_devanagari": True, "romanization": answer.romanization}]
    for i, distractor in enumerate(distractors):
        options.append({"id": f"{ex_id}_d{i + 1}", "text": distractor.newari_script, "is_devanagari": True, "romanization": distractor.romanization})
    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="fillBlank",
        instruction="Fill in the blank",
        prompt=f"___ ({answer.english_meaning})", prompt_hint=answer.english_meaning,
        sequence=sequence, options=options, answer_id=f"{ex_id}_a",
        correct_answer_config={"correct_option_id": f"{ex_id}_a"},
        newari_script=answer.newari_script,
        romanization=answer.romanization,
        vocabulary_reference={
            "entry_ids": [pair.vocabulary_id for pair in [answer, *distractors]
                          if pair.vocabulary_id],
            "source_worksheet": "Vocabulary",
        },
    )


def _make_translate_exercise(ex_id: str, lesson_id: str, sequence: int,
                             target: WordPair,
                             distractors: list[WordPair]) -> GeneratedExercise | None:
    """Build a sourced Newari word answer from stable whole-word tiles."""
    choices = [target, *distractors]
    unique_script: set[str] = set()
    tiles: list[dict[str, Any]] = []
    target_tile_id = ""
    for i, pair in enumerate(choices, start=1):
        if pair.newari_script in unique_script:
            continue
        unique_script.add(pair.newari_script)
        tile_id = f"{ex_id}_t{i}"
        if pair is target:
            target_tile_id = tile_id
        tiles.append({
            "id": tile_id,
            "text": pair.newari_script,
            "is_devanagari": True,
            "romanization": pair.romanization,
        })
    if len(tiles) < 4 or not target_tile_id:
        return None

    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="translate",
        instruction="Choose the Newari word that matches the English meaning",
        prompt=target.english_meaning,
        sequence=sequence,
        word_tiles=tiles,
        newari_script=target.newari_script,
        romanization=target.romanization,
        correct_answer_config={
            "correct_sequence": [target_tile_id],
            "alternative_sequences": [],
        },
        vocabulary_reference={
            "entry_ids": [pair.vocabulary_id for pair in choices if pair.vocabulary_id],
            "source_worksheet": "Vocabulary",
        },
    )


def _vocabulary_reference(pairs: list[WordPair], **extra: Any) -> dict[str, Any]:
    return {
        "entry_ids": [pair.vocabulary_id for pair in pairs if pair.vocabulary_id],
        "source_worksheet": "Vocabulary",
        **extra,
    }


def _make_picture_to_word_exercise(
    ex_id: str, lesson_id: str, sequence: int, target: WordPair,
    choices: list[WordPair],
) -> GeneratedExercise:
    key = ILLUSTRATION_KEY_BY_ENGLISH[target.english_meaning]
    option_rows = [
        {
            "id": f"{ex_id}_o{index}", "text": pair.newari_script,
            "is_devanagari": True, "romanization": pair.romanization,
        }
        for index, pair in enumerate(choices, start=1)
    ]
    answer_id = next(
        f"{ex_id}_o{index}"
        for index, pair in enumerate(choices, start=1)
        if pair.vocabulary_id == target.vocabulary_id
    )
    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="pictureToWord",
        instruction="Choose the Newari word that matches the picture",
        prompt=target.english_meaning, sequence=sequence,
        image_key=key, illustration_id=key, options=option_rows,
        answer_id=answer_id,
        correct_answer_config={"correct_option_id": answer_id},
        vocabulary_reference=_vocabulary_reference(choices),
    )


def _make_word_to_picture_exercise(
    ex_id: str, lesson_id: str, sequence: int, target: WordPair,
    choices: list[WordPair],
) -> GeneratedExercise:
    options = []
    answer_id = ""
    for index, pair in enumerate(choices, start=1):
        key = ILLUSTRATION_KEY_BY_ENGLISH[pair.english_meaning]
        option_id = f"{ex_id}_o{index}"
        options.append({
            "id": option_id, "text": pair.newari_script,
            "is_devanagari": True, "romanization": pair.romanization,
            "image_key": key,
        })
        if pair.vocabulary_id == target.vocabulary_id:
            answer_id = option_id
    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="wordToPicture",
        instruction="Choose the picture that matches the Newari word",
        prompt=target.newari_script, sequence=sequence,
        romanization=target.romanization, options=options,
        answer_id=answer_id,
        correct_answer_config={"correct_option_id": answer_id},
        vocabulary_reference=_vocabulary_reference(choices),
    )


def _make_word_order_exercise(
    ex_id: str, lesson_id: str, sequence: int,
    phrase: tuple[str, list[str], list[str]],
    distractors: list[WordPair],
) -> GeneratedExercise:
    """Build a wordOrder exercise from a predefined phrase.

    The learner arranges scrambled Newari word tiles into the correct order
    to form a simple phrase.
    """
    english_prompt, correct_words, correct_romanizations = phrase
    tiles: list[dict[str, Any]] = []
    correct_tile_ids: list[str] = []

    for i, (word, rom) in enumerate(zip(correct_words, correct_romanizations), start=1):
        tile_id = f"{ex_id}_t{i}"
        correct_tile_ids.append(tile_id)
        tiles.append({
            "id": tile_id,
            "text": word,
            "is_devanagari": True,
            "romanization": rom,
        })

    # Add distractor tiles from vocabulary
    for j, pair in enumerate(distractors[:2], start=len(tiles) + 1):
        tile_id = f"{ex_id}_t{j}"
        if pair.newari_script not in [t["text"] for t in tiles]:
            tiles.append({
                "id": tile_id,
                "text": pair.newari_script,
                "is_devanagari": True,
                "romanization": pair.romanization,
            })

    if len(tiles) < 2:
        return None

    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="wordOrder",
        instruction="Arrange the words in the correct order",
        prompt=english_prompt, sequence=sequence,
        word_tiles=tiles,
        newari_script=" ".join(correct_words),
        romanization=" ".join(correct_romanizations),
        correct_answer_config={
            "correct_sequence": correct_tile_ids,
            "alternative_sequences": [],
        },
        vocabulary_reference={
            "entry_ids": [],
            "source_worksheet": "Vocabulary",
            "provisional": True,
        },
    )


def _make_dialogue_complete_exercise(
    ex_id: str, lesson_id: str, sequence: int,
    content: dict[str, Any],
) -> GeneratedExercise:
    """Build a dialogueComplete exercise from predefined dialogue content.

    The learner reads a 2-3 line dialogue with one missing response and
    selects the correct option to complete it.
    """
    dialogue = content["dialogue"]
    raw_options = content["options"]

    options: list[dict[str, Any]] = []
    answer_id = ""
    for i, opt in enumerate(raw_options, start=1):
        opt_id = f"{ex_id}_o{i}"
        options.append({
            "id": opt_id,
            "text": opt["text"],
            "is_devanagari": True,
            "romanization": opt.get("romanization", ""),
        })
        if opt.get("correct"):
            answer_id = opt_id

    if not answer_id:
        return None

    return GeneratedExercise(
        id=ex_id, lesson_id=lesson_id, exercise_type="dialogueComplete",
        instruction="Complete the dialogue",
        sequence=sequence,
        options=options,
        answer_id=answer_id,
        dialogue_structure=dialogue,
        correct_answer_config={"correct_option_id": answer_id},
        vocabulary_reference={
            "entry_ids": [],
            "source_worksheet": "Vocabulary",
            "provisional": True,
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
            vocabulary_id=row.id,
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

        # Exercise slots reuse only workbook entries assigned to this lesson.
        # Repeated practice is intentional; Newari phrases are never synthesized.
        distinct_words = []
        seen_scripts: set[str] = set()
        for pair in unique_available:
            if pair.newari_script not in seen_scripts:
                seen_scripts.add(pair.newari_script)
                distinct_words.append(pair)
        match_slot = 0
        fill_slot = 0
        translate_slot = 0
        picture_slot = 0
        image_choice_slot = 0
        word_order_slot = 0
        dialogue_slot = 0
        by_english = {pair.english_meaning: pair for pair in unique_available}
        illustrated_words = [
            pair for pair in unique_available
            if pair.english_meaning in ILLUSTRATION_KEY_BY_ENGLISH
        ]
        for slot_idx, ex_type in enumerate(exercise_types, start=1):
            if ex_type in ("pictureToWord", "wordToPicture"):
                if ex_type == "pictureToWord":
                    targets = PICTURE_TO_WORD_TARGETS.get(course_plan_lesson, [])
                    target_index = picture_slot
                    picture_slot += 1
                else:
                    targets = WORD_TO_PICTURE_TARGETS.get(course_plan_lesson, [])
                    target_index = image_choice_slot
                    image_choice_slot += 1
                target_name = targets[target_index] if target_index < len(targets) else None
                target = by_english.get(target_name) if target_name else None
                if target is None or len(illustrated_words) < 4:
                    raise ValueError(
                        f"Illustration catalog lacks four workbook choices for lesson "
                        f"{course_plan_lesson}, slot {slot_idx} ({target_name})"
                    )
                if ex_type == "pictureToWord":
                    choices = [target, *[
                        pair for pair in illustrated_words
                        if pair.vocabulary_id != target.vocabulary_id
                    ][:3]]
                    exercise = _make_picture_to_word_exercise(
                        _exercise_id(lesson_id, ex_type, slot_idx),
                        lesson_id, slot_idx, target, choices,
                    )
                else:
                    target_key = ILLUSTRATION_KEY_BY_ENGLISH[target.english_meaning]
                    choices = [target, *[
                        pair for pair in illustrated_words
                        if pair.vocabulary_id != target.vocabulary_id
                        and ILLUSTRATION_KEY_BY_ENGLISH[pair.english_meaning] != target_key
                    ][:3]]
                    exercise = _make_word_to_picture_exercise(
                        _exercise_id(lesson_id, ex_type, slot_idx),
                        lesson_id, slot_idx, target, choices,
                    )
                if len(choices) != 4:
                    raise ValueError(f"Expected four distinct image choices in {exercise.id}")
                exercises.append(exercise)
                continue

            if ex_type not in SUPPORTED_EXERCISE_TYPES:
                continue

            ex_id = _exercise_id(lesson_id, ex_type, slot_idx)

            if ex_type == "matchWords":
                if len(distinct_words) < 2:
                    continue
                start = (match_slot * 4) % len(distinct_words)
                pairs = [
                    distinct_words[(start + offset) % len(distinct_words)]
                    for offset in range(min(4, len(distinct_words)))
                ]
                match_slot += 1
                ex = _make_match_exercise(ex_id, lesson_id, slot_idx, pairs)
            elif ex_type == "fillBlank":
                if len(distinct_words) < 4:
                    continue
                answer = distinct_words[fill_slot % len(distinct_words)]
                distractors = [pair for pair in distinct_words if pair is not answer][:3]
                fill_slot += 1
                ex = _make_fillblank_exercise(ex_id, lesson_id, slot_idx, answer, distractors)
            elif ex_type == "translate":
                if len(distinct_words) < 4:
                    continue
                target = distinct_words[translate_slot % len(distinct_words)]
                distractors = [pair for pair in distinct_words if pair is not target][:3]
                translate_slot += 1
                ex = _make_translate_exercise(
                    ex_id, lesson_id, slot_idx, target, distractors
                )
            elif ex_type == "wordOrder":
                phrases = WORD_ORDER_PHRASES.get(course_plan_lesson, [])
                if word_order_slot < len(phrases):
                    phrase = phrases[word_order_slot]
                    word_order_slot += 1
                    ex = _make_word_order_exercise(
                        ex_id, lesson_id, slot_idx, phrase, distinct_words[:2],
                    )
                else:
                    continue
            elif ex_type == "dialogueComplete":
                dialogues = DIALOGUE_CONTENT.get(course_plan_lesson, [])
                if dialogue_slot < len(dialogues):
                    content = dialogues[dialogue_slot]
                    dialogue_slot += 1
                    ex = _make_dialogue_complete_exercise(
                        ex_id, lesson_id, slot_idx, content,
                    )
                else:
                    continue
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
            is_published=False,  # Provisional content; requires native-speaker verification before publication
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
        protect_existing_content = False
        if existing is None:
            db.add(Lesson(
                id=gl.lesson_id, unit_id=gl.unit_id, sequence=gl.sequence,
                title=gl.title, subtitle=gl.subtitle,
                exercise_type=gl.exercise_type, xp_reward=gl.xp_reward,
                word_count=gl.word_count, required_level=gl.required_level,
                is_published=gl.is_published, is_checkpoint=gl.is_checkpoint,
                passing_score=80 if gl.is_checkpoint else 100,
            ))
            lessons_created += 1
        else:
            has_verified_vocabulary = db.query(LessonVocabulary).join(
                VocabularyEntry,
                LessonVocabulary.vocabulary_entry_id == VocabularyEntry.id,
            ).filter(
                LessonVocabulary.lesson_id == gl.lesson_id,
                VocabularyEntry.is_verified.is_(True),
            ).first() is not None
            protect_existing_content = bool(
                existing.is_published
                or existing.vocabulary_verified
                or existing.sentence_verified
                or existing.dialogue_verified
                or existing.illustration_verified
                or has_verified_vocabulary
            )
            # Seed only synchronizes unverified blueprint shells. Published
            # or reviewed lesson content is protected from startup changes.
            if not protect_existing_content:
                existing.title = gl.title
                existing.subtitle = gl.subtitle
                existing.is_checkpoint = gl.is_checkpoint
                existing.passing_score = 80 if gl.is_checkpoint else 100
                existing.is_published = gl.is_published
                existing.exercise_type = gl.exercise_type
                existing.xp_reward = gl.xp_reward
                existing.word_count = gl.word_count
                existing.required_level = gl.required_level
            lessons_existed += 1

        # Create / sync exercises for this lesson.
        existing_ex_ids = {
            e.id for e in db.query(Exercise).filter(Exercise.lesson_id == gl.lesson_id).all()
        }
        for ex in gl.exercises:
            if ex.id in existing_ex_ids:
                current = db.get(Exercise, ex.id)
                if (not protect_existing_content and current is not None
                        and current.vocabulary_reference is None):
                    # Older generated rows have no provenance reference.
                    # Refresh only these unverified generated rows in place;
                    # ids and learner progress records remain stable.
                    current.instruction = ex.instruction
                    current.prompt = ex.prompt
                    current.prompt_hint = ex.prompt_hint
                    current.image_key = ex.image_key
                    current.illustration_id = ex.illustration_id
                    current.audio_key = ex.audio_key
                    current.sequence = ex.sequence
                    current.options = ex.options
                    current.answer_id = ex.answer_id
                    current.pairs = ex.pairs
                    current.newari_script = ex.newari_script
                    current.romanization = ex.romanization
                    current.correct_answer_config = ex.correct_answer_config
                    current.word_tiles = ex.word_tiles
                    current.dialogue_structure = ex.dialogue_structure
                    current.vocabulary_reference = ex.vocabulary_reference
                exercises_existed += 1
                continue
            db.add(Exercise(
                id=ex.id, lesson_id=ex.lesson_id,
                exercise_type=ex.exercise_type, instruction=ex.instruction,
                prompt=ex.prompt, prompt_hint=ex.prompt_hint,
                image_key=ex.image_key, illustration_id=ex.illustration_id,
                audio_key=ex.audio_key,
                sequence=ex.sequence, options=ex.options,
                answer_id=ex.answer_id, pairs=ex.pairs,
                newari_script=ex.newari_script,
                romanization=ex.romanization,
                correct_answer_config=ex.correct_answer_config,
                word_tiles=ex.word_tiles,
                dialogue_structure=ex.dialogue_structure,
                vocabulary_reference=ex.vocabulary_reference,
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


def get_curriculum_coverage_report(db: Session) -> dict[str, dict[str, int]]:
    """Report planned learner content separately from preserved legacy rows."""
    from app.models import Course

    blueprint_ids = {
        _lesson_id("en_new", unit_sequence, lesson_sequence)
        for unit_sequence in range(1, len(PLANNED_UNITS) + 1)
        for lesson_sequence in range(1, 4)
    }
    expected_exercise_ids = set()
    for course_plan_lesson, exercise_types in EXERCISE_SEQUENCES.items():
        unit_sequence = UNIT_SEQUENCE[LESSON_TO_UNIT[course_plan_lesson]]
        lesson_sequence = ((course_plan_lesson - 1) % 3) + 1
        lesson_id = _lesson_id("en_new", unit_sequence, lesson_sequence)
        for slot, exercise_type in enumerate(exercise_types, start=1):
            if exercise_type in SUPPORTED_EXERCISE_TYPES:
                expected_exercise_ids.add(_exercise_id(lesson_id, exercise_type, slot))
    lessons = list(db.query(Lesson).filter(Lesson.id.in_(blueprint_ids)).all())
    units = list(db.query(Unit).filter(
        Unit.course_id == "en_new",
        Unit.sequence.between(1, len(PLANNED_UNITS)),
    ).all())
    exercise_count = db.query(Exercise).filter(Exercise.id.in_(expected_exercise_ids)).count()
    vocab_count = db.query(VocabularyEntry).count()
    historical = {
        "retired_courses": db.query(Course).filter(Course.id != "en_new").count(),
        "units": db.query(Unit).filter(
            (Unit.course_id != "en_new") | (Unit.sequence > len(PLANNED_UNITS))
        ).count(),
        "lessons": db.query(Lesson).filter(~Lesson.id.in_(blueprint_ids)).count(),
        "exercises": db.query(Exercise).filter(~Exercise.id.in_(expected_exercise_ids)).count(),
    }
    return {
        "active_blueprint": {
            "planned_units": len(PLANNED_UNITS),
            "unit_rows_present": len(units),
            "planned_lessons": len(blueprint_ids),
            "lesson_rows_present": len(lessons),
            "checkpoints_including_capstone": len(CHECKPOINT_LESSONS),
            "planned_exercise_slots": sum(len(v) for v in EXERCISE_SEQUENCES.values()),
            "populated_exercise_slots": exercise_count,
            "missing_exercise_slots": max(0, sum(len(v) for v in EXERCISE_SEQUENCES.values()) - exercise_count),
            "published_lessons": sum(1 for lesson in lessons if lesson.is_published),
            "imported_vocabulary_entries": vocab_count,
        },
        "historical_records": historical,
    }
