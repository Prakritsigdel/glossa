import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/demo_user.dart';
import '../models/course_models.dart';
import '../mock_data/mock_data.dart';
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
  // FIX 5: Real attempt statistics for the level-up screen.
  final int lastXpEarned;
  final int lastCorrectAnswers;
  final int lastTotalQuestions;
  final List<String> lastWordsLearned;

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
    this.lastWordsLearned = const [],
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
    List<String>? lastWordsLearned,
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
    lastWordsLearned: lastWordsLearned ?? this.lastWordsLearned,
  );
}

class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier(this.api)
      : super(GameState(user: seedUser, lessons: mockLessons)) {
    restoreSession();
  }

  final BackendApi api;

  Future<void> restoreSession() async {
    try {
      final token = await api.token;
      if (token == null) return;
      if (mounted) state = state.copyWith(isLoading: true, clearError: true);
      final user = await api.me();
      final lessons = await api.lessons();
      if (mounted) {
        state = state.copyWith(
          user: user,
          lessons: lessons,
          isAuthenticated: true,
          isLoading: false,
        );
      }
    } catch (_) {
      try {
        await api.logout();
      } catch (_) {}
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          clearError: true,
        );
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
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await action();
      final lessons = await api.lessons();
      if (mounted) {
        state = GameState(user: user, isAuthenticated: true, lessons: lessons);
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: error.toString());
      }
      rethrow;
    }
  }

  Future<void> logOut() async {
    try {
      await api.logout();
    } catch (_) {}
    if (mounted) {
      state = GameState(user: seedUser, lessons: mockLessons);
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

  Future<void> selectLanguage(String id, String name, String script) async {
    state = state.copyWith(
      user: state.user.copyWith(
        languageId: id,
        languageName: name,
        languageScript: script,
      ),
    );
    try {
      final user = await api.updateProfile(languageId: id);
      if (mounted) {
        state = state.copyWith(
          user: user.copyWith(languageName: name, languageScript: script),
        );
      }
    } catch (_) {}
  }

  bool canStartLesson(String lessonId) => state.lessons.any(
    (l) => l.id == lessonId && l.status != LessonStatus.locked,
  );

  Future<void> startLesson(String lessonId) async {
    if (!canStartLesson(lessonId)) return;
    state = state.copyWith(
      activeLessonId: lessonId,
      exercises: exercisesForLesson(lessonId),
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

  Future<bool> checkAnswer(
    String exerciseId, {
    String? selectedOptionId,
    Map<String, String>? selectedPairs,
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
    bool correct = false;
    try {
      correct = await api.checkAnswer(lessonId, answer);
    } catch (_) {
      correct = true;
    }
    if (correct && mounted) {
      final answers = Map<String, Map<String, dynamic>>.from(state.answers);
      final existing = answers[exerciseId];
      if (selectedPairs != null) {
        final previousPairs =
            existing?['selected_pairs'] as Map<String, dynamic>? ?? {};
        answers[exerciseId] = {
          ...?existing,
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

  Future<void> completeLesson() async {
    final lessonId = state.activeLessonId;
    // FIX 4 / FIX 6: Guard prevents duplicate calls. lessonComplete is set
    // immediately so concurrent callers are blocked before any await.
    if (lessonId == null || state.lessonComplete) return;

    // FIX 6: Mark complete immediately to block re-entry, but do NOT apply XP
    // optimistically. We wait for the server to confirm the reward so that a
    // network failure leaves the user XP unchanged and allows a retry.
    state = state.copyWith(lessonComplete: true);

    // Collect words learned from the exercises (Devanagari options).
    final wordsLearned = state.exercises
        .expand((e) => e.options.where((o) => o.isDevanagari).map((o) => o.text))
        .toSet()
        .toList();

    try {
      final result = await api.submitAttempt(
        lessonId,
        state.answers.values.toList(),
      );

      // FIX 5: Extract real attempt statistics.
      final xpEarned = (result['xp_earned'] as num?)?.toInt() ?? 0;
      final correctAnswers = (result['correct_answers'] as num?)?.toInt() ?? 0;
      final totalQuestions = (result['total_questions'] as num?)?.toInt() ?? 0;

      final userRow = result['user'] as Map<String, dynamic>;
      final user = DemoUser(
        name: userRow['name'] as String,
        email: userRow['email'] as String,
        heroIndex: (userRow['hero_index'] as num).toInt(),
        heroClassName: userRow['hero_class_name'] as String,
        level: (userRow['level'] as num).toInt(),
        xp: (userRow['xp'] as num).toInt(),
        xpToNextLevel: (userRow['xp_to_next_level'] as num).toInt(),
        streak: (userRow['streak'] as num).toInt(),
        wordsFound: (userRow['words_found'] as num).toInt(),
        lessonsCompleted: (userRow['lessons_completed'] as num).toInt(),
        languageId: userRow['language_id'] as String,
        languageName: state.user.languageName,
        languageScript: state.user.languageScript,
      );

      final lessons = await api.lessons();
      if (mounted) {
        state = state.copyWith(
          user: user,
          lessons: lessons,
          lessonComplete: true,
          lastXpEarned: xpEarned,
          lastCorrectAnswers: correctAnswers,
          lastTotalQuestions: totalQuestions,
          lastWordsLearned: wordsLearned,
        );
      }
    } catch (error) {
      // FIX 6: On failure, reset lessonComplete so the user can retry.
      // XP was never applied optimistically, so it stays correct.
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
