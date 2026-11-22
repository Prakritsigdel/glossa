/// Language model for the multi-language course architecture.
class Language {
  final String id;
  final String nameEnglish;
  final String nameNative;
  final String script;
  final bool isActive;

  const Language({
    required this.id,
    required this.nameEnglish,
    required this.nameNative,
    required this.script,
    required this.isActive,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'] as String,
      nameEnglish: json['name_english'] as String,
      nameNative: json['name_native'] as String,
      script: json['script'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}

/// Course model representing a learning direction (e.g. English → Nepali).
class Course {
  final String id;
  final String sourceLanguageId;
  final String targetLanguageId;
  final String name;
  final String? description;
  final bool isPublished;
  final Language sourceLanguage;
  final Language targetLanguage;

  const Course({
    required this.id,
    required this.sourceLanguageId,
    required this.targetLanguageId,
    required this.name,
    this.description,
    required this.isPublished,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      sourceLanguageId: json['source_language_id'] as String,
      targetLanguageId: json['target_language_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublished: json['is_published'] as bool,
      sourceLanguage: Language.fromJson(
        json['source_language'] as Map<String, dynamic>,
      ),
      targetLanguage: Language.fromJson(
        json['target_language'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Unit model representing a themed grouping of lessons within a course.
class CourseUnit {
  final int id;
  final String courseId;
  final int sequence;
  final String title;
  final String? description;
  final int totalLessons;
  final int clearedLessons;
  final List<Lesson> lessons;

  const CourseUnit({
    required this.id,
    required this.courseId,
    required this.sequence,
    required this.title,
    this.description,
    required this.totalLessons,
    required this.clearedLessons,
    required this.lessons,
  });

  factory CourseUnit.fromJson(Map<String, dynamic> json) {
    return CourseUnit(
      id: (json['id'] as num).toInt(),
      courseId: json['course_id'] as String,
      sequence: (json['sequence'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      totalLessons: (json['total_lessons'] as num).toInt(),
      clearedLessons: (json['cleared_lessons'] as num).toInt(),
      lessons: const [],
    );
  }

  double get progress =>
      totalLessons > 0 ? clearedLessons / totalLessons : 0.0;
}

/// The status of a lesson on the town path.
enum LessonStatus { cleared, current, locked }

/// Type of exercise within a lesson.
enum ExerciseType { matchWords, fillBlank, pictureToWord, wordToPicture }

/// A single lesson card on the town path.
class Lesson {
  final String id;
  final int? unitId;
  final int? sequence;
  final String title;
  final String subtitle;
  final ExerciseType exerciseType;
  final LessonStatus status;
  final int xpReward;
  final int wordCount;
  final int requiredLevel;
  final bool isPublished;

  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.exerciseType,
    required this.status,
    this.unitId,
    this.sequence,
    this.xpReward = 20,
    this.wordCount = 4,
    this.requiredLevel = 1,
    this.isPublished = true,
  });

  Lesson copyWith({LessonStatus? status}) {
    return Lesson(
      id: id,
      unitId: unitId,
      sequence: sequence,
      title: title,
      subtitle: subtitle,
      exerciseType: exerciseType,
      status: status ?? this.status,
      xpReward: xpReward,
      wordCount: wordCount,
      requiredLevel: requiredLevel,
      isPublished: isPublished,
    );
  }
}

/// A single exercise question within a lesson.
class Exercise {
  final String id;
  final ExerciseType type;
  final String instruction;
  final String? prompt;
  final String? promptHint;
  final String? imageKey;
  final String? audioKey;
  final List<AnswerOption> options;
  final String correctAnswerId;
  final Map<String, String>? pairs;

  const Exercise({
    required this.id,
    required this.type,
    required this.instruction,
    this.prompt,
    this.promptHint,
    this.imageKey,
    this.audioKey,
    required this.options,
    required this.correctAnswerId,
    this.pairs,
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

  double get accuracy =>
      totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;
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

  double get progress =>
      xpToNextLevel > 0 ? totalXp / xpToNextLevel : 0.0;
}
