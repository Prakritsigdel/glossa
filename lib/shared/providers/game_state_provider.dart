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
  );
}

class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier(this.api) : super(GameState(user: seedUser)) {
    restoreSession();
  }

  final BackendApi api;

  Future<void> restoreSession() async {
    if (await api.token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await api.me();
      final lessons = await api.lessons();
      state = state.copyWith(
        user: user,
        lessons: lessons,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (_) {
      await api.logout();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        clearError: true,
      );
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
      state = GameState(user: user, isAuthenticated: true, lessons: lessons);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> logOut() async {
    await api.logout();
    state = GameState(user: seedUser);
  }

  Future<void> selectHero(int index, String name) async {
    final user = await api.updateProfile(heroIndex: index, name: name);
    state = state.copyWith(user: user);
  }

  Future<void> selectLanguage(String id, String name, String script) async {
    final user = await api.updateProfile(languageId: id);
    state = state.copyWith(
      user: user.copyWith(languageName: name, languageScript: script),
    );
  }

  bool canStartLesson(String lessonId) => state.lessons.any(
    (l) => l.id == lessonId && l.status != LessonStatus.locked,
  );

  Future<void> startLesson(String lessonId) async {
    if (!canStartLesson(lessonId)) return;
    final exercises = await api.exercises(lessonId);
    state = state.copyWith(
      activeLessonId: lessonId,
      exercises: exercises,
      currentExerciseIndex: 0,
      correctAnswersInLesson: 0,
      lessonComplete: false,
      matchedPairIds: {},
      answers: {},
      clearError: true,
    );
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
    if (selectedPairs != null) answer['selected_pairs'] = selectedPairs;
    final correct = await api.checkAnswer(lessonId, answer);
    if (correct) {
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
    if (lessonId == null || state.lessonComplete) return;
    final result = await api.submitAttempt(
      lessonId,
      state.answers.values.toList(),
    );
    final userRow = result['user'] as Map<String, dynamic>;
    final user = DemoUser(
      name: userRow['name'],
      email: userRow['email'],
      heroIndex: userRow['hero_index'],
      heroClassName: userRow['hero_class_name'],
      level: userRow['level'],
      xp: userRow['xp'],
      xpToNextLevel: userRow['xp_to_next_level'],
      streak: userRow['streak'],
      wordsFound: userRow['words_found'],
      lessonsCompleted: userRow['lessons_completed'],
      languageId: userRow['language_id'],
      languageName: state.user.languageName,
      languageScript: state.user.languageScript,
    );
    final lessons = await api.lessons();
    state = state.copyWith(user: user, lessons: lessons, lessonComplete: true);
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
