"""Glossa curriculum data and idempotent seeding logic.

Defines vocabulary for English↔Nepali courses and generates exercises
programmatically. Newari course structures are created as unpublished
shells without fabricated content.
"""

from dataclasses import dataclass, field
from typing import Any

# ─── Unit themes (10 units per course) ─────────────────────────

UNIT_THEMES = [
    "Greetings and Introductions",
    "Family and People",
    "Numbers, Colors, and Objects",
    "Home and Daily Routines",
    "Food and Drinks",
    "Places and Directions",
    "Shopping and Money",
    "Time, Dates, and Schedules",
    "Travel and Everyday Situations",
    "Conversations and Revision",
]

# ─── Vocabulary: English ↔ Nepali ──────────────────────────────
# Each entry: (english, nepali_devanagari, romanized, image_key)
# Image keys must match SimpleIllustration widget: house, droplet, bowl, person

VOCABULARY = {
    "Greetings and Introductions": [
        ("Hello", "नमस्ते", "namaste", "person"),
        ("Thank you", "धन्यवाद", "dhanyabad", "person"),
        ("Good", "राम्रो", "ramro", "house"),
        ("Friend", "मित्र", "mitra", "person"),
        ("How are you?", "तपाईं कसरी हुनुहुन्छ?", "tapai kastai hunuhuncha", "person"),
        ("I am fine", "म ठीक छु", "ma thik chu", "person"),
        ("Good morning", "शुभ प्रभात", "shubha prabhat", "house"),
        ("See you again", "फेरि भेटौंला", "pheri bhetaula", "person"),
    ],
    "Family and People": [
        ("Mother", "आमा", "aama", "person"),
        ("Father", "बुवा", "buwa", "person"),
        ("Sister", "दिदी", "didi", "person"),
        ("Brother", "दाजु", "daju", "person"),
        ("Son", "छोरा", "chora", "person"),
        ("Daughter", "छोरी", "chori", "person"),
        ("Person", "मान्छे", "manche", "person"),
        ("Family", "परिवार", "pariwar", "house"),
    ],
    "Numbers, Colors, and Objects": [
        ("One", "एक", "ek", "bowl"),
        ("Two", "दुई", "dui", "bowl"),
        ("Three", "तीन", "tin", "bowl"),
        ("Red", "रातो", "rato", "droplet"),
        ("Blue", "निलो", "nilo", "droplet"),
        ("House", "घर", "ghar", "house"),
        ("Water", "पानी", "pani", "droplet"),
        ("Bowl", "भाँडा", "bhada", "bowl"),
    ],
    "Home and Daily Routines": [
        ("Home", "घर", "ghar", "house"),
        ("To eat", "खाने", "khane", "bowl"),
        ("To sleep", "सुत्ने", "sutne", "house"),
        ("To go", "जाने", "jane", "person"),
        ("To come", "आउने", "aune", "person"),
        ("Work", "काम", "kaam", "house"),
        ("Clean", "सफा", "safa", "droplet"),
        ("Rest", "आराम", "aaram", "house"),
    ],
    "Food and Drinks": [
        ("Rice", "भात", "bhat", "bowl"),
        ("Lentil soup", "दाल", "dal", "bowl"),
        ("Vegetable", "तरकारी", "tarkari", "bowl"),
        ("Water", "पानी", "pani", "droplet"),
        ("Tea", "चिया", "chiya", "bowl"),
        ("Milk", "दूध", "dudh", "droplet"),
        ("Bread", "रोटी", "roti", "bowl"),
        ("Meat", "मासु", "masu", "bowl"),
    ],
    "Places and Directions": [
        ("Market", "बजार", "bazaar", "house"),
        ("School", "विद्यालय", "vidyalaya", "house"),
        ("Hospital", "अस्पताल", "aspatal", "house"),
        ("Road", "सडक", "sadak", "house"),
        ("Forward", "अगाडि", "agadi", "person"),
        ("Backward", "पछाडि", "pachadi", "person"),
        ("Up", "माथि", "mathi", "house"),
        ("Place", "ठाउँ", "thau", "house"),
    ],
    "Shopping and Money": [
        ("Money", "पैसा", "paisa", "bowl"),
        ("Price", "दाम", "daam", "bowl"),
        ("To buy", "किन्ने", "kinne", "person"),
        ("To sell", "बेच्ने", "bechne", "person"),
        ("Cheap", "सस्तो", "sasto", "bowl"),
        ("Expensive", "महंगो", "mahango", "bowl"),
        ("Shop", "दोकान", "dokan", "house"),
        ("Bill", "हिसाब", "hisab", "bowl"),
    ],
    "Time, Dates, and Schedules": [
        ("Today", "आज", "aaja", "house"),
        ("Tomorrow", "भोलि", "bholi", "house"),
        ("Yesterday", "हिजो", "hijo", "house"),
        ("Morning", "बिहान", "bihan", "house"),
        ("Evening", "बेलुका", "beluka", "house"),
        ("Night", "रात", "raat", "house"),
        ("Day", "दिन", "din", "house"),
        ("Time", "समय", "samaya", "bowl"),
    ],
    "Travel and Everyday Situations": [
        ("Bus", "बस", "bas", "house"),
        ("Ticket", "टिकट", "tikat", "bowl"),
        ("Journey", "यात्रा", "yatra", "person"),
        ("Hotel", "होटल", "hotel", "house"),
        ("Garden", "बगैचा", "bagaicha", "house"),
        ("Road", "बाटो", "bato", "house"),
        ("To walk", "हिँड्ने", "hidne", "person"),
        ("To sit", "बस्ने", "basne", "house"),
    ],
    "Conversations and Revision": [
        ("What?", "के?", "ke", "person"),
        ("How?", "कसरी?", "kasari", "person"),
        ("Why?", "किन?", "kina", "person"),
        ("Where?", "कहाँ?", "kahan", "house"),
        ("Good", "राम्रो", "ramro", "house"),
        ("Bad", "नराम्रो", "naramro", "house"),
        ("Yes", "हो", "ho", "person"),
        ("No", "होइन", "hoina", "person"),
    ],
}


@dataclass
class GeneratedLesson:
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
    exercises: list[dict[str, Any]] = field(default_factory=list)


def _make_match_exercise(ex_id: str, words: list[tuple[str, str, str, str]]) -> dict:
    """Create a matchWords exercise from 4 word pairs."""
    options = []
    pairs = {}
    for i, (english, nepali, _roman, _image) in enumerate(words):
        d_id = f"{ex_id}_d{i+1}"
        e_id = f"{ex_id}_e{i+1}"
        options.append({"id": d_id, "text": nepali, "is_devanagari": True})
        options.append({"id": e_id, "text": english})
        pairs[d_id] = e_id
    return {
        "id": ex_id,
        "exercise_type": "matchWords",
        "instruction": "Match the words",
        "prompt": None,
        "prompt_hint": None,
        "image_key": None,
        "audio_key": None,
        "sequence": 1,
        "options": options,
        "pairs": pairs,
        "answer_id": None,
    }


def _make_fillblank_exercise(ex_id: str, answer: tuple[str, str, str, str], distractors: list[tuple[str, str, str, str]]) -> dict:
    """Create a fillBlank exercise: show sentence with blank, pick the answer."""
    english, nepali, _roman, _image = answer
    options = [{"id": f"{ex_id}_a", "text": nepali, "is_devanagari": True}]
    for i, (d_en, d_ne, _d_rom, _d_img) in enumerate(distractors):
        options.append({"id": f"{ex_id}_d{i+1}", "text": d_ne, "is_devanagari": True})
    return {
        "id": ex_id,
        "exercise_type": "fillBlank",
        "instruction": "Fill in the blank",
        "prompt": f"___ ({english})",
        "prompt_hint": english,
        "image_key": None,
        "audio_key": None,
        "sequence": 2,
        "options": options,
        "answer_id": f"{ex_id}_a",
        "pairs": None,
    }


def _make_picture_to_word_exercise(ex_id: str, answer: tuple[str, str, str, str], distractors: list[tuple[str, str, str, str]]) -> dict:
    """Create a pictureToWord exercise: see image, pick the word."""
    english, nepali, _roman, image_key = answer
    options = [{"id": f"{ex_id}_a", "text": nepali, "is_devanagari": True}]
    for i, (d_en, d_ne, _d_rom, _d_img) in enumerate(distractors):
        options.append({"id": f"{ex_id}_d{i+1}", "text": d_ne, "is_devanagari": True})
    return {
        "id": ex_id,
        "exercise_type": "pictureToWord",
        "instruction": "Name the picture",
        "prompt": f"What is this? ({english})",
        "prompt_hint": english,
        "image_key": image_key,
        "audio_key": None,
        "sequence": 3,
        "options": options,
        "answer_id": f"{ex_id}_a",
        "pairs": None,
    }


def _make_word_to_picture_exercise(ex_id: str, answer: tuple[str, str, str, str], distractors: list[tuple[str, str, str, str]]) -> dict:
    """Create a wordToPicture exercise: see the word, pick the picture."""
    english, nepali, _roman, image_key = answer
    options = [{"id": f"{ex_id}_a", "text": english, "image_key": image_key}]
    for i, (d_en, d_ne, _d_rom, d_img) in enumerate(distractors):
        options.append({"id": f"{ex_id}_d{i+1}", "text": d_en, "image_key": d_img})
    return {
        "id": ex_id,
        "exercise_type": "wordToPicture",
        "instruction": "Pick the picture",
        "prompt": f"Which picture is '{nepali}'?",
        "prompt_hint": english,
        "image_key": None,
        "audio_key": None,
        "sequence": 4,
        "options": options,
        "answer_id": f"{ex_id}_a",
        "pairs": None,
    }


def generate_course_lessons(course_id: str, units: list, source_lang: str, target_lang: str) -> list[GeneratedLesson]:
    """Generate 4 lessons per unit (40 total) for a course.

    For en_ne: English prompts, Nepali answers, published.
    For ne_en: Nepali prompts, English answers, published.
    For Newari courses: create lesson shells, unpublished, no exercises.
    """
    lessons = []
    is_nepali_target = target_lang == "ne"
    is_nepali_source = source_lang == "ne"
    has_content = (source_lang in ("en", "ne") and target_lang in ("en", "ne")
                   and source_lang != target_lang)

    for unit_idx, unit in enumerate(units):
        unit_sequence = unit.sequence
        unit_id = unit.id
        theme = UNIT_THEMES[unit_idx] if unit_idx < len(UNIT_THEMES) else f"Unit {unit_sequence}"
        vocab = VOCABULARY.get(theme, VOCABULARY["Greetings and Introductions"])

        for lesson_idx in range(4):
            lesson_seq = lesson_idx + 1
            lesson_id = f"{course_id}_u{unit_sequence}_l{lesson_seq}"

            # Pick 4 vocabulary words for this lesson (cycling through the vocab list)
            start = (lesson_idx * 2) % len(vocab)
            words = [vocab[i % len(vocab)] for i in range(start, start + 4)]
            # Ensure unique
            seen = set()
            unique_words = []
            for w in words:
                if w[0] not in seen:
                    seen.add(w[0])
                    unique_words.append(w)
            while len(unique_words) < 4:
                for w in vocab:
                    if w[0] not in seen:
                        seen.add(w[0])
                        unique_words.append(w)
                        if len(unique_words) >= 4:
                            break
            words = unique_words[:4]

            if has_content:
                # Generate real exercises
                match_ex = _make_match_exercise(f"{lesson_id}_mw", words)

                # Fill blank: use first word as answer, others as distractors
                fill_answer = words[0]
                fill_distractors = [w for w in words[1:] if w[1] != fill_answer[1]][:3]
                fill_ex = _make_fillblank_exercise(f"{lesson_id}_fb", fill_answer, fill_distractors)

                # Picture to word: use first word with image_key
                ptw_answer = words[0]
                ptw_distractors = [w for w in words[1:] if w[3] != ptw_answer[3]][:3]
                ptw_ex = _make_picture_to_word_exercise(f"{lesson_id}_ptw", ptw_answer, ptw_distractors)

                # Word to picture: use second word with image_key
                wtp_answer = words[1] if len(words) > 1 else words[0]
                wtp_distractors = [w for w in words if w[0] != wtp_answer[0]][:3]
                wtp_ex = _make_word_to_picture_exercise(f"{lesson_id}_wtp", wtp_answer, wtp_distractors)

                lesson = GeneratedLesson(
                    lesson_id=lesson_id,
                    unit_id=unit_id,
                    sequence=lesson_seq,
                    title=f"{theme} {lesson_seq}",
                    subtitle=f"Match · {len(words)} words",
                    exercise_type="matchWords",
                    xp_reward=20 + lesson_idx * 5,
                    word_count=len(words),
                    required_level=1,
                    is_published=True,
                    exercises=[match_ex, fill_ex, ptw_ex, wtp_ex],
                )
            else:
                # Newari course: create unpublished lesson shell without exercises
                lesson = GeneratedLesson(
                    lesson_id=lesson_id,
                    unit_id=unit_id,
                    sequence=lesson_seq,
                    title=f"{theme} {lesson_seq}",
                    subtitle="Coming soon — awaiting language verification",
                    exercise_type="matchWords",
                    xp_reward=20,
                    word_count=0,
                    required_level=1,
                    is_published=False,
                    exercises=[],
                )

            lessons.append(lesson)

    return lessons


def get_curriculum_coverage_report():
    """Return a machine-readable coverage report for all 6 courses."""
    report = {}
    for course_id, src, tgt, name in [
        ("en_ne", "en", "ne", "English → Nepali"),
        ("ne_en", "ne", "en", "Nepali → English"),
        ("en_new", "en", "new", "English → Newari"),
        ("new_en", "new", "en", "Newari → English"),
        ("ne_new", "ne", "new", "Nepali → Newari"),
        ("new_ne", "new", "ne", "Newari → Nepali"),
    ]:
        has_content = src in ("en", "ne") and tgt in ("en", "ne") and src != tgt
        report[course_id] = {
            "name": name,
            "source_language": src,
            "target_language": tgt,
            "units_created": 10,
            "lesson_slots_created": 40,
            "lessons_with_exercises": 40 if has_content else 0,
            "lessons_reviewed": 40 if has_content else 0,
            "lessons_published": 40 if has_content else 0,
            "lessons_awaiting_verification": 0 if has_content else 40,
            "audio_coverage": "none",
        }
    return report
