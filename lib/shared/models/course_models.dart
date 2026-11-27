/// The status of a lesson on the town path.
enum LessonStatus { completed, available, locked, unavailable }

/// Type of exercise within a lesson.
enum ExerciseType {
  matchWords,
  fillBlank,
  pictureToWord,
  wordToPicture,
  translate,
  wordOrder,
  dialogueComplete,
}

/// A single lesson card on the town path.
class Lesson {
  final String id;
  final int? unitId;
  final int? sequence;
  final String? unitTitle;
  final String title;
  final String subtitle;
  final ExerciseType exerciseType;
  final LessonStatus status;
  final int xpReward;
  final int wordCount;
  final int requiredLevel;
  final bool isPublished;
  final bool isCheckpoint;
  final bool isCapstone;
  final String
  availability; // "unavailable", "locked", "available", "completed"
  final int plannedExerciseCount;
  final int populatedExerciseCount;

  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.exerciseType,
    required this.status,
    this.unitId,
    this.sequence,
    this.unitTitle,
    this.xpReward = 20,
    this.wordCount = 4,
    this.requiredLevel = 1,
    this.isPublished = true,
    this.isCheckpoint = false,
    this.isCapstone = false,
    this.availability = "locked",
    this.plannedExerciseCount = 0,
    this.populatedExerciseCount = 0,
  });

  Lesson copyWith({LessonStatus? status}) {
    return Lesson(
      id: id,
      unitId: unitId,
      sequence: sequence,
      unitTitle: unitTitle,
      title: title,
      subtitle: subtitle,
      exerciseType: exerciseType,
      status: status ?? this.status,
      xpReward: xpReward,
      wordCount: wordCount,
      requiredLevel: requiredLevel,
      isPublished: isPublished,
      isCheckpoint: isCheckpoint,
      isCapstone: isCapstone,
      availability: availability,
      plannedExerciseCount: plannedExerciseCount,
      populatedExerciseCount: populatedExerciseCount,
    );
  }
}

/// A single exercise question within a lesson.
///
/// All correct-answer configuration (pairs, answer_id, correct_answer_config)
/// is intentionally NOT exposed in the public model — correctness is
/// determined server-side via /api/v1/lessons/{id}/answer and
/// /api/v1/lessons/{id}/attempts.
class Exercise {
  final String id;
  final ExerciseType type;
  final String instruction;
  final int xp;
  final String? prompt;
  final String? promptHint;
  final String? imageKey;
  final String? audioKey;
  final List<AnswerOption> options;

  // ── Newari typography fields ──
  /// Devanagari script text (for word/prompt display).
  final String? newariScript;

  /// Romanization / pronunciation guide for [newariScript].
  final String? romanization;

  // ── Word tiles (translate / wordOrder) ──
  /// Selectable word tiles with stable IDs.
  final List<AnswerOption> wordTiles;

  // ── Dialogue structure (dialogueComplete) ──
  /// Ordered dialogue lines, one flagged as missing.
  final List<Map<String, dynamic>>? dialogueStructure;

  // ── Illustration reference (pictureToWord / wordToPicture) ──
  final String? illustrationId;

  // ── Vocabulary reference ──
  final Map<String, dynamic>? vocabularyReference;
  final Map<String, dynamic>? layout;
  final String? variant;
  final String? plannedType;
  final String? phraseTargetEn;

  const Exercise({
    required this.id,
    required this.type,
    required this.instruction,
    this.xp = 0,
    this.prompt,
    this.promptHint,
    this.imageKey,
    this.audioKey,
    required this.options,
    this.newariScript,
    this.romanization,
    this.wordTiles = const [],
    this.dialogueStructure,
    this.illustrationId,
    this.vocabularyReference,
    this.layout,
    this.variant,
    this.plannedType,
    this.phraseTargetEn,
  });

  /// Returns true if this exercise uses illustrations (pictureToWord / wordToPicture).
  bool get usesIllustration =>
      type == ExerciseType.pictureToWord || type == ExerciseType.wordToPicture;

  /// Returns true if this exercise is a matching exercise (matchWords).
  bool get isMatchWords => type == ExerciseType.matchWords;

  /// Returns true if this exercise is fillBlank.
  bool get isFillBlank => type == ExerciseType.fillBlank;
}

/// An answer option in an exercise.
///
/// For word tiles (translate/wordOrder), [text] holds the Devanagari
/// character or word fragment, [isDevanagari] is true, and [id] is the
/// stable tile instance identifier (repeated words use distinct tile IDs).
///
/// [romanization] is the source-provided pronunciation guide for Devanagari
/// text. It is displayed beneath the Newari script where applicable.
class AnswerOption {
  final String id;
  final String text;
  final String? imageKey;
  final bool isDevanagari;
  final String? romanization;

  const AnswerOption({
    required this.id,
    required this.text,
    this.imageKey,
    this.isDevanagari = false,
    this.romanization,
  });
}
