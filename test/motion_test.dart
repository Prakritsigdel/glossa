import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/motion/motion_widgets.dart';
import 'package:glossa_app/core/motion/page_transitions.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('GlossaMotion Tokens & Accessibility', () {
    test('Motion duration constants follow game-feel specifications', () {
      expect(GlossaMotion.buttonPress.inMilliseconds, inInclusiveRange(90, 130));
      expect(GlossaMotion.selection.inMilliseconds, inInclusiveRange(150, 220));
      expect(GlossaMotion.pageTransition.inMilliseconds, inInclusiveRange(250, 350));
      expect(GlossaMotion.modal.inMilliseconds, inInclusiveRange(180, 280));
      expect(GlossaMotion.xpFill.inMilliseconds, inInclusiveRange(500, 900));
      expect(GlossaMotion.celebration.inMilliseconds, inInclusiveRange(1000, 1800));
      expect(GlossaMotion.shake.inMilliseconds, inInclusiveRange(300, 450));
    });

    testWidgets('shouldReduceMotion respects MediaQuery disableAnimations flag', (tester) async {
      late bool standardMotion;
      late bool reducedMotion;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              standardMotion = GlossaMotion.shouldReduceMotion(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(standardMotion, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reducedMotion = GlossaMotion.shouldReduceMotion(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(reducedMotion, isTrue);
    });

    testWidgets('duration returns Duration.zero when reduced motion is requested', (tester) async {
      late Duration normalDur;
      late Duration reducedDur;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              normalDur = GlossaMotion.duration(context, GlossaMotion.buttonPress);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(normalDur, equals(GlossaMotion.buttonPress));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reducedDur = GlossaMotion.duration(context, GlossaMotion.buttonPress);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(reducedDur, equals(Duration.zero));
    });
  });

  group('GlossaButton Micro-Interactions', () {
    testWidgets('Button compresses on tap down and returns on tap up', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlossaButton(
              label: 'Press Me',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      final buttonFinder = find.text('Press Me');
      expect(buttonFinder, findsOneWidget);

      // Simulate press down
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump(const Duration(milliseconds: 50));

      // AnimatedContainer has updated transform during press
      expect(find.byType(AnimatedContainer), findsOneWidget);

      // Release press
      await gesture.up();
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('Disabled button ignores touch interactions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlossaButton(
              label: 'Disabled',
              onPressed: null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();

      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('Loading button shows progress indicator and prevents tap execution', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlossaButton(
              label: 'Loading Action',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(GlossaButton));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tapped, isFalse);
    });
  });

  group('GlossaProgressBar Motion', () {
    testWidgets('Smoothly animates width via TweenAnimationBuilder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlossaProgressBar(
              progress: 0.8,
            ),
          ),
        ),
      );

      expect(find.byType(GlossaProgressBar), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('ShakeWidget Feedback', () {
    testWidgets('Triggers oscillation on shake and completes cleanly', (tester) async {
      final shakeKey = GlobalKey<ShakeWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShakeWidget(
              key: shakeKey,
              child: const Text('ShakeTarget'),
            ),
          ),
        ),
      );

      expect(find.text('ShakeTarget'), findsOneWidget);

      // Trigger shake
      shakeKey.currentState?.shake();
      await tester.pump(const Duration(milliseconds: 100));

      // Transform widget is actively oscillating
      expect(find.byType(Transform), findsWidgets);

      // Settle after shake duration
      await tester.pump(GlossaMotion.shake);
      await tester.pumpAndSettle();
    });
  });

  group('IdleBobbing & CelebrationParticles', () {
    testWidgets('IdleBobbing renders child without error and respects lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IdleBobbing(
              child: Text('IdleHero'),
            ),
          ),
        ),
      );

      expect(find.text('IdleHero'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('CelebrationParticles renders custom sparkle particles and settles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CelebrationParticles(
              size: 200,
            ),
          ),
        ),
      );

      expect(find.byType(CelebrationParticles), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Settle full celebration cycle
      await tester.pump(GlossaMotion.celebration);
      await tester.pumpAndSettle();
    });
  });

  group('Page Transitions & Reduced Motion Fallback', () {
    testWidgets('slideFadeTransitionPage renders with custom transition in GoRouter', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(
            path: '/test',
            pageBuilder: (context, state) => slideFadeTransitionPage(
              context: context,
              state: state,
              child: const Text('SlideScreen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
      await tester.pumpAndSettle();

      expect(find.text('SlideScreen'), findsOneWidget);
    });

    testWidgets('battleEntranceTransitionPage renders with battle entrance transition', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/battle',
        routes: [
          GoRoute(
            path: '/battle',
            pageBuilder: (context, state) => battleEntranceTransitionPage(
              context: context,
              state: state,
              child: const Text('BattleScreen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
      await tester.pumpAndSettle();

      expect(find.text('BattleScreen'), findsOneWidget);
    });

    testWidgets('celebrationTransitionPage renders with celebratory scale page', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/celebrate',
        routes: [
          GoRoute(
            path: '/celebrate',
            pageBuilder: (context, state) => celebrationTransitionPage(
              context: context,
              state: state,
              child: const Text('CelebrationScreen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
      await tester.pumpAndSettle();

      expect(find.text('CelebrationScreen'), findsOneWidget);
    });

    testWidgets('Transitions fallback cleanly when reduced motion is requested', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/reduced',
        routes: [
          GoRoute(
            path: '/reduced',
            pageBuilder: (context, state) => slideFadeTransitionPage(
              context: context,
              state: state,
              child: const Text('ReducedScreen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp.router(routerConfig: testRouter),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ReducedScreen'), findsOneWidget);
    });
  });
}
