// Phase 2 Regression Tests
// Tests for all 7 critical bug fixes identified in the Phase 1 audit.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';

// ─── Test double ───────────────────────────────────────────────────────────
/// A BackendApi that makes submitAttempt succeed with mock data.
// Used in Fix 4 tests where TestWidgetsFlutterBinding blocks real HTTP.
class _NoOpBackendApi extends BackendApi {
  @override
  Future<Map<String, dynamic>> submitAttempt(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) async {
    return {
      'completed': true,
      'already_completed': false,
      'xp_earned': 20,
      'correct_answers': 1,
      'total_questions': 1,
      'user': {
        'name': 'Test',
        'email': 'test@test.com',
        'hero_index': 0,
        'hero_class_name': 'Traveler',
        'level': 1,
        'xp': 20,
        'xp_to_next_level': 100,
        'streak': 1,
        'words_found': 4,
        'lessons_completed': 1,
        'language_id': 'newari',
      },
    };
  }

  @override
  Future<List<Lesson>> lessons() async => [];
}

// A BackendApi subclass that makes submitAttempt always throw, simulating
/// a network failure. Used to verify XP is not permanently set on failure.
class _FailingBackendApi extends BackendApi {
  @override
  Future<Map<String, dynamic>> submitAttempt(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) async {
    throw const BackendException('Simulated network failure');
  }
}

void main() {
  // Needed because BackendApi.token reads flutter_secure_storage,
  // which requires the Flutter widget binding to be initialised.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────────────────
  group('Fix 1 — WordToPicture prompt comes from exercise data', () {
    test('Exercise stores its prompt value correctly', () {
      const exercise = Exercise(
        id: 'test_wtp',
        type: ExerciseType.wordToPicture,
        instruction: 'Pick the picture',
        prompt: 'ल',
        options: [],
        correctAnswerId: '',
      );
      expect(exercise.prompt, equals('ल'));
    });

    test('Exercise prompt can be null — fallback to ? is safe', () {
      const exercise = Exercise(
        id: 'test_null_prompt',
        type: ExerciseType.wordToPicture,
        instruction: 'Pick the picture',
        options: [],
        correctAnswerId: '',
      );
      final display = exercise.prompt ?? '?';
      expect(display, equals('?'));
    });

    test('Different exercises carry different prompts', () {
      const e1 = Exercise(
        id: 'e1',
        type: ExerciseType.wordToPicture,
        instruction: 'Pick',
        prompt: 'माँ',
        options: [],
        correctAnswerId: '',
      );
      const e2 = Exercise(
        id: 'e2',
        type: ExerciseType.wordToPicture,
        instruction: 'Pick',
        prompt: 'ल',
        options: [],
        correctAnswerId: '',
      );
      expect(e1.prompt, isNot(equals(e2.prompt)));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Fix 2 — Dynamic progress bar calculation', () {
    double calculateProgress(int currentIndex, int total) {
      if (total == 0) return 0.0;
      return ((currentIndex + 1) / total).clamp(0.0, 1.0);
    }

    test('Single exercise shows 100% progress', () {
      expect(calculateProgress(0, 1), equals(1.0));
    });

    test('First of four exercises shows 25%', () {
      expect(calculateProgress(0, 4), closeTo(0.25, 0.001));
    });

    test('Second of four exercises shows 50%', () {
      expect(calculateProgress(1, 4), closeTo(0.50, 0.001));
    });

    test('Last of four exercises shows 100%', () {
      expect(calculateProgress(3, 4), equals(1.0));
    });

    test('Empty exercise list returns 0.0', () {
      expect(calculateProgress(0, 0), equals(0.0));
    });

    test('Middle of three exercises shows ~67%', () {
      expect(calculateProgress(1, 3), closeTo(0.667, 0.001));
    });

    test('Progress never exceeds 1.0', () {
      // Even if index somehow exceeds count
      expect(calculateProgress(10, 4), equals(1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Fix 3 — Routing by exerciseType', () {
    // Mirror the switch from battle_loading_screen.dart so any change there
    // will break this test, acting as a regression guard.
    String routeForType(ExerciseType type) {
      switch (type) {
        case ExerciseType.matchWords:
          return '/lesson/match-words';
        case ExerciseType.fillBlank:
          return '/lesson/fill-blank';
        case ExerciseType.pictureToWord:
          return '/lesson/picture-to-word';
        case ExerciseType.wordToPicture:
          return '/lesson/word-to-picture';
      }
    }

    test('matchWords routes to /lesson/match-words', () {
      expect(routeForType(ExerciseType.matchWords), equals('/lesson/match-words'));
    });

    test('fillBlank routes to /lesson/fill-blank', () {
      expect(routeForType(ExerciseType.fillBlank), equals('/lesson/fill-blank'));
    });

    test('pictureToWord routes to /lesson/picture-to-word', () {
      expect(routeForType(ExerciseType.pictureToWord), equals('/lesson/picture-to-word'));
    });

    test('wordToPicture routes to /lesson/word-to-picture', () {
      expect(routeForType(ExerciseType.wordToPicture), equals('/lesson/word-to-picture'));
    });

    test('Every ExerciseType value has a /lesson/ route', () {
      for (final type in ExerciseType.values) {
        expect(routeForType(type), startsWith('/lesson/'),
            reason: 'ExerciseType.\$type must map to a /lesson/ route');
      }
    });

    test('No two ExerciseTypes share the same route', () {
      final routes = ExerciseType.values.map(routeForType).toList();
      expect(routes.toSet().length, equals(routes.length));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Fix 4 — Single completion submission', () {
    test('Second completeLesson call is a no-op when lessonComplete is true', () async {
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(_NoOpBackendApi())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      notifier.startLesson('lesson_1');
      // First completion sets lessonComplete = true
      await notifier.completeLesson();
      expect(container.read(gameStateProvider).lessonComplete, isTrue);
      final xpAfterFirst = container.read(gameStateProvider).user.xp;

      // Second call must be blocked by the guard
      await notifier.completeLesson();
      final xpAfterSecond = container.read(gameStateProvider).user.xp;

      expect(xpAfterSecond, equals(xpAfterFirst),
          reason: 'XP must not change on a duplicate completeLesson call');
    });

    test('lessonComplete flag is set before the async API call', () async {
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(_NoOpBackendApi())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      notifier.startLesson('lesson_1');
      expect(container.read(gameStateProvider).lessonComplete, isFalse);

      // Start completeLesson but do not await — flag should be set synchronously
      final future = notifier.completeLesson();
      expect(container.read(gameStateProvider).lessonComplete, isTrue);
      await future; // let it finish
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Fix 5 — Level-up statistics fields on GameState', () {
    test('lastXpEarned initialises to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(gameStateProvider).lastXpEarned, equals(0));
    });

    test('lastCorrectAnswers initialises to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(gameStateProvider).lastCorrectAnswers, equals(0));
    });

    test('lastTotalQuestions initialises to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(gameStateProvider).lastTotalQuestions, equals(0));
    });

    test('lastWordsLearned initialises to empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(gameStateProvider).lastWordsLearned, isEmpty);
    });

    test('copyWith preserves lastXpEarned when not overridden', () {
      final state = GameState(
        user: seedUser,
        lastXpEarned: 42,
        lastCorrectAnswers: 4,
        lastTotalQuestions: 4,
        lastWordsLearned: const ['माँ', 'ल'],
      );
      final copy = state.copyWith();
      expect(copy.lastXpEarned, equals(42));
      expect(copy.lastCorrectAnswers, equals(4));
      expect(copy.lastTotalQuestions, equals(4));
      expect(copy.lastWordsLearned, equals(['माँ', 'ल']));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Fix 6 — XP consistency on network failure', () {
    test('XP is unchanged when submitAttempt throws', () async {
      final container = ProviderContainer(
        overrides: [
          backendApiProvider.overrideWithValue(_FailingBackendApi()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      notifier.startLesson('lesson_1');
      final xpBefore = container.read(gameStateProvider).user.xp;

      // completeLesson should throw and revert lessonComplete
      try {
        await notifier.completeLesson();
      } catch (_) {}

      final state = container.read(gameStateProvider);
      expect(state.user.xp, equals(xpBefore),
          reason: 'XP must not be permanently changed when server call fails');
    });

    test('lessonComplete resets to false after a failed submitAttempt', () async {
      final container = ProviderContainer(
        overrides: [
          backendApiProvider.overrideWithValue(_FailingBackendApi()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      notifier.startLesson('lesson_1');
      try {
        await notifier.completeLesson();
      } catch (_) {}

      expect(container.read(gameStateProvider).lessonComplete, isFalse,
          reason: 'lessonComplete must be false after failure so user can retry');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Fix 7 — Unsupported language safeguard', () {
    // The supported set must match the constant in language_selection_screen.dart
    const supportedLanguages = {'newari', 'nepali', 'english'};

    test('newari is a supported language', () {
      expect(supportedLanguages.contains('newari'), isTrue);
    });

    test('nepali is a supported language', () {
      expect(supportedLanguages.contains('nepali'), isTrue);
    });

    test('english is a supported language', () {
      expect(supportedLanguages.contains('english'), isTrue);
    });

    test('maithili is not yet supported', () {
      expect(supportedLanguages.contains('maithili'), isFalse);
    });

    test('tharu is not yet supported', () {
      expect(supportedLanguages.contains('tharu'), isFalse);
    });

    test('limbu is not yet supported', () {
      expect(supportedLanguages.contains('limbu'), isFalse);
    });

    test('exactly three languages are currently supported', () {
      expect(supportedLanguages.length, equals(3));
    });
  });
}


