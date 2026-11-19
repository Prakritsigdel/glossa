/// A unit grouping several lessons (e.g. "World 1: Home & Food").
class CourseUnit {
  final String id;
  final String title;
  final int totalLessons;
  final int clearedLessons;
  final List<Lesson> lessons;

  const CourseUnit({
    required this.id,
    required this.title,
    required this.totalLessons,
    required this.clearedLessons,
    required this.lessons,
  });
}

/// The status of a lesson on the town path.
enum LessonStatus { cleared, current, locked }

/// Type of exercise within a lesson.
enum ExerciseType { matchWords, fillBlank, pictureToWord, wordToPicture }

/// A single lesson card on the town path.
class Lesson {
  final String id;
  final String title;
  final String subtitle;
  final ExerciseType exerciseType;
  final LessonStatus status;
  final int xpReward;
  final int wordCount;
  final int requiredLevel;

  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.exerciseType,
    required this.status,
    this.xpReward = 20,
    this.wordCount = 4,
    this.requiredLevel = 1,
  });

  Lesson copyWith({LessonStatus? status}) {
    return Lesson(
      id: id,
      title: title,
      subtitle: subtitle,
      exerciseType: exerciseType,
      status: status ?? this.status,
      xpReward: xpReward,
      wordCount: wordCount,
      requiredLevel: requiredLevel,
    );
  }
}

/// A single exercise question within a lesson.
class Exercise {
  final String id;
  final ExerciseType type;
  final String instruction;
  final String? prompt;        // The word/sentence to match
  final String? promptHint;    // English hint text
  final String? imageKey;      // For picture exercises
  final List<AnswerOption> options;
  final String correctAnswerId;

  const Exercise({
    required this.id,
    required this.type,
    required this.instruction,
    this.prompt,
    this.promptHint,
    this.imageKey,
    required this.options,
    required this.correctAnswerId,
  });
}

/// An answer option in an exercise.
class AnswerOption {
  final String id;
  final String text;
  final String? imageKey;
  final bool isDevanagari;

  const AnswerOption({
    required this.id,
    required this.text,
    this.imageKey,
    this.isDevanagari = false,
  });
}

/// Tracks the result of a completed lesson attempt.
class LessonAttempt {
  final String lessonId;
  final int correctAnswers;
  final int totalQuestions;
  final int xpEarned;
  final List<String> wordsLearned;
  final int streakBonus;

  const LessonAttempt({
    required this.lessonId,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.xpEarned,
    required this.wordsLearned,
    this.streakBonus = 0,
  });

  double get accuracy => totalQuestions > 0
      ? correctAnswers / totalQuestions
      : 0.0;
}

/// XP summary after a lesson/session.
class XpSummary {
  final int totalXp;
  final int xpToNextLevel;
  final int currentLevel;

  const XpSummary({
    required this.totalXp,
    required this.xpToNextLevel,
    required this.currentLevel,
  });

  double get progress => xpToNextLevel > 0
      ? totalXp / xpToNextLevel
      : 0.0;
}
