import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/app/glossa_app.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/features/authentication/screens/login_screen.dart';
import 'package:glossa_app/features/authentication/screens/signup_screen.dart';
import 'package:glossa_app/features/onboarding/screens/splash_screen.dart';
import 'package:glossa_app/features/onboarding/screens/welcome_screen.dart';
import 'package:glossa_app/features/profile/screens/profile_screen.dart';
import 'package:glossa_app/features/town/screens/town_screen.dart';
import 'package:glossa_app/core/widgets/logo_widget.dart';
import 'package:glossa_app/shared/models/demo_user.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';

import 'support/mock_data.dart';

class _WelcomeApi extends BackendApi {
  _WelcomeApi({this.authenticated = false});

  bool authenticated;

  @override
  Future<String?> get token async => authenticated ? 'test-token' : null;

  @override
  Future<void> logout() async {
    authenticated = false;
  }

  @override
  Future<DemoUser> me() async => seedUser.copyWith(activeCourseId: 'en_new');

  @override
  Future<List<Lesson>> lessons({String? courseId}) async => mockLessons;

  @override
  Future<List<Map<String, dynamic>>> townMap(String courseId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unauthenticated startup reaches the canonical welcome screen', (
    tester,
  ) async {
    final api = _WelcomeApi();
    appRouter.go(AppRoutes.landing);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendApiProvider.overrideWithValue(api)],
        child: const GlossaApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Hear the\nlanguage of\nhome.'), findsOneWidget);
    expect(find.text('Master English\u2192Newari.'), findsNothing);
    expect(find.byType(GlossaAppIcon), findsOneWidget);
    expect(find.text('भार'), findsOneWidget);

    await tester.tap(find.text('New Game'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.ensureVisible(find.text('Continue (load save)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue (load save)'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('authenticated startup continues to Town after session restore', (
    tester,
  ) async {
    final api = _WelcomeApi(authenticated: true);
    appRouter.go(AppRoutes.splash);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendApiProvider.overrideWithValue(api)],
        child: const GlossaApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TownScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('logout returns to the same welcome screen and clears session', (
    tester,
  ) async {
    final api = _WelcomeApi(authenticated: true);
    final container = ProviderContainer(
      overrides: [backendApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).state = GameState(
      user: seedUser.copyWith(activeCourseId: 'en_new'),
      isAuthenticated: true,
      lessons: mockLessons,
      activeLessonId: 'unfinished-lesson',
      runId: 'unfinished-run',
      reviewQueue: const ['missed-exercise'],
    );
    appRouter.go(AppRoutes.profile);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GlossaApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.ensureVisible(find.text('Log Out'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Log Out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      appRouter.routeInformationProvider.value.uri.path,
      AppRoutes.welcome,
    );
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(container.read(gameStateProvider).isAuthenticated, isFalse);
    expect(container.read(gameStateProvider).activeLessonId, isNull);
    expect(container.read(gameStateProvider).runId, isNull);
    expect(container.read(gameStateProvider).reviewQueue, isEmpty);
  });

  testWidgets('welcome layout scrolls on a small viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appRouter.go(AppRoutes.welcome);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendApiProvider.overrideWithValue(_WelcomeApi())],
        child: const GlossaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Continue (load save)'));
    await tester.pumpAndSettle();
    expect(find.text('Continue (load save)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
