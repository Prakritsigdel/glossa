import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/app/glossa_app.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/core/widgets/bottom_nav_bar.dart';
import 'package:glossa_app/core/widgets/not_found_screen.dart';
import 'package:glossa_app/features/authentication/screens/signup_screen.dart';
import 'package:glossa_app/features/character/screens/character_selection_screen.dart';
import 'package:glossa_app/features/languages/screens/language_selection_screen.dart';
import 'package:glossa_app/features/town/screens/town_screen.dart';
import 'package:glossa_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:glossa_app/features/profile/screens/profile_screen.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

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
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      // Lesson 3 is locked in initial state
      final canStart = notifier.canStartLesson('lesson_3');
      expect(canStart, isFalse);

      notifier.startLesson('lesson_3');
      expect(container.read(gameStateProvider).activeLessonId, isNull);
    });

    test('Can start an unlocked lesson and reset safely', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      expect(notifier.canStartLesson('lesson_1'), isTrue);

      notifier.startLesson('lesson_1');
      expect(container.read(gameStateProvider).activeLessonId, equals('lesson_1'));

      notifier.resetLesson();
      expect(container.read(gameStateProvider).activeLessonId, isNull);
    });

    test('completeLesson prevents duplicate XP awards when called repeatedly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      notifier.startLesson('lesson_1');
      final initialXp = container.read(gameStateProvider).user.xp;

      // First completion
      notifier.completeLesson();
      final xpAfterFirst = container.read(gameStateProvider).user.xp;
      expect(xpAfterFirst, equals(initialXp + 20));
      expect(container.read(gameStateProvider).lessonComplete, isTrue);

      // Second completion call should be guarded and ignored
      notifier.completeLesson();
      final xpAfterSecond = container.read(gameStateProvider).user.xp;
      expect(xpAfterSecond, equals(xpAfterFirst));
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

    testWidgets('LanguageSelectionScreen in edit mode displays Change Language and Save language',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LanguageSelectionScreen(isEditing: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Change target\nlanguage'), findsOneWidget);
      expect(find.text('Save language'), findsOneWidget);
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
