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
  final int lastXpEarned;
  final int lastCorrectAnswers;
  final int lastTotalQuestions;
  final List<String> lastWordsLearned;
  // ─── Course architecture ───────────────────────────────────
  final List<Language> languages;
  final List<Course> courses;
  final List<CourseUnit> units;

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
    this.languages = const [],
    this.courses = const [],
    this.units = const [],
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
    List<Language>? languages,
    List<Course>? courses,
    List<CourseUnit>? units,
  }) =>
      GameState(
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
        languages: languages ?? this.languages,
        courses: courses ?? this.courses,
        units: units ?? this.units,
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
      await _loadCoursesAndLanguages(user);
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
      await _loadCoursesAndLanguages(user);
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: error.toString());
      }
      rethrow;
    }
  }

  /// Load courses, languages, units, and lessons after authentication.
  Future<void> _loadCoursesAndLanguages(DemoUser user) async {
    try {
      final languages = await api.getLanguages();
      final courses = await api.getCourses(publishedOnly: true);
      List<CourseUnit> units = [];
      List<Lesson> lessons = [];
      if (user.activeCourseId != null) {
        try {
          units = await api.getUnitsForCourse(user.activeCourseId!);
          lessons = await api.lessons(courseId: user.activeCourseId);
        } catch (_) {}
      }
      if (mounted) {
        state = GameState(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          languages: languages,
          courses: courses,
          units: units,
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
    final targetCourseId = id == 'english' ? 'ne_en' : 'en_ne';
    state = state.copyWith(
      user: state.user.copyWith(
        languageId: id,
        languageName: name,
        languageScript: script,
        activeCourseId: targetCourseId,
      ),
    );
    try {
      final user = await api.updateProfile(languageId: id);
      DemoUser updatedUser = user;
      try {
        updatedUser = await api.updateActiveCourse(targetCourseId);
      } catch (_) {}
      List<CourseUnit> units = [];
      List<Lesson> lessons = [];
      try {
        units = await api.getUnitsForCourse(targetCourseId);
      } catch (_) {}
      try {
        lessons = await api.lessons(courseId: targetCourseId);
      } catch (_) {}
      if (mounted) {
        state = state.copyWith(
          user: updatedUser.copyWith(languageName: name, languageScript: script),
          units: units.isNotEmpty ? units : state.units,
          lessons: lessons.isNotEmpty ? lessons : state.lessons,
        );
      }
    } catch (_) {}
  }

  // ─── Course switching ────────────────────────────────────────

  Future<void> switchCourse(String courseId) async {
    final previousCourseId = state.user.activeCourseId;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await api.updateActiveCourse(courseId);
      // Reload units and lessons for the new course
      List<CourseUnit> units = [];
      List<Lesson> lessons = [];
      try {
        units = await api.getUnitsForCourse(courseId);
      } catch (_) {}
      try {
        lessons = await api.lessons(courseId: courseId);
      } catch (_) {}
      if (mounted) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          units: units,
          lessons: lessons,
          clearActiveLesson: true,
          exercises: [],
          currentExerciseIndex: 0,
          correctAnswersInLesson: 0,
          lessonComplete: false,
          matchedPairIds: {},
          answers: {},
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
          user: state.user.copyWith(activeCourseId: previousCourseId),
        );
      }
      rethrow;
    }
  }

  bool canStartLesson(String lessonId) => state.lessons.any(
    (l) => l.id == lessonId && l.status != LessonStatus.locked,
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
    } catch (e) {
      // Re-throw network errors so the UI can display them and retry.
      // Do NOT silently default to true — that would accept wrong answers.
      rethrow;
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
    if (lessonId == null || state.lessonComplete) return;
    if (state.exercises.isNotEmpty &&
        state.answers.length < state.exercises.length) {
      // Guard: all exercises must have recorded answers before submitting attempt
      return;
    }
    state = state.copyWith(lessonComplete: true);

    final wordsLearned = state.exercises
        .expand((e) => e.options.where((o) => o.isDevanagari).map((o) => o.text))
        .toSet()
        .toList();

    try {
      final result = await api.submitAttempt(
        lessonId,
        state.answers.values.toList(),
      );

      final xpEarned = (result['xp_earned'] as num?)?.toInt() ?? 0;
      final correctAnswers = (result['correct_answers'] as num?)?.toInt() ?? 0;
      final totalQuestions = (result['total_questions'] as num?)?.toInt() ?? 0;

      final userRow = result['user'] as Map<String, dynamic>;
      final user = DemoUser(
        name: userRow['name'] as String,
        email: userRow['email'] as String,
        heroIndex: userRow['hero_index'] as int,
        heroClassName: userRow['hero_class_name'] as String,
        level: userRow['level'] as int,
        xp: userRow['xp'] as int,
        xpToNextLevel: userRow['xp_to_next_level'] as int,
        streak: userRow['streak'] as int,
        wordsFound: userRow['words_found'] as int,
        lessonsCompleted: userRow['lessons_completed'] as int,
        languageId: userRow['language_id'] as String,
        activeCourseId: userRow['active_course_id'] as String?,
        languageName: state.user.languageName,
        languageScript: state.user.languageScript,
      );

      final lessons = await api.lessons(courseId: user.activeCourseId);
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
