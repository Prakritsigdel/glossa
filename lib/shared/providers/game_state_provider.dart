import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/demo_user.dart';
import '../models/course_models.dart';
import '../repositories/backend_api.dart';

class GameState {
  final DemoUser user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final List<Lesson> lessons;
  final List<Exercise> exercises;
  final String? activeLessonId;
  final int currentExerciseIndex;
  final int correctAnswersInLesson;
  final bool lessonComplete;
  final Set<String> matchedPairIds;
  final Map<String, Map<String, dynamic>> answers;
  final int lastXpEarned;
  final int lastCorrectAnswers;
  final int lastTotalQuestions;
  final bool lastAlreadyCompleted;
  final double lastScore;
  final int lastPassingThreshold;
  final bool lastPassed;

  const GameState({
    required this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.lessons = const [],
    this.exercises = const [],
    this.activeLessonId,
    this.currentExerciseIndex = 0,
    this.correctAnswersInLesson = 0,
    this.lessonComplete = false,
    this.matchedPairIds = const {},
    this.answers = const {},
    this.lastXpEarned = 0,
    this.lastCorrectAnswers = 0,
    this.lastTotalQuestions = 0,
    this.lastAlreadyCompleted = false,
    this.lastScore = 0,
    this.lastPassingThreshold = 100,
    this.lastPassed = false,
  });

  GameState copyWith({
    DemoUser? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<Lesson>? lessons,
    List<Exercise>? exercises,
    String? activeLessonId,
    bool clearActiveLesson = false,
    int? currentExerciseIndex,
    int? correctAnswersInLesson,
    bool? lessonComplete,
    Set<String>? matchedPairIds,
    Map<String, Map<String, dynamic>>? answers,
    int? lastXpEarned,
    int? lastCorrectAnswers,
    int? lastTotalQuestions,
    bool? lastAlreadyCompleted,
    double? lastScore,
    int? lastPassingThreshold,
    bool? lastPassed,
  }) => GameState(
    user: user ?? this.user,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    lessons: lessons ?? this.lessons,
    exercises: exercises ?? this.exercises,
    activeLessonId: clearActiveLesson
        ? null
        : (activeLessonId ?? this.activeLessonId),
    currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
    correctAnswersInLesson:
        correctAnswersInLesson ?? this.correctAnswersInLesson,
    lessonComplete: lessonComplete ?? this.lessonComplete,
    matchedPairIds: matchedPairIds ?? this.matchedPairIds,
    answers: answers ?? this.answers,
    lastXpEarned: lastXpEarned ?? this.lastXpEarned,
    lastCorrectAnswers: lastCorrectAnswers ?? this.lastCorrectAnswers,
    lastTotalQuestions: lastTotalQuestions ?? this.lastTotalQuestions,
    lastAlreadyCompleted: lastAlreadyCompleted ?? this.lastAlreadyCompleted,
    lastScore: lastScore ?? this.lastScore,
    lastPassingThreshold: lastPassingThreshold ?? this.lastPassingThreshold,
    lastPassed: lastPassed ?? this.lastPassed,
  );
}

class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier(this.api) : super(const GameState(user: guestUser)) {
    restoreSession();
  }

  final BackendApi api;

  Future<void> restoreSession() async {
    try {
      final token = await api.token;
      if (token == null) return;
      if (mounted) state = state.copyWith(isLoading: true, clearError: true);
      final user = await api.me();
      await _loadAuthenticatedState(user);
    } catch (_) {
      try {
        await api.logout();
      } catch (_) {}
      if (mounted) {
        state = const GameState(user: guestUser);
      }
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _authenticate(
      () => api.register(name: name, email: email, password: password),
    );
  }

  Future<void> logIn({required String email, required String password}) async {
    await _authenticate(() => api.login(email: email, password: password));
  }

  Future<void> _authenticate(Future<DemoUser> Function() action) async {
    state = const GameState(user: guestUser, isLoading: true);
    try {
      final user = await action();
      await _loadAuthenticatedState(user);
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      }
      rethrow;
    }
  }

  /// Load courses, languages, units, and lessons after authentication.
  Future<void> _loadAuthenticatedState(DemoUser user) async {
    try {
      if (user.activeCourseId != 'en_new') {
        await api.updateActiveCourse('en_new');
        user = await api.me();
      }
      final lessons = user.activeCourseId == 'en_new'
          ? await api.lessons(courseId: 'en_new')
          : <Lesson>[];
      if (mounted) {
        state = GameState(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          lessons: lessons,
        );
      }
    } catch (error) {
      // Even if courses fail to load, still set authenticated state.
      if (mounted) {
        state = GameState(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          errorMessage: error.toString(),
        );
      }
    }
  }

  Future<void> logOut() async {
    try {
      await api.logout();
    } catch (_) {}
    if (mounted) {
      state = const GameState(user: guestUser);
    }
  }

  Future<void> selectHero(int index, String name) async {
    state = state.copyWith(
      user: state.user.copyWith(heroIndex: index, name: name),
    );
    try {
      final user = await api.updateProfile(heroIndex: index, name: name);
      if (mounted) state = state.copyWith(user: user);
    } catch (_) {}
  }

  // ─── Single course (English -> Newari) ─────────────────────────
  /// Glossa is English->Newari only. en_new is assigned automatically;
  /// there is no language or course selection for the user.
  bool canStartLesson(String lessonId) => state.lessons.any(
    (l) =>
        l.id == lessonId &&
        l.status != LessonStatus.locked &&
        l.status != LessonStatus.unavailable,
  );

  Future<void> startLesson(String lessonId) async {
    if (!canStartLesson(lessonId)) return;
    state = state.copyWith(
      activeLessonId: lessonId,
      exercises: [],
      currentExerciseIndex: 0,
      correctAnswersInLesson: 0,
      lessonComplete: false,
      matchedPairIds: {},
      answers: {},
      clearError: true,
    );
    try {
      final exercises = await api.exercises(lessonId);
      if (exercises.isNotEmpty && mounted) {
        state = state.copyWith(exercises: exercises);
      }
    } catch (_) {}
  }

  /// Check a single exercise answer via the per-exercise endpoint.
  ///
  /// Supports [selectedOptionId] (fillBlank, pictureToWord, wordToPicture,
  /// dialogueComplete), [selectedPairs] (matchWords), and
  /// [selectedTileIds] (translate, wordOrder).
  ///
  /// Returns true if correct. Network errors are rethrown so the UI can
  /// display them and offer retry — never silently treated as incorrect.
  Future<bool> checkAnswer(
    String exerciseId, {
    String? selectedOptionId,
    Map<String, String>? selectedPairs,
    List<String>? selectedTileIds,
  }) async {
    final lessonId = state.activeLessonId;
    if (lessonId == null) return false;
    final answer = <String, dynamic>{'exercise_id': exerciseId};
    if (selectedOptionId != null) {
      answer['selected_option_id'] = selectedOptionId;
    }
    if (selectedPairs != null) {
      answer['selected_pairs'] = selectedPairs;
    }
    if (selectedTileIds != null) {
      answer['selected_tile_ids'] = selectedTileIds;
    }
    bool correct = false;
    try {
      correct = await api.checkAnswer(lessonId, answer);
    } catch (e) {
      // Re-throw network errors so the UI can display them and retry.
      // Do NOT silently default to true — that would accept wrong answers.
      rethrow;
    }
    if (correct && mounted) {
      final answers = Map<String, Map<String, dynamic>>.from(state.answers);
      final existing = answers[exerciseId];
      if (selectedPairs != null && existing != null) {
        final previousPairs =
            existing['selected_pairs'] as Map<String, dynamic>? ?? {};
        answers[exerciseId] = {
          ...existing,
          'exercise_id': exerciseId,
          'selected_pairs': {...previousPairs, ...selectedPairs},
        };
      } else {
        answers[exerciseId] = answer;
      }
      state = state.copyWith(
        answers: answers,
        correctAnswersInLesson: state.correctAnswersInLesson + 1,
      );
    }
    return correct;
  }

  void addMatchedPair(String devanagariId, String englishId) {
    state = state.copyWith(
      matchedPairIds: {...state.matchedPairIds, devanagariId, englishId},
    );
  }

  void nextExercise() => state = state.copyWith(
    currentExerciseIndex: state.currentExerciseIndex + 1,
  );

  /// Submit the complete lesson attempt to the backend.
  ///
  /// [idempotencyKey] scopes the submission to this user+lesson+request
  /// so duplicate network retries do not award double XP. Reuse the same
  /// key when retrying the same submission after a timeout or uncertain
  /// network failure; generate a new key only for a genuinely new attempt.
  Future<void> completeLesson({String? idempotencyKey}) async {
    final lessonId = state.activeLessonId;
    if (lessonId == null || state.lessonComplete) return;
    if (state.exercises.isNotEmpty &&
        state.answers.length < state.exercises.length) {
      // Guard: all exercises must have recorded answers before submitting attempt
      return;
    }
    state = state.copyWith(lessonComplete: true);

    try {
      final result = await api.submitAttempt(
        lessonId,
        answers: state.answers.values.toList(),
        idempotencyKey: idempotencyKey,
      );

      final xpEarned = (result['xp_earned'] as num?)?.toInt() ?? 0;
      final correctAnswers = (result['correct_answers'] as num?)?.toInt() ?? 0;
      final totalQuestions = (result['total_questions'] as num?)?.toInt() ?? 0;
      final alreadyCompleted = (result['already_completed'] as bool?) ?? false;
      final score =
          (result['score'] as num?)?.toDouble() ??
          (totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0);
      final passingThreshold =
          (result['passing_threshold'] as num?)?.toInt() ?? 100;
      final passed =
          (result['passed'] as bool?) ??
          (totalQuestions > 0 &&
              correctAnswers * 100 >= totalQuestions * passingThreshold);

      var user = state.user;
      try {
        user = await api.me();
      } catch (_) {
        // A successful attempt is already committed. A profile refresh
        // failure must not turn that success into a retry or lose answers.
      }

      final lessons = await api.lessons(courseId: user.activeCourseId);
      if (mounted) {
        state = state.copyWith(
          user: user,
          lessons: lessons,
          lessonComplete: true,
          lastXpEarned: xpEarned,
          lastCorrectAnswers: correctAnswers,
          lastTotalQuestions: totalQuestions,
          lastScore: score,
          lastPassingThreshold: passingThreshold,
          lastPassed: passed,
          lastAlreadyCompleted: alreadyCompleted,
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          lessonComplete: false,
          errorMessage: error.toString(),
        );
      }
      rethrow;
    }
  }

  void resetLesson() => state = state.copyWith(
    clearActiveLesson: true,
    exercises: [],
    currentExerciseIndex: 0,
    correctAnswersInLesson: 0,
    lessonComplete: false,
    matchedPairIds: {},
    answers: {},
  );
}

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>(
  (ref) => GameStateNotifier(ref.watch(backendApiProvider)),
);

/// Provides the town map data (all lessons with availability status).
final townMapProvider = FutureProvider<List<Lesson>>((ref) async {
  final api = ref.watch(backendApiProvider);
  final raw = await api.townMap('en_new');
  return raw
      .map(
        (r) => Lesson(
          id: r['id'] as String,
          unitId: r['unit_sequence'] != null
              ? (r['unit_sequence'] as num).toInt()
              : null,
          sequence: r['sequence'] != null
              ? (r['sequence'] as num).toInt()
              : null,
          title: r['title'] as String,
          subtitle: r['subtitle'] as String,
          exerciseType: _parseExerciseType(r['exercise_type'] as String),
          status: _lessonStatus(r['availability'] as String?),
          xpReward: (r['xp_reward'] as num?)?.toInt() ?? 20,
          wordCount: (r['word_count'] as num?)?.toInt() ?? 4,
          requiredLevel: (r['required_level'] as num?)?.toInt() ?? 1,
          isPublished: (r['is_published'] as bool?) ?? true,
          isCheckpoint: (r['is_checkpoint'] as bool?) ?? false,
          isCapstone: (r['is_capstone'] as bool?) ?? false,
          availability: r['availability'] as String? ?? 'locked',
          plannedExerciseCount:
              (r['planned_exercise_count'] as num?)?.toInt() ?? 0,
          populatedExerciseCount:
              (r['populated_exercise_count'] as num?)?.toInt() ?? 0,
        ),
      )
      .toList();
});

ExerciseType _parseExerciseType(String? value) {
  switch (value) {
    case 'matchWords':
      return ExerciseType.matchWords;
    case 'fillBlank':
      return ExerciseType.fillBlank;
    case 'pictureToWord':
      return ExerciseType.pictureToWord;
    case 'wordToPicture':
      return ExerciseType.wordToPicture;
    case 'translate':
      return ExerciseType.translate;
    case 'wordOrder':
      return ExerciseType.wordOrder;
    case 'dialogueComplete':
      return ExerciseType.dialogueComplete;
    default:
      return ExerciseType.fillBlank;
  }
}

LessonStatus _lessonStatus(String? value) {
  switch (value) {
    case 'cleared':
    case 'completed':
      return LessonStatus.completed;
    case 'locked':
      return LessonStatus.locked;
    case 'unavailable':
      return LessonStatus.unavailable;
    case 'current':
    default:
      return LessonStatus.available;
  }
}
