// Auth & Button State Management Regression Tests
//
// Verifies:
// 1. GlossaButton disables during async processing and displays loadingLabel + spinner.
// 2. Rapid repeated taps on GlossaButton trigger the callback only once.
// 3. GlossaButton recovers enabled state after an error (try/finally).
// 4. SignupScreen prevents duplicate registrations on rapid taps.
// 5. LoginScreen prevents duplicate logins on rapid taps.
// 6. GameStateNotifier session restoration and logout.
// 7. Backend attempt submission idempotency.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/models/demo_user.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';
import 'package:glossa_app/features/authentication/screens/login_screen.dart';
import 'package:glossa_app/features/authentication/screens/signup_screen.dart';

class _MockApi extends BackendApi {
  int registerCallCount = 0;
  int loginCallCount = 0;
  int submitAttemptCallCount = 0;
  bool shouldFail = false;
  Completer<DemoUser>? authCompleter;

  String? storedToken;

  @override
  Future<String?> get token async => storedToken;

  @override
  Future<DemoUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    registerCallCount++;
    storedToken = 'mock_token';
    if (shouldFail) throw const BackendException('Registration failed');
    if (authCompleter != null) return authCompleter!.future;
    return seedUser.copyWith(name: name, email: email, activeCourseId: 'en_ne');
  }

  @override
  Future<DemoUser> login({
    required String email,
    required String password,
  }) async {
    loginCallCount++;
    storedToken = 'mock_token';
    if (shouldFail) throw const BackendException('Invalid email or password');
    if (authCompleter != null) return authCompleter!.future;
    return seedUser.copyWith(email: email, activeCourseId: 'en_ne');
  }

  @override
  Future<DemoUser> me() async => seedUser.copyWith(activeCourseId: 'en_ne');

  @override
  Future<void> logout() async {
    storedToken = null;
  }

  @override
  Future<List<Language>> getLanguages() async => [];

  @override
  Future<List<Course>> getCourses({bool publishedOnly = true}) async => [];

  @override
  Future<List<CourseUnit>> getUnitsForCourse(String courseId) async => [];

  @override
  Future<List<Lesson>> lessons({String? courseId}) async => mockLessons;

  @override
  Future<Map<String, dynamic>> submitAttempt(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) async {
    submitAttemptCallCount++;
    return {
      'completed': true,
      'already_completed': submitAttemptCallCount > 1,
      'xp_earned': submitAttemptCallCount > 1 ? 0 : 20,
      'correct_answers': 1,
      'total_questions': 1,
      'user': {
        'name': 'Player',
        'email': 'p@glossa.dev',
        'hero_index': 0,
        'hero_class_name': 'Traveler',
        'level': 1,
        'xp': 20,
        'xp_to_next_level': 100,
        'streak': 1,
        'words_found': 4,
        'lessons_completed': 1,
        'language_id': 'newari',
        'active_course_id': 'en_ne',
      },
    };
  }
}

void main() {
  group('GlossaButton Async & Loading State Management', () {
    testWidgets('GlossaButton immediately disables and shows loadingLabel during async execution',
        (tester) async {
      final completer = Completer<void>();
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlossaButton(
              label: 'Submit',
              loadingLabel: 'Processing...',
              onPressed: () async {
                callCount++;
                await completer.future;
              },
            ),
          ),
        ),
      );

      // Initially shows 'Submit'
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Processing...'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tap button once
      await tester.tap(find.byType(GlossaButton));
      await tester.pump();

      // Now processing: label changed to 'Processing...', spinner is shown
      expect(find.text('Processing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(callCount, 1);

      // Rapidly tap again while processing — should NOT trigger another call
      await tester.tap(find.byType(GlossaButton));
      await tester.pump();
      await tester.tap(find.byType(GlossaButton));
      await tester.pump();
      expect(callCount, 1);

      // Finish the async operation
      completer.complete();
      await tester.pumpAndSettle();

      // Restored: label is 'Submit', spinner is gone
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Processing...'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('GlossaButton recovers enabled state and allows retry after error (try/finally)',
        (tester) async {
      var callCount = 0;
      var shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlossaButton(
              label: 'Action',
              loadingLabel: 'Loading...',
              onPressed: () async {
                callCount++;
                if (shouldThrow) {
                  throw Exception('Network error');
                }
              },
            ),
          ),
        ),
      );

      // Tap — throws an error
      await tester.tap(find.byType(GlossaButton));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      // Button must be restored to enabled so user can retry
      expect(find.text('Action'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Now succeed on retry
      shouldThrow = false;
      await tester.tap(find.byType(GlossaButton));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(find.text('Action'), findsOneWidget);
    });
  });

  group('Authentication Flow & Idempotency', () {
    testWidgets('SignupScreen disables button and shows Creating account... during registration',
        (tester) async {
      final mockApi = _MockApi();
      final completer = Completer<DemoUser>();
      mockApi.authCompleter = completer;

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [backendApiProvider.overrideWithValue(mockApi)],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Fill in valid registration details
      final nameField = find.byType(TextFormField).at(0);
      final emailField = find.byType(TextFormField).at(1);
      final passField = find.byType(TextFormField).at(2);

      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@glossa.dev');
      await tester.enterText(passField, 'Password123!');
      await tester.pumpAndSettle();

      // Accept terms
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap 'Start adventure'
      final buttonFinder = find.widgetWithText(GlossaButton, 'Start adventure');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();

      // Verifies: button disabled and shows 'Creating account...'
      expect(find.text('Creating account...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(mockApi.registerCallCount, 1);

      // Rapidly tap again — must NOT duplicate registration
      await tester.tap(find.byType(GlossaButton).first);
      await tester.pump();
      expect(mockApi.registerCallCount, 1);

      // Complete the request
      completer.complete(seedUser.copyWith(name: 'Test User'));
      await tester.pump();
    });

    testWidgets('LoginScreen disables button and shows Loading save file... during login',
        (tester) async {
      final mockApi = _MockApi();
      final completer = Completer<DemoUser>();
      mockApi.authCompleter = completer;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [backendApiProvider.overrideWithValue(mockApi)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final emailField = find.byType(TextFormField).at(0);
      final passField = find.byType(TextFormField).at(1);

      await tester.enterText(emailField, 'test@glossa.dev');
      await tester.enterText(passField, 'Password123!');
      await tester.pumpAndSettle();

      // Tap 'Load game'
      await tester.tap(find.widgetWithText(GlossaButton, 'Load game'));
      await tester.pump();

      expect(find.text('Loading save file...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(mockApi.loginCallCount, 1);

      // Rapid second tap
      await tester.tap(find.byType(GlossaButton).first);
      await tester.pump();
      expect(mockApi.loginCallCount, 1);

      completer.complete(seedUser);
      await tester.pump();
    });

    testWidgets('Session logout resets authentication state in GameStateNotifier',
        (tester) async {
      final mockApi = _MockApi();
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(mockApi)],
      );

      final notifier = container.read(gameStateProvider.notifier);
      await notifier.logIn(email: 'user@glossa.dev', password: 'password123');

      expect(container.read(gameStateProvider).isAuthenticated, true);

      // Perform logout
      await notifier.logOut();

      expect(container.read(gameStateProvider).isAuthenticated, false);
      expect(container.read(gameStateProvider).user.email, seedUser.email);
    });

    testWidgets('Repeated completeLesson calls are idempotent and do not grant duplicate XP',
        (tester) async {
      final mockApi = _MockApi();
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(mockApi)],
      );

      final notifier = container.read(gameStateProvider.notifier);
      await notifier.startLesson('lesson_1');

      // First completion
      await notifier.completeLesson();
      expect(mockApi.submitAttemptCallCount, 1);
      final xpAfterFirst = container.read(gameStateProvider).user.xp;

      // Second completion attempt on the same completed lesson
      await notifier.completeLesson();
      expect(mockApi.submitAttemptCallCount, 1); // Guard prevented re-submission!
      expect(container.read(gameStateProvider).user.xp, xpAfterFirst);
    });
  });
}
