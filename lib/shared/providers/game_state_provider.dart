import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/demo_user.dart';
import '../models/course_models.dart';
import '../mock_data/mock_data.dart';

/// Central game state that tracks the demo user, selections, and progress.
class GameState {
  final DemoUser user;
  final bool isAuthenticated;
  final List<Lesson> lessons;
  final String? activeLessonId;
  final int currentExerciseIndex;
  final int correctAnswersInLesson;
  final bool lessonComplete;
  final Set<String> matchedPairIds;

  const GameState({
    required this.user,
    this.isAuthenticated = false,
    this.lessons = const [],
    this.activeLessonId,
    this.currentExerciseIndex = 0,
    this.correctAnswersInLesson = 0,
    this.lessonComplete = false,
    this.matchedPairIds = const {},
  });

  GameState copyWith({
    DemoUser? user,
    bool? isAuthenticated,
    List<Lesson>? lessons,
    String? activeLessonId,
    bool clearActiveLesson = false,
    int? currentExerciseIndex,
    int? correctAnswersInLesson,
    bool? lessonComplete,
    Set<String>? matchedPairIds,
  }) {
    return GameState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      lessons: lessons ?? this.lessons,
      activeLessonId: clearActiveLesson ? null : (activeLessonId ?? this.activeLessonId),
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      correctAnswersInLesson: correctAnswersInLesson ?? this.correctAnswersInLesson,
      lessonComplete: lessonComplete ?? this.lessonComplete,
      matchedPairIds: matchedPairIds ?? this.matchedPairIds,
    );
  }
}

class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier()
      : super(GameState(
          user: seedUser,
          lessons: mockLessons,
          isAuthenticated: true, // Default to demo user LeBron authenticated
        ));

  // ─── Auth ─────────────────────────────────────────────────
  void signUp({required String name, required String email, required int heroIndex}) {
    state = state.copyWith(
      user: state.user.copyWith(
        name: name,
        email: email,
        heroIndex: heroIndex,
        level: 1,
        xp: 0,
        xpToNextLevel: 100,
        streak: 0,
        wordsFound: 0,
        lessonsCompleted: 0,
      ),
      isAuthenticated: true,
      lessons: mockLessons.map((l) {
        if (l.status == LessonStatus.cleared) {
          return l.copyWith(status: LessonStatus.current);
        }
        return l;
      }).toList(),
    );
  }

  void logIn() {
    state = state.copyWith(
      user: seedUser,
      isAuthenticated: true,
      lessons: mockLessons,
    );
  }

  void logOut() {
    state = state.copyWith(
      isAuthenticated: false,
      clearActiveLesson: true,
      lessonComplete: false,
    );
  }

  // ─── Character & language ─────────────────────────────────
  void selectHero(int index, String name) {
    state = state.copyWith(
      user: state.user.copyWith(heroIndex: index, name: name),
    );
  }

  void selectLanguage(String id, String name, String script) {
    state = state.copyWith(
      user: state.user.copyWith(
        languageId: id,
        languageName: name,
        languageScript: script,
      ),
    );
  }

  // ─── Lessons ──────────────────────────────────────────────
  bool canStartLesson(String lessonId) {
    final lesson = state.lessons.cast<Lesson?>().firstWhere(
          (l) => l?.id == lessonId,
          orElse: () => null,
        );
    if (lesson == null) return false;
    return lesson.status != LessonStatus.locked;
  }

  void startLesson(String lessonId) {
    if (!canStartLesson(lessonId)) return;
    state = state.copyWith(
      activeLessonId: lessonId,
      currentExerciseIndex: 0,
      correctAnswersInLesson: 0,
      lessonComplete: false,
      matchedPairIds: {},
    );
  }

  void recordCorrectAnswer() {
    state = state.copyWith(
      correctAnswersInLesson: state.correctAnswersInLesson + 1,
    );
  }

  void addMatchedPair(String devanagariId, String englishId) {
    state = state.copyWith(
      matchedPairIds: {...state.matchedPairIds, devanagariId, englishId},
    );
  }

  void nextExercise() {
    state = state.copyWith(
      currentExerciseIndex: state.currentExerciseIndex + 1,
    );
  }

  void completeLesson() {
    final lessonId = state.activeLessonId;
    if (lessonId == null) return;
    // Guard against duplicate XP and multiple completion calls
    if (state.lessonComplete) return;

    final xpEarned = 20;
    final newXp = state.user.xp + xpEarned;
    final newWordsFound = state.user.wordsFound + 4;
    final newLessonsCompleted = state.user.lessonsCompleted + 1;

    // Check level up
    var newLevel = state.user.level;
    var newXpToNext = state.user.xpToNextLevel;
    if (newXp >= state.user.xpToNextLevel) {
      newLevel += 1;
      newXpToNext = newLevel * 150; // Simple scaling
    }

    // Update lesson statuses
    final updatedLessons = state.lessons.map((l) {
      if (l.id == lessonId) {
        return l.copyWith(status: LessonStatus.cleared);
      }
      // Unlock next lesson
      if (l.status == LessonStatus.locked && l.requiredLevel <= newLevel) {
        final currentIndex = state.lessons.indexWhere((x) => x.id == lessonId);
        final thisIndex = state.lessons.indexOf(l);
        if (thisIndex == currentIndex + 1) {
          return l.copyWith(status: LessonStatus.current);
        }
      }
      return l;
    }).toList();

    state = state.copyWith(
      user: state.user.copyWith(
        xp: newXp,
        xpToNextLevel: newXpToNext,
        level: newLevel,
        wordsFound: newWordsFound,
        lessonsCompleted: newLessonsCompleted,
        heroClassName: state.user.copyWith(level: newLevel).levelTitle,
      ),
      lessons: updatedLessons,
      lessonComplete: true,
    );
  }

  void resetLesson() {
    state = state.copyWith(
      clearActiveLesson: true,
      currentExerciseIndex: 0,
      correctAnswersInLesson: 0,
      lessonComplete: false,
      matchedPairIds: {},
    );
  }
}

/// The central game state provider.
final gameStateProvider =
    StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  return GameStateNotifier();
});
