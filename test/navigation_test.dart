import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  Future<String?> get token async => null;

  @override
  Future<DemoUser> login({required String email, required String password}) async =>
      seedUser.copyWith(activeCourseId: 'en_new');

  @override
  Future<List<Lesson>> lessons({String? courseId}) async => mockLessons;
}

void main() {
  group('Step 3: Main Application Persistent Shell & Tabs', () {
    testWidgets('Main shell displays persistent bottom nav bar and switches branches',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: GlossaApp()));
      await tester.pumpAndSettle();

      // Navigate to /town
      appRouter.go(AppRoutes.town);
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(LeaderboardScreen), findsNothing);
      expect(find.byType(GlossaBottomNavBar), findsOneWidget);

      // Tap Town tab (item 0)
      await tester.tap(find.text('Town'));
      await tester.pumpAndSettle();

      expect(find.byType(TownScreen), findsOneWidget);
    });
  });

  group('Step 4: Onboarding Workflow & Back Navigation', () {
    testWidgets('SignupScreen has working back button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text('New game'), findsOneWidget);
      expect(find.text('Load game'), findsOneWidget);
    });

    testWidgets('CharacterSelectionScreen in onboarding mode shows Confirm button',
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
    });
  });

  group('Step 5: Lesson Navigation & Progression Guards', () {
    test('Cannot start a locked lesson', () {
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(_NavigationApi())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      // Lesson 3 is locked in initial state
      final canStart = notifier.canStartLesson('lesson_3');
      expect(canStart, isFalse);

      notifier.startLesson('lesson_3');
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

      notifier.startLesson('lesson_1');
      expect(container.read(gameStateProvider).activeLessonId, equals('lesson_1'));

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
      notifier.startLesson('lesson_1');
      final initialXp = container.read(gameStateProvider).user.xp;

      // lessonComplete is set to true synchronously before any await
      final future = notifier.completeLesson();
      expect(container.read(gameStateProvider).lessonComplete, isTrue);

      // Second call is blocked by the lessonComplete guard (no-op)
      await notifier.completeLesson();

      // First call will throw in test env (no server) and reset lessonComplete
      try { await future; } catch (_) {}

      // XP unchanged — no server confirmed it
      expect(container.read(gameStateProvider).user.xp, equals(initialXp));
    });
  });

  group('Step 6: Profile Editing Flow', () {
    testWidgets('CharacterSelectionScreen in edit mode displays Edit Hero and Save changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CharacterSelectionScreen(isEditing: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit your\nhero'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('Step 2: Fallback Route / 404 Screen', () {
    testWidgets('NotFoundScreen renders RPG-themed message and Return to Town button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotFoundScreen(uri: '/unknown-route'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lost Traveler'), findsOneWidget);
      expect(find.textContaining('Fog of Forgetting'), findsOneWidget);
      expect(find.text('Return to Town'), findsOneWidget);
    });
  });
}
