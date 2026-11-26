import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/glossa_app.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/core/widgets/bottom_nav_bar.dart';
import 'package:glossa_app/core/widgets/not_found_screen.dart';
import 'package:glossa_app/features/authentication/screens/signup_screen.dart';
import 'package:glossa_app/features/character/screens/character_selection_screen.dart';
import 'package:glossa_app/features/town/screens/town_screen.dart';
import 'package:glossa_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:glossa_app/features/profile/screens/profile_screen.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/models/demo_user.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';

import 'support/mock_data.dart';

class _NavigationApi extends BackendApi {
  bool failExerciseFetch = false;

  @override
  Future<String?> get token async => null;

  @override
  Future<DemoUser> login({
    required String email,
    required String password,
  }) async => seedUser.copyWith(activeCourseId: 'en_new');

  @override
  Future<List<Lesson>> lessons({String? courseId}) async => mockLessons;

  @override
  Future<List<Exercise>> exercises(String lessonId) async {
    if (failExerciseFetch) {
      throw const BackendException('Exercise request failed.');
    }
    return const [
      Exercise(
        id: 'navigation-exercise',
        type: ExerciseType.fillBlank,
        instruction: 'Choose the answer',
        options: [AnswerOption(id: 'answer', text: 'answer')],
      ),
    ];
  }

  @override
  Future<bool> checkAnswer(
    String lessonId,
    Map<String, dynamic> answer,
  ) async => true;
}

void main() {
  group('Step 3: Main Application Persistent Shell & Tabs', () {
    testWidgets(
      'Main shell displays persistent bottom nav bar and switches branches',
      (WidgetTester tester) async {
        await tester.pumpWidget(const ProviderScope(child: GlossaApp()));
        await tester.pumpAndSettle();

        // Navigate to /town
        appRouter.go(AppRoutes.town);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify TownScreen and GlossaBottomNavBar are present
        expect(find.byType(TownScreen), findsOneWidget);
        expect(find.byType(GlossaBottomNavBar), findsOneWidget);

        // Tap Leaderboard tab (item 1)
        await tester.tap(find.text('Leaderboard'));
        await tester.pumpAndSettle();

        expect(find.byType(LeaderboardScreen), findsOneWidget);
        expect(find.byType(TownScreen), findsNothing);
        expect(find.byType(GlossaBottomNavBar), findsOneWidget);

        // Tap Hero/Profile tab (item 2)
        await tester.tap(find.text('Hero'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.byType(LeaderboardScreen), findsNothing);
        expect(find.byType(GlossaBottomNavBar), findsOneWidget);

        // Tap Town tab (item 0)
        await tester.tap(find.text('Town'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(TownScreen), findsOneWidget);
      },
    );
  });

  group('Step 4: Onboarding Workflow & Back Navigation', () {
    testWidgets('SignupScreen has working back button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SignupScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text('New game'), findsOneWidget);
      expect(find.text('Load game'), findsOneWidget);
    });

    testWidgets(
      'CharacterSelectionScreen in onboarding mode shows Confirm button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CharacterSelectionScreen(isEditing: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Select your\ncharacter'), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);
        expect(find.text('Save changes'), findsNothing);
      },
    );
  });

  group('Step 5: Lesson Navigation & Progression Guards', () {
    test('Cannot start a locked lesson', () async {
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(_NavigationApi())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      // Lesson 3 is locked in initial state
      final canStart = notifier.canStartLesson('lesson_3');
      expect(canStart, isFalse);

      await expectLater(
        notifier.startLesson('lesson_3'),
        throwsA(isA<BackendException>()),
      );
      expect(container.read(gameStateProvider).activeLessonId, isNull);
    });

    test('Can start an unlocked lesson and reset safely', () async {
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(_NavigationApi())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      await notifier.logIn(email: 'test@test.com', password: 'pw');
      expect(notifier.canStartLesson('lesson_1'), isTrue);

      await notifier.startLesson('lesson_1');
      expect(
        container.read(gameStateProvider).activeLessonId,
        equals('lesson_1'),
      );

      notifier.resetLesson();
      expect(container.read(gameStateProvider).activeLessonId, isNull);
    });

    test('completeLesson prevents duplicate awards when called repeatedly', () async {
      // FIX 4 + FIX 6: lessonComplete flag blocks re-entry before the await.
      // XP is no longer optimistic — it only changes on server success.
      // In test environment (no server), completeLesson throws and resets the flag.
      // A second call while lessonComplete is true is a guaranteed no-op.
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(_NavigationApi())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      await notifier.logIn(email: 'test@test.com', password: 'pw');
      await notifier.startLesson('lesson_1');
      await notifier.checkAnswer(
        'navigation-exercise',
        selectedOptionId: 'answer',
      );
      final initialXp = container.read(gameStateProvider).user.xp;

      // lessonComplete is set to true synchronously before any await
      final future = notifier.completeLesson();
      expect(container.read(gameStateProvider).lessonComplete, isTrue);

      // Second call is blocked by the lessonComplete guard (no-op)
      await notifier.completeLesson();

      // First call will throw in test env (no server) and reset lessonComplete
      try {
        await future;
      } catch (_) {}

      // XP unchanged — no server confirmed it
      expect(container.read(gameStateProvider).user.xp, equals(initialXp));
    });

    test(
      'Exercise loading failure clears the active lesson and rethrows',
      () async {
        final api = _NavigationApi()..failExerciseFetch = true;
        final container = ProviderContainer(
          overrides: [backendApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(gameStateProvider.notifier);
        await notifier.logIn(email: 'test@test.com', password: 'pw');
        await expectLater(
          notifier.startLesson('lesson_1'),
          throwsA(isA<BackendException>()),
        );

        final state = container.read(gameStateProvider);
        expect(state.activeLessonId, isNull);
        expect(state.exercises, isEmpty);
        expect(state.errorMessage, contains('Exercise request failed'));
      },
    );
  });

  testWidgets('Meeting Someone reaches battle flow after exercises load', (
    tester,
  ) async {
    const lesson = Lesson(
      id: 'en_new_u1_l2',
      unitId: 1,
      sequence: 2,
      title: 'Meeting Someone',
      subtitle: 'Names and greetings',
      exerciseType: ExerciseType.dialogueComplete,
      status: LessonStatus.available,
    );
    final api = _NavigationApi();
    final container = ProviderContainer(
      overrides: [
        backendApiProvider.overrideWithValue(api),
        townMapProvider.overrideWith((ref) async => [lesson]),
      ],
    );
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).state = container
        .read(gameStateProvider)
        .copyWith(lessons: [lesson]);

    final router = GoRouter(
      initialLocation: AppRoutes.town,
      routes: [
        GoRoute(
          path: AppRoutes.town,
          builder: (context, state) => const TownScreen(),
        ),
        GoRoute(
          path: AppRoutes.battleLoading,
          builder: (context, state) =>
              const Scaffold(body: Text('Battle flow')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Meeting Someone'), findsOneWidget);
    await tester.tap(find.text('Go!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Battle flow'), findsOneWidget);
    expect(container.read(gameStateProvider).activeLessonId, 'en_new_u1_l2');
    expect(container.read(gameStateProvider).exercises, hasLength(1));
  });

  group('Step 6: Profile Editing Flow', () {
    testWidgets(
      'CharacterSelectionScreen in edit mode displays Edit Hero and Save changes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: CharacterSelectionScreen(isEditing: true)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit your\nhero'), findsOneWidget);
        expect(find.text('Save changes'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );
  });

  group('Step 2: Fallback Route / 404 Screen', () {
    testWidgets(
      'NotFoundScreen renders RPG-themed message and Return to Town button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: NotFoundScreen(uri: '/unknown-route')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lost Traveler'), findsOneWidget);
        expect(find.textContaining('Fog of Forgetting'), findsOneWidget);
        expect(find.text('Return to Town'), findsOneWidget);
      },
    );
  });
}
