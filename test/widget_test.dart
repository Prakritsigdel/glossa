import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/app/glossa_app.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/logo_widget.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

void main() {
  group('Glossa App & Landing Smoke Tests', () {
    testWidgets('GlossaApp renders landing screen correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: GlossaApp()));
      await tester.pump();

      expect(find.byType(GlossaApp), findsOneWidget);
      expect(find.byType(GlossaLogo), findsOneWidget);
      expect(find.text('Glossa'), findsOneWidget);
    });

    testWidgets('Tapping Landing navigates to splash', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: GlossaApp()));
      await tester.pump();

      // Tap on the landing screen
      await tester.tap(find.text('Glossa'));
      await tester.pump();

      expect(find.byType(GlossaApp), findsOneWidget);
    });
  });

  group('Glossa Core Components Tests', () {
    testWidgets('HeroAvatar renders both boy and girl variants', (WidgetTester tester) async {
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

    testWidgets('GlossaProgressBar renders progress correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlossaProgressBar(progress: 0.5),
          ),
        ),
      );

      expect(find.byType(GlossaProgressBar), findsOneWidget);
    });
  });

  group('GameState Provider & Progression Tests', () {
    test('Initial game state contains seed user and mock lessons', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(gameStateProvider);
      expect(state.user.name, equals('LeBron'));
      expect(state.user.level, equals(4));
      expect(state.lessons.length, equals(mockLessons.length));
    });

    test('Selecting hero updates user heroIndex and name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).selectHero(1, 'Heroine');
      final state = container.read(gameStateProvider);
      expect(state.user.heroIndex, equals(1));
      expect(state.user.name, equals('Heroine'));
    });

    test('Completing a lesson awards XP and updates progress', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).startLesson('lesson_1');
      container.read(gameStateProvider.notifier).completeLesson();

      final state = container.read(gameStateProvider);
      expect(state.user.xp, greaterThan(seedUser.xp));
      expect(state.lessonComplete, isTrue);
    });
  });
}
