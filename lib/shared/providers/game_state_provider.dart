import 'dart:math';

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
  final String? runId;
  final int currentExerciseIndex;
  final int correctAnswersInLesson;
  final bool lessonComplete;
  final Set<String> matchedPairIds;
  final Map<String, Map<String, dynamic>> answers;
  final Set<String> answeredExerciseIds;
  final Map<String, Map<String, String>> matchedPairsByExercise;
  final List<String> reviewQueue;
  final bool isReviewingMistakes;
  final int reviewTotalCount;
  final int reviewRetryNonce;
  final bool needsCompletion;
  final int lastXpEarned;
  final int lastCorrectAnswers;
  final int lastTotalQuestions;
  final bool lastAlreadyCompleted;
  final double lastScore;
  final int lastPassingThreshold;
  final bool lastPassed;
  final int lastEarnedXp;
  final int lastXpMax;
  final List<Map<String, dynamic>> lastMissedVocabulary;
  final Map<String, int> lastStatGains;
  final Map<String, int> lastHeroStats;
  final bool lastLevelUp;
  final int lastOldLevel;
  final int lastNewLevel;
  final int lastMistakesCorrected;
  final int lastMasteredExercises;
  final List<Map<String, dynamic>> lastExerciseResults;

  const GameState({
    required this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.lessons = const [],
    this.exercises = const [],
    this.activeLessonId,
    this.runId,
    this.currentExerciseIndex = 0,
    this.correctAnswersInLesson = 0,
    this.lessonComplete = false,
    this.matchedPairIds = const {},
    this.answers = const {},
    this.answeredExerciseIds = const {},
    this.matchedPairsByExercise = const {},
    this.reviewQueue = const [],
    this.isReviewingMistakes = false,
    this.reviewTotalCount = 0,
    this.reviewRetryNonce = 0,
    this.needsCompletion = false,
    this.lastXpEarned = 0,
    this.lastCorrectAnswers = 0,
    this.lastTotalQuestions = 0,
    this.lastAlreadyCompleted = false,
    this.lastScore = 0,
    this.lastPassingThreshold = 100,
    this.lastPassed = false,
    this.lastEarnedXp = 0,
    this.lastXpMax = 0,
    this.lastMissedVocabulary = const [],
    this.lastStatGains = const {},
    this.lastHeroStats = const {},
    this.lastLevelUp = false,
    this.lastOldLevel = 1,
    this.lastNewLevel = 1,
    this.lastMistakesCorrected = 0,
    this.lastMasteredExercises = 0,
    this.lastExerciseResults = const [],
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
    String? runId,
    bool clearRunId = false,
    int? currentExerciseIndex,
    int? correctAnswersInLesson,
    bool? lessonComplete,
    Set<String>? matchedPairIds,
    Map<String, Map<String, dynamic>>? answers,
    Set<String>? answeredExerciseIds,
    Map<String, Map<String, String>>? matchedPairsByExercise,
    List<String>? reviewQueue,
    bool? isReviewingMistakes,
    int? reviewTotalCount,
    int? reviewRetryNonce,
    bool? needsCompletion,
    int? lastXpEarned,
    int? lastCorrectAnswers,
    int? lastTotalQuestions,
    bool? lastAlreadyCompleted,
    double? lastScore,
    int? lastPassingThreshold,
    bool? lastPassed,
    int? lastEarnedXp,
    int? lastXpMax,
    List<Map<String, dynamic>>? lastMissedVocabulary,
    Map<String, int>? lastStatGains,
    Map<String, int>? lastHeroStats,
    bool? lastLevelUp,
    int? lastOldLevel,
    int? lastNewLevel,
    int? lastMistakesCorrected,
    int? lastMasteredExercises,
    List<Map<String, dynamic>>? lastExerciseResults,
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
    runId: clearRunId ? null : (runId ?? this.runId),
    currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
    correctAnswersInLesson:
        correctAnswersInLesson ?? this.correctAnswersInLesson,
    lessonComplete: lessonComplete ?? this.lessonComplete,
    matchedPairIds: matchedPairIds ?? this.matchedPairIds,
    answers: answers ?? this.answers,
    answeredExerciseIds: answeredExerciseIds ?? this.answeredExerciseIds,
    matchedPairsByExercise:
        matchedPairsByExercise ?? this.matchedPairsByExercise,
    reviewQueue: reviewQueue ?? this.reviewQueue,
    isReviewingMistakes: isReviewingMistakes ?? this.isReviewingMistakes,
    reviewTotalCount: reviewTotalCount ?? this.reviewTotalCount,
    reviewRetryNonce: reviewRetryNonce ?? this.reviewRetryNonce,
    needsCompletion: needsCompletion ?? this.needsCompletion,
    lastXpEarned: lastXpEarned ?? this.lastXpEarned,
    lastCorrectAnswers: lastCorrectAnswers ?? this.lastCorrectAnswers,
    lastTotalQuestions: lastTotalQuestions ?? this.lastTotalQuestions,
    lastAlreadyCompleted: lastAlreadyCompleted ?? this.lastAlreadyCompleted,
    lastScore: lastScore ?? this.lastScore,
    lastPassingThreshold: lastPassingThreshold ?? this.lastPassingThreshold,
    lastPassed: lastPassed ?? this.lastPassed,
    lastEarnedXp: lastEarnedXp ?? this.lastEarnedXp,
    lastXpMax: lastXpMax ?? this.lastXpMax,
    lastMissedVocabulary: lastMissedVocabulary ?? this.lastMissedVocabulary,
    lastStatGains: lastStatGains ?? this.lastStatGains,
    lastHeroStats: lastHeroStats ?? this.lastHeroStats,
    lastLevelUp: lastLevelUp ?? this.lastLevelUp,
    lastOldLevel: lastOldLevel ?? this.lastOldLevel,
    lastNewLevel: lastNewLevel ?? this.lastNewLevel,
    lastMistakesCorrected: lastMistakesCorrected ?? this.lastMistakesCorrected,
    lastMasteredExercises: lastMasteredExercises ?? this.lastMasteredExercises,
    lastExerciseResults: lastExerciseResults ?? this.lastExerciseResults,
  );
}

class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier(this.api) : super(const GameState(user: guestUser)) {
    restoreSession();
  }

  final BackendApi api;
  int _lessonStartGeneration = 0;
  int _authGeneration = 0;

  bool _isCurrentSession(int generation) =>
      mounted && generation == _authGeneration;

  String _newAnswerSubmissionId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<void> restoreSession() async {
    final generation = ++_authGeneration;
    _lessonStartGeneration++;
    try {
      final token = await api.token;
      if (!_isCurrentSession(generation)) return;
      if (token == null) return;
      if (mounted) state = state.copyWith(isLoading: true, clearError: true);
      final user = await api.me();
      if (!_isCurrentSession(generation)) return;
      await _loadAuthenticatedState(user, generation);
    } catch (_) {
      if (!_isCurrentSession(generation)) return;
      try {
        await api.logout();
      } catch (_) {}
      if (_isCurrentSession(generation)) {
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
    final generation = ++_authGeneration;
    _lessonStartGeneration++;
    final clearPreviousCredentials = api.logout();
    state = const GameState(user: guestUser, isLoading: true);
    try {
      await clearPreviousCredentials;
      if (!_isCurrentSession(generation)) return;
      final user = await action();
      if (!_isCurrentSession(generation)) return;
      await _loadAuthenticatedState(user, generation);
    } catch (error) {
      if (_isCurrentSession(generation)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      }
      rethrow;
    }
  }

  /// Load courses, languages, units, and lessons after authentication.
  Future<void> _loadAuthenticatedState(DemoUser user, int generation) async {
    try {
      if (user.activeCourseId != 'en_new') {
        await api.updateActiveCourse('en_new');
        if (!_isCurrentSession(generation)) return;
        user = await api.me();
      }
      final lessons = user.activeCourseId == 'en_new'
          ? await api.lessons(courseId: 'en_new')
          : <Lesson>[];
      if (_isCurrentSession(generation)) {
        state = GameState(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          lessons: lessons,
        );
      }
    } catch (error) {
      // Even if courses fail to load, still set authenticated state.
      if (_isCurrentSession(generation)) {
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
    ++_authGeneration;
    _lessonStartGeneration++;
    final clearCredentials = api.logout();
    state = const GameState(user: guestUser);
    await clearCredentials;
  }

  Future<void> selectHero(int index, String name) async {
    final generation = _authGeneration;
    final userId = state.user.id;
    state = state.copyWith(
      user: state.user.copyWith(heroIndex: index, name: name),
    );
    try {
      final user = await api.updateProfile(heroIndex: index, name: name);
      if (_isCurrentSession(generation) && state.user.id == userId) {
        state = state.copyWith(user: user);
      }
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
    if (!canStartLesson(lessonId)) {
      throw const BackendException('This lesson is locked or unavailable.');
    }
    final authGeneration = _authGeneration;
    final generation = ++_lessonStartGeneration;
    state = state.copyWith(
      activeLessonId: lessonId,
      clearRunId: true,
      exercises: [],
      currentExerciseIndex: 0,
      correctAnswersInLesson: 0,
      lessonComplete: false,
      matchedPairIds: {},
      answers: {},
      answeredExerciseIds: {},
      matchedPairsByExercise: {},
      reviewQueue: [],
      isReviewingMistakes: false,
      reviewTotalCount: 0,
      reviewRetryNonce: 0,
      needsCompletion: false,
      clearError: true,
    );
    try {
      final runState = await api.startLessonRun(lessonId);
      final runId = runState['run_id'] as String;
      final exercises = await api.exercises(lessonId);
      if (exercises.isEmpty) {
        throw const BackendException(
          'No exercises are available for this lesson yet.',
        );
      }
      if (!_isCurrentSession(authGeneration) ||
          generation != _lessonStartGeneration ||
          state.activeLessonId != lessonId) {
        return;
      }
      final answeredIds =
          (runState['answered_exercise_ids'] as List? ?? const [])
              .whereType<String>()
              .toSet();
      final originalResults =
          runState['original_results'] as Map<String, dynamic>? ?? const {};
      final restoredAnswers = <String, Map<String, dynamic>>{
        for (final entry in originalResults.entries)
          entry.key: {'exercise_id': entry.key, 'correct': entry.value == true},
      };
      final queue = (runState['review_queue'] as List? ?? const [])
          .whereType<String>()
          .toList();
      final corrected =
          (runState['corrected_exercise_ids'] as List? ?? const [])
              .whereType<String>()
              .toSet();
      final rawMatched =
          runState['matched_pairs_by_exercise'] as Map<String, dynamic>? ??
          const {};
      final matchedByExercise = <String, Map<String, String>>{};
      for (final entry in rawMatched.entries) {
        final value = entry.value;
        if (value is Map) {
          matchedByExercise[entry.key] = {
            for (final pair in value.entries)
              if (pair.key is String && pair.value is String)
                pair.key as String: pair.value as String,
          };
        }
      }
      final firstUnanswered = exercises.indexWhere(
        (exercise) => !answeredIds.contains(exercise.id),
      );
      final isReviewing = firstUnanswered < 0 && queue.isNotEmpty;
      state = state.copyWith(
        runId: runId,
        exercises: exercises,
        currentExerciseIndex: firstUnanswered < 0 ? 0 : firstUnanswered,
        correctAnswersInLesson: restoredAnswers.values
            .where((answer) => answer['correct'] == true)
            .length,
        answers: restoredAnswers,
        answeredExerciseIds: answeredIds,
        reviewQueue: queue,
        isReviewingMistakes: isReviewing,
        reviewTotalCount: queue.length + corrected.length,
        matchedPairsByExercise: matchedByExercise,
        needsCompletion: runState['needs_completion'] == true,
        clearError: true,
      );
    } catch (error) {
      if (_isCurrentSession(authGeneration) &&
          generation == _lessonStartGeneration &&
          state.activeLessonId == lessonId) {
        state = state.copyWith(
          clearActiveLesson: true,
          exercises: [],
          currentExerciseIndex: 0,
          correctAnswersInLesson: 0,
          lessonComplete: false,
          errorMessage: error.toString(),
        );
      }
      rethrow;
    }
  }

  /// Compatibility helper for legacy callers. Active gameplay uses
  /// [submitExerciseAnswer] so it can render final feedback and continue.
  Future<bool> checkAnswer(
    String exerciseId, {
    String? selectedOptionId,
    Map<String, String>? selectedPairs,
    List<String>? selectedTileIds,
  }) async {
    final authGeneration = _authGeneration;
    final lessonId = state.activeLessonId;
    final runId = state.runId;
    if (lessonId == null || runId == null) return false;
    final answer = <String, dynamic>{
      'exercise_id': exerciseId,
      'run_id': runId,
    };
    if (selectedOptionId != null) {
      answer['selected_option_id'] = selectedOptionId;
    }
    if (selectedPairs != null) answer['selected_pairs'] = selectedPairs;
    if (selectedTileIds != null) answer['selected_tile_ids'] = selectedTileIds;
    final correct = await api.checkAnswer(lessonId, answer);
    if (!_isCurrentSession(authGeneration)) {
      throw const BackendException(
        'The account session changed. Please retry.',
      );
    }
    if (correct && mounted) {
      final answers = Map<String, Map<String, dynamic>>.from(state.answers)
        ..[exerciseId] = answer;
      state = state.copyWith(
        answers: answers,
        correctAnswersInLesson: state.correctAnswersInLesson + 1,
      );
    }
    return correct;
  }

  /// Record a single active-curriculum answer and return authoritative feedback.
  Future<Map<String, dynamic>> submitExerciseAnswer(
    String exerciseId, {
    String? submissionId,
    bool review = false,
    String? selectedOptionId,
    Map<String, String>? selectedPairs,
    List<String>? selectedTileIds,
  }) async {
    final authGeneration = _authGeneration;
    final lessonId = state.activeLessonId;
    final runId = state.runId;
    if (lessonId == null || runId == null) {
      throw const BackendException('No active lesson attempt.');
    }
    final answer = <String, dynamic>{
      'exercise_id': exerciseId,
      'run_id': runId,
      'submission_id': submissionId ?? _newAnswerSubmissionId(),
    };
    if (review) answer['phase'] = 'review';
    if (selectedOptionId != null) {
      answer['selected_option_id'] = selectedOptionId;
    }
    if (selectedPairs != null) {
      answer['selected_pairs'] = selectedPairs;
    }
    if (selectedTileIds != null) {
      answer['selected_tile_ids'] = selectedTileIds;
    }
    late final Map<String, dynamic> response;
    try {
      response = await api.answerExercise(lessonId, answer);
    } catch (e) {
      // Re-throw network errors so the UI can display them and retry.
      // Do NOT silently default to true — that would accept wrong answers.
      rethrow;
    }
    if (!_isCurrentSession(authGeneration)) {
      throw const BackendException(
        'The account session changed. Please retry.',
      );
    }
    final correct = response['correct'] as bool;
    final isFinal = response['is_final'] as bool;
    if (_isCurrentSession(authGeneration) &&
        state.activeLessonId == lessonId &&
        state.runId == runId) {
      if (review) return response;
      final answers = Map<String, Map<String, dynamic>>.from(state.answers);
      final answeredIds = Set<String>.from(state.answeredExerciseIds);
      final wasAnswered = answeredIds.contains(exerciseId);
      if (isFinal) {
        answeredIds.add(exerciseId);
        answers[exerciseId] = {'exercise_id': exerciseId, 'correct': correct};
      }

      final matchedPairs =
          response['matched_pairs'] as Map<String, dynamic>? ?? {};
      final matchedByExercise = Map<String, Map<String, String>>.from(
        state.matchedPairsByExercise,
      );
      if (selectedPairs != null) {
        matchedByExercise[exerciseId] = {
          for (final entry in matchedPairs.entries)
            if (entry.value is String) entry.key: entry.value,
        };
      }
      state = state.copyWith(
        answers: answers,
        answeredExerciseIds: answeredIds,
        matchedPairsByExercise: matchedByExercise,
        matchedPairIds: {
          ...matchedPairs.keys,
          ...matchedPairs.values.whereType<String>(),
        },
        correctAnswersInLesson:
            state.correctAnswersInLesson +
            (isFinal && correct && !wasAnswered ? 1 : 0),
      );
    }
    return response;
  }

  void addMatchedPair(String devanagariId, String englishId) {
    state = state.copyWith(
      matchedPairIds: {...state.matchedPairIds, devanagariId, englishId},
    );
  }

  void nextExercise() {
    if (state.currentExerciseIndex < 0 ||
        state.currentExerciseIndex >= state.exercises.length - 1) {
      return;
    }
    state = state.copyWith(
      currentExerciseIndex: state.currentExerciseIndex + 1,
    );
  }

  Future<List<String>> refreshReviewQueue() async {
    final authGeneration = _authGeneration;
    final lessonId = state.activeLessonId;
    final runId = state.runId;
    if (lessonId == null || runId == null) {
      throw const BackendException('No active lesson attempt.');
    }
    final response = await api.reviewQueue(lessonId, runId);
    final queue = (response['review_queue'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final corrected = (response['corrected_exercise_ids'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    if (!_isCurrentSession(authGeneration)) {
      throw const BackendException(
        'The account session changed. Please retry.',
      );
    }
    if (state.activeLessonId == lessonId && state.runId == runId) {
      state = state.copyWith(
        reviewQueue: queue,
        reviewTotalCount: queue.length + corrected.length,
      );
    }
    return queue;
  }

  void beginMistakeReview(List<String> queue) {
    state = state.copyWith(
      reviewQueue: queue,
      isReviewingMistakes: queue.isNotEmpty,
      reviewTotalCount: queue.length,
      reviewRetryNonce: 0,
      needsCompletion: false,
    );
  }

  void retryReviewExercise() {
    state = state.copyWith(reviewRetryNonce: state.reviewRetryNonce + 1);
  }

  /// Finalize the server-recorded exercise answers for the current run.
  Future<void> completeLesson({String? idempotencyKey}) async {
    final authGeneration = _authGeneration;
    final lessonId = state.activeLessonId;
    final runId = state.runId;
    if (lessonId == null || runId == null || state.lessonComplete) return;
    state = state.copyWith(lessonComplete: true);

    try {
      final result = await api.submitAttempt(
        lessonId,
        answers: const [],
        idempotencyKey: idempotencyKey ?? runId,
      );
      if (!_isCurrentSession(authGeneration)) {
        throw const BackendException(
          'The account session changed. Please retry.',
        );
      }

      final xpEarned =
          (result['credited_xp'] as num?)?.toInt() ??
          (result['xp_earned'] as num?)?.toInt() ??
          0;
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
      final earnedXp = (result['earned_xp'] as num?)?.toInt() ?? 0;
      final xpMax = (result['xp_max'] as num?)?.toInt() ?? 0;
      final missed = (result['missed_vocabulary'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final exerciseResults = (result['results'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final statGains = (result['stat_gains'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, (value as num).toInt()));
      final heroStats = (result['hero_stats'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, (value as num).toInt()));

      var user = state.user;
      try {
        user = await api.me();
      } catch (_) {
        // A successful attempt is already committed. A profile refresh
        // failure must not turn that success into a retry or lose answers.
      }

      if (!_isCurrentSession(authGeneration)) {
        throw const BackendException(
          'The account session changed. Please retry.',
        );
      }
      final lessons = await api.lessons(courseId: user.activeCourseId);
      if (_isCurrentSession(authGeneration)) {
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
          lastEarnedXp: earnedXp,
          lastXpMax: xpMax,
          lastMissedVocabulary: missed,
          lastMistakesCorrected:
              (result['mistakes_corrected'] as num?)?.toInt() ?? 0,
          lastMasteredExercises:
              (result['mastered_exercises'] as num?)?.toInt() ?? 0,
          lastExerciseResults: exerciseResults,
          lastStatGains: statGains,
          lastHeroStats: heroStats,
          lastLevelUp: (result['level_up'] as bool?) ?? false,
          lastOldLevel: (result['old_level'] as num?)?.toInt() ?? user.level,
          lastNewLevel: (result['new_level'] as num?)?.toInt() ?? user.level,
        );
      }
    } catch (error) {
      if (_isCurrentSession(authGeneration)) {
        state = state.copyWith(
          lessonComplete: false,
          errorMessage: error.toString(),
        );
      }
      rethrow;
    }
  }

  void resetLesson() {
    _lessonStartGeneration++;
    state = state.copyWith(
      clearActiveLesson: true,
      clearRunId: true,
      exercises: [],
      currentExerciseIndex: 0,
      correctAnswersInLesson: 0,
      lessonComplete: false,
      matchedPairIds: {},
      answers: {},
      answeredExerciseIds: {},
      matchedPairsByExercise: {},
      reviewQueue: [],
      isReviewingMistakes: false,
      reviewTotalCount: 0,
      reviewRetryNonce: 0,
      needsCompletion: false,
    );
  }
}

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>(
  (ref) => GameStateNotifier(ref.watch(backendApiProvider)),
);

/// Provides the town map data (all lessons with availability status).
final townMapProvider = FutureProvider<List<Lesson>>((ref) async {
  final session = ref.watch(
    gameStateProvider.select(
      (state) => (state.isAuthenticated, state.user.id, state.isLoading),
    ),
  );
  if (session.$1 && session.$2.isEmpty) {
    throw StateError('Authenticated account is missing its identity.');
  }
  if (session.$3) return const [];
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
          unitTitle: r['unit_title'] as String?,
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
    default:
      throw FormatException('Unsupported exercise type: $value');
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
