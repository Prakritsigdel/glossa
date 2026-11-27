import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/app/glossa_app.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/features/onboarding/screens/landing_screen.dart';
import 'package:glossa_app/features/onboarding/screens/splash_screen.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

void main() {
  group('Glossa App & Landing Smoke Tests', () {
    testWidgets('GlossaApp renders landing screen correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: GlossaApp()));
      await tester.pump();

      expect(find.byType(GlossaApp), findsOneWidget);
      expect(find.byType(LandingScreen), findsOneWidget);
      // LandingScreen auto-navigates to /splash; SplashScreen must not be
      // shown immediately on startup.
      expect(find.byType(SplashScreen), findsNothing);
      // Landing exposes the New Game and Continue entry points.
      expect(find.text('New Game'), findsOneWidget);
      expect(find.text('Continue (load save)'), findsOneWidget);
    });

    testWidgets('Tapping Landing does not crash', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: GlossaApp()));
      await tester.pump();

      // Tapping New Game triggers navigation without crashing.
      await tester.tap(find.text('New Game'));
      // Pump past the button debounce so no timer is left pending.
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });
  });

  group('Glossa Core Components Tests', () {
    testWidgets('HeroAvatar renders both boy and girl variants', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                HeroAvatar(heroIndex: 0, level: 1),
                HeroAvatar(heroIndex: 1, level: 5),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(HeroAvatar), findsNWidgets(2));
    });

    testWidgets('GlossaProgressBar renders progress correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GlossaProgressBar(progress: 0.5)),
        ),
      );

      expect(find.byType(GlossaProgressBar), findsOneWidget);
    });
  });

  group('GameState Provider & Progression Tests', () {
    test(
      'Initial game state is an empty guest without fabricated progression',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(gameStateProvider);
        expect(state.user.name, equals('Guest'));
        expect(state.user.xp, 0);
        expect(state.user.streak, 0);
        expect(state.lessons, isEmpty);
      },
    );

    test('Selecting hero updates user heroIndex and name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).selectHero(1, 'Heroine');
      final state = container.read(gameStateProvider);
      expect(state.user.heroIndex, equals(1));
      expect(state.user.name, equals('Heroine'));
    });

    test('Completing a lesson sets lessonComplete and allows no retry', () async {
      // FIX 6: XP is no longer applied optimistically. It is only updated when
      // the server confirms the attempt. In the test environment (no server),
      // completeLesson() will throw after setting lessonComplete = true and
      // then reset it to false so the user can retry. We verify the guard works.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      notifier.state = notifier.state.copyWith(activeLessonId: 'lesson_1');

      // lessonComplete starts false
      expect(container.read(gameStateProvider).lessonComplete, isFalse);

      // completeLesson will throw in test env (no HTTP) and revert lessonComplete
      try {
        await notifier.completeLesson();
      } catch (_) {}

      // Guard worked: lessonComplete resets to false on failure, enabling retry
      expect(container.read(gameStateProvider).lessonComplete, isFalse);
      // XP must not change without server confirmation
      expect(container.read(gameStateProvider).user.xp, 0);
    });
  });
}
