# Glossa: Newari Course Plan (Pilot, 15 Lessons)

A pilot slice of the 10-unit course structure. It uses the first five themes from `UNIT_THEMES`, with 3 lessons per unit. The remaining five units can follow the same pattern later.

**Scope rules**
- No voice or audio lessons. `audio_key` stays `null` on every exercise and `audio_coverage` stays `"none"`.
- No fabricated Newari content. Every lesson stays `is_published = False` until a native speaker has verified it.

---

## 1. Learning Curve

Each unit follows one rhythm: **Introduce, Expand, Consolidate**. Difficulty ramps from recognition to recall to production.

| Phase | Lessons | Skill focus | Exercises per lesson |
|---|---|---|---|
| 1. Recognition | 1-3 | See a word, pick the meaning | 5-7 |
| 2. Association | 4-6 | Link words to people, pictures and context | 6-8 |
| 3. Recall | 7-9 | Produce the word with fewer hints | 6-8 |
| 4. Use in context | 10-12 | Short phrases and simple sentences | 7-9 |
| 5. Integration | 13-15 | Mixed review plus conversation | 8-10 |

**Rules that hold throughout**
- 4-6 new words per lesson, about 70% new and 30% review. Checkpoints are mostly review.
- Exercises within a lesson go from easy to hard: matching and picture recognition first, then fill-in-the-blank and production.
- Lesson 3 of every unit is a **checkpoint**. It mixes the whole unit, and an 80% pass could gate the next unit.
- Each lesson has between 5 and 10 exercises.

---

## 2. Exercise Types (all text-only)

| Type | Status | Description |
|---|---|---|
| `matchWords` | Existing | Match Devanagari words to English |
| `fillBlank` | Existing | Pick the word that completes the prompt |
| `pictureToWord` | Existing | See an image, pick the word |
| `wordToPicture` | Existing | See a word, pick the image |
| `translate` | New | Build the Newari answer from word tiles |
| `wordOrder` | New | Arrange scrambled words into a sentence |
| `dialogueComplete` | New | Fill the missing line of a 2-3 line exchange |

Because there is no audio, **show the romanization under every Devanagari word** as a pronunciation guide.

---

## 3. Lesson Map

| # | Unit | Lesson | New content | Exercises | Exercise sequence |
|---|---|---|---|---|---|
| 1 | Greetings | First Words | Hello, thank you, goodbye, yes/no | 5 | matchWords → fillBlank → matchWords → fillBlank → pictureToWord |
| 2 | Greetings | Meeting Someone | How are you, I am fine, name, friend | 6 | matchWords → fillBlank → fillBlank → pictureToWord → matchWords → fillBlank |
| 3 | Greetings | **Checkpoint: Greetings** | Review only | 7 | matchWords → fillBlank ×3 → translate ×2 → dialogueComplete |
| 4 | Family | Close Family | Mother, father, sister, brother | 6 | matchWords → pictureToWord ×2 → wordToPicture ×2 → fillBlank |
| 5 | Family | More People | Son, daughter, family, person | 7 | matchWords → wordToPicture ×2 → pictureToWord → fillBlank ×2 → matchWords |
| 6 | Family | **Checkpoint: Family** | Review plus "this is my..." | 8 | matchWords → pictureToWord → wordToPicture → fillBlank ×2 → translate ×2 → wordOrder |
| 7 | Numbers & Colors | Numbers 1-5 | Counting words | 6 | matchWords ×2 → pictureToWord ×2 → fillBlank ×2 |
| 8 | Numbers & Colors | Colors and Objects | 3-4 colors, 2-3 objects | 7 | matchWords → pictureToWord ×2 → wordToPicture ×2 → fillBlank ×2 |
| 9 | Numbers & Colors | **Checkpoint: Counting Things** | Numbers 6-10, "two red bowls" | 8 | matchWords → fillBlank ×3 → translate ×2 → wordOrder ×2 |
| 10 | Food & Drinks | Basic Foods | Rice, water, tea, milk, etc. | 7 | matchWords → pictureToWord ×2 → wordToPicture ×2 → fillBlank ×2 |
| 11 | Food & Drinks | Eating and Drinking | Verbs: eat, drink, want | 8 | matchWords → fillBlank ×3 → wordOrder ×2 → translate ×2 |
| 12 | Food & Drinks | **Checkpoint: At the Table** | Offering, asking, polite phrases | 9 | matchWords → fillBlank ×2 → translate ×2 → wordOrder ×2 → dialogueComplete ×2 |
| 13 | Home & Routines | Home and Places | Home, work, rest, clean | 8 | matchWords → pictureToWord ×2 → wordToPicture → fillBlank ×3 → translate |
| 14 | Home & Routines | Daily Actions | Go, come, sleep, work | 9 | matchWords → fillBlank ×3 → wordOrder ×2 → translate ×2 → dialogueComplete |
| 15 | Home & Routines | **Capstone: A Day in Newari** | Everything so far | 10 | matchWords → fillBlank ×2 → pictureToWord → translate ×2 → wordOrder ×2 → dialogueComplete ×2 |

**Notes**
- Illustration keys are limited to `house`, `droplet`, `bowl` and `person`, so the Greetings lessons lean on `matchWords` and `fillBlank`.
- Exercise counts per lesson: 5, 6, 7, 6, 7, 8, 6, 7, 8, 7, 8, 9, 8, 9, 10. This gives 115 exercises in total.

---

## 4. Course Directions

- **English → Newari (`en_new`)** is the primary course and uses this plan.
- **Nepali → Newari (`ne_new`)** can reuse the same blueprint. Some vocabulary and grammar will feel familiar to Nepali speakers, so it could be compressed or have tighter review.
- **Newari → English (`new_en`) and Newari → Nepali (`new_ne`)** are best built later, once there are Newari-speaking learners.

---

## 5. Decisions Needed Before Adding Data

- **Script:** Newari is written in Devanagari today, and also in Ranjana and Prachalit. Pick one for the first release. Devanagari matches the existing `is_devanagari` flag.
- **Dialect:** Kathmandu Valley Newari varies by area (Kathmandu, Patan, Bhaktapur and others). Choose one standard and label it in the course.
- **Verification:** Without audio, a wrong romanization has nothing to correct it. A native-speaker review of vocabulary and romanization is essential before publishing. The `lessons_awaiting_verification` field already supports this.
- **Cultural content:** Food and family lessons are good places for Newar culture and festivals, but only once a speaker can confirm terms and usage.

---

## 6. Code Changes Required

- Replace the hardcoded 4-exercise generator (`match`, `fill`, `ptw`, `wtp`) with a **per-lesson blueprint**: a list of exercise types plus the vocabulary slice each lesson uses.
- Replace the `4 lessons × 10 units` loop and the coverage report's `40` constants with values derived from the blueprint (15 lessons for this pilot).
- Add an `is_checkpoint` flag to lessons for unlock gating and special styling.
- Add builders for `translate`, `wordOrder` and `dialogueComplete`.
- Keep `is_published = False` for all Newari lessons until verified.

**Suggested next step:** write the blueprint structure itself, with lesson IDs, exercise-type sequences and empty vocabulary slots, so data can be filled in once a verified word list exists.
