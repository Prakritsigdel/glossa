import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/features/progression/screens/level_up_screen.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/models/demo_user.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';

class _Stage6Api extends BackendApi {
  DemoUser accountA = _user('a', xp: 400, streak: 8, lessons: 12);
  DemoUser accountB = _user('b');
  DemoUser? currentUser;
  List<Lesson> accountALessons = [_lesson('a-lesson', LessonStatus.completed)];
  List<Lesson> accountBLessons = [_lesson('b-lesson', LessonStatus.available)];
  List<Exercise> exercisesForLesson = const [
    Exercise(
      id: 'e1',
      type: ExerciseType.fillBlank,
      instruction: 'choose',
      options: [AnswerOption(id: 'yes', text: 'yes')],
    ),
  ];
  final List<String?> submittedKeys = [];
  final List<List<Map<String, dynamic>>> submittedAnswers = [];
  int submissionCount = 0;
  bool failFirstSubmission = false;
  bool submissionPassed = true;
  List<Map<String, dynamic>> townRows = [];
  Completer<List<Map<String, dynamic>>>? pendingTownMap;
  Completer<DemoUser>? pendingAccountALogin;
  String? storedToken;
  int townCalls = 0;
  int runCount = 0;

  @override
  Future<String?> get token async => storedToken;

  @override
  Future<DemoUser> login({
    required String email,
    required String password,
  }) async {
    storedToken = 'token-${email.substring(0, 1)}';
    final user = email.startsWith('b') ? accountB : accountA;
    if (email.startsWith('a') && pendingAccountALogin != null) {
      return pendingAccountALogin!.future;
    }
    return currentUser = user;
  }

  @override
  Future<DemoUser> me() async => currentUser ?? accountA;

  @override
  Future<void> logout() async {
    storedToken = null;
  }

  @override
  Future<List<Lesson>> lessons({String? courseId}) async =>
      currentUser?.id == 'b' ? accountBLessons : accountALessons;

  @override
  Future<List<Exercise>> exercises(String lessonId) async => exercisesForLesson;

  @override
  Future<Map<String, dynamic>> startLessonRun(String lessonId) async => {
    'run_id': 'stage6-run-${runCount++}',
    'answered_exercise_ids': <String>[],
    'original_results': <String, bool>{},
    'review_queue': <String>[],
    'corrected_exercise_ids': <String>[],
    'matched_pairs_by_exercise': <String, dynamic>{},
    'needs_completion': false,
  };

  @override
  Future<Map<String, dynamic>> reviewQueue(
    String lessonId,
    String runId,
  ) async => {'review_queue': <String>[], 'corrected_exercise_ids': <String>[]};

  @override
  Future<bool> checkAnswer(
    String lessonId,
    Map<String, dynamic> answer,
  ) async => true;

  @override
  Future<Map<String, dynamic>> submitAttempt(
    String lessonId, {
    required List<Map<String, dynamic>> answers,
    String? idempotencyKey,
  }) async {
    submissionCount++;
    submittedKeys.add(idempotencyKey);
    submittedAnswers.add(answers.map(Map<String, dynamic>.from).toList());
    if (failFirstSubmission && submissionCount == 1) {
      throw const BackendException('Request timed out');
    }
    return {
      'xp_earned': 20,
      'correct_answers': 1,
      'total_questions': 1,
      'passed': submissionPassed,
      'score': submissionPassed ? 1.0 : 0.6,
      'passing_threshold': 80,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> townMap(String courseId) async {
    townCalls++;
    final pending = pendingTownMap;
    if (pending != null) {
      pendingTownMap = null;
      return pending.future;
    }
    return townRows;
  }
}

DemoUser _user(String id, {int xp = 0, int streak = 0, int lessons = 0}) =>
    DemoUser(
      id: id,
      name: 'User $id',
      email: '$id@example.test',
      xp: xp,
      streak: streak,
      lessonsCompleted: lessons,
      level: xp ~/ 100 + 1,
      activeCourseId: 'en_new',
    );

Lesson _lesson(String id, LessonStatus status, {bool checkpoint = false}) =>
    Lesson(
      id: id,
      title: id,
      subtitle: '',
      exerciseType: ExerciseType.fillBlank,
      status: status,
      isCheckpoint: checkpoint,
      availability: status.name,
    );

Map<String, dynamic> _townRow(String id, String availability) => {
  'id': id,
  'unit_sequence': 1,
  'sequence': 1,
  'title': id,
  'subtitle': '',
  'exercise_type': 'fillBlank',
  'availability': availability,
  'xp_reward': 20,
  'word_count': 1,
  'required_level': 1,
  'is_published': availability != 'unavailable',
  'is_checkpoint': false,
  'is_capstone': false,
  'planned_exercise_count': 1,
  'populated_exercise_count': 1,
};

void main() {
  late _Stage6Api api;
  late ProviderContainer container;
  late GameStateNotifier notifier;

  setUp(() {
    api = _Stage6Api();
    container = ProviderContainer(
      overrides: [backendApiProvider.overrideWithValue(api)],
    );
    notifier = container.read(gameStateProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
    'account switching replaces the previous user and progression',
    () async {
      await notifier.logIn(email: 'a@example.test', password: 'pw');
      expect(container.read(gameStateProvider).user.xp, 400);
      expect(container.read(gameStateProvider).lessons.single.id, 'a-lesson');

      await notifier.logIn(email: 'b@example.test', password: 'pw');
      final state = container.read(gameStateProvider);
      expect(state.user.id, 'b');
      expect(state.user.xp, 0);
      expect(state.user.streak, 0);
      expect(state.user.lessonsCompleted, 0);
      expect(state.lessons.map((lesson) => lesson.id), ['b-lesson']);
    },
  );

  test(
    'a delayed response from the previous account cannot replace the new one',
    () async {
      final oldLogin = Completer<DemoUser>();
      api.pendingAccountALogin = oldLogin;

      final staleLogin = notifier.logIn(
        email: 'a@example.test',
        password: 'pw',
      );
      await Future<void>.delayed(Duration.zero);
      await notifier.logIn(email: 'b@example.test', password: 'pw');
      oldLogin.complete(api.accountA);
      await staleLogin;

      final state = container.read(gameStateProvider);
      expect(state.user.id, 'b');
      expect(state.user.xp, 0);
      expect(state.lessons.map((lesson) => lesson.id), ['b-lesson']);
    },
  );

  test(
    'town map ignores a delayed account response after switching sessions',
    () async {
      await notifier.logIn(email: 'a@example.test', password: 'pw');
      final staleMap = Completer<List<Map<String, dynamic>>>();
      api.pendingTownMap = staleMap;
      final oldMap = container.read(townMapProvider.future);
      await Future<void>.delayed(Duration.zero);

      api.townRows = [_townRow('b-lesson', 'available')];
      await notifier.logIn(email: 'b@example.test', password: 'pw');
      expect(
        (await container.read(townMapProvider.future))
            .map((lesson) => lesson.id),
        ['b-lesson'],
      );

      staleMap.complete([_townRow('a-lesson', 'completed')]);
      await oldMap;
      expect(
        (await container.read(townMapProvider.future))
            .map((lesson) => lesson.id),
        ['b-lesson'],
      );
    },
  );

  test(
    'a restarted provider restores only the currently authenticated account',
    () async {
      await notifier.logIn(email: 'b@example.test', password: 'pw');
      final restartedContainer = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(api)],
      );
      addTearDown(restartedContainer.dispose);

      final restartedNotifier = restartedContainer.read(
        gameStateProvider.notifier,
      );
      await restartedNotifier.restoreSession();

      expect(restartedContainer.read(gameStateProvider).user.id, 'b');
      expect(restartedContainer.read(gameStateProvider).user.xp, 0);
      expect(
        restartedContainer
            .read(gameStateProvider)
            .lessons
            .map((lesson) => lesson.id),
        ['b-lesson'],
      );
    },
  );

  test(
    'logout clears protected user, lesson, answer, and submission state',
    () async {
      await notifier.logIn(email: 'a@example.test', password: 'pw');
      await notifier.startLesson('a-lesson');
      await notifier.checkAnswer('e1', selectedOptionId: 'yes');
      await notifier.completeLesson(idempotencyKey: 'logout-key');
      await notifier.logOut();
      final state = container.read(gameStateProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.user.id, isNot('a'));
      expect(state.user.xp, 0);
      expect(state.user.streak, 0);
      expect(state.user.lessonsCompleted, 0);
      expect(state.exercises, isEmpty);
      expect(state.answers, isEmpty);
      expect(state.lessonComplete, isFalse);
      expect(state.lastXpEarned, 0);
    },
  );

  test('submission timeout preserves answers for retry', () async {
    api.failFirstSubmission = true;
    await notifier.logIn(email: 'a@example.test', password: 'pw');
    await notifier.startLesson('a-lesson');
    await notifier.checkAnswer('e1', selectedOptionId: 'yes');
    await expectLater(
      () => notifier.completeLesson(idempotencyKey: 'stable-key'),
      throwsA(isA<BackendException>()),
    );
    expect(container.read(gameStateProvider).answers, contains('e1'));
    expect(container.read(gameStateProvider).lessonComplete, isFalse);
    await notifier.completeLesson(idempotencyKey: 'stable-key');
    expect(api.submittedAnswers, [
      <Map<String, dynamic>>[],
      <Map<String, dynamic>>[],
    ]);
    expect(container.read(gameStateProvider).answers, contains('e1'));
  });

  test('submission retry reuses the original idempotency key', () async {
    api.failFirstSubmission = true;
    await notifier.logIn(email: 'a@example.test', password: 'pw');
    await notifier.startLesson('a-lesson');
    await notifier.checkAnswer('e1', selectedOptionId: 'yes');
    await expectLater(
      () => notifier.completeLesson(idempotencyKey: 'stable-key'),
      throwsA(isA<BackendException>()),
    );
    await notifier.completeLesson(idempotencyKey: 'stable-key');
    expect(api.submittedKeys, ['stable-key', 'stable-key']);
  });

  test(
    'failed checkpoint result remains retryable without discarding answers',
    () async {
      api.submissionPassed = false;
      api.accountALessons = [
        _lesson('checkpoint', LessonStatus.available, checkpoint: true),
      ];
      await notifier.logIn(email: 'a@example.test', password: 'pw');
      await notifier.startLesson('checkpoint');
      await notifier.checkAnswer('e1', selectedOptionId: 'yes');
      await notifier.completeLesson(idempotencyKey: 'checkpoint-key');
      expect(container.read(gameStateProvider).answers, isNotEmpty);
      expect(container.read(gameStateProvider).lessonComplete, isTrue);
      expect(container.read(gameStateProvider).lastPassed, isFalse);
    },
  );

  testWidgets('failed checkpoint Retry lesson action restarts the checkpoint', (
    tester,
  ) async {
    api.accountALessons = [
      _lesson('checkpoint', LessonStatus.available, checkpoint: true),
    ];
    api.submissionPassed = false;
    await notifier.logIn(email: 'a@example.test', password: 'pw');
    await notifier.startLesson('checkpoint');
    await notifier.checkAnswer('e1', selectedOptionId: 'yes');
    await notifier.completeLesson(idempotencyKey: 'checkpoint-fail');
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(path: '/result', builder: (_, _) => const LevelUpScreen()),
        GoRoute(
          path: '/battle-loading',
          builder: (_, _) => const Scaffold(body: Text('Battle loading route')),
        ),
        GoRoute(
          path: '/town',
          builder: (_, _) => const Scaffold(body: Text('Town route')),
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
    await tester.pumpAndSettle();
    expect(find.text('CHECKPOINT NOT PASSED'), findsOneWidget);
    await tester.ensureVisible(find.text('Retry Lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry Lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Battle loading route'), findsOneWidget);
    expect(container.read(gameStateProvider).activeLessonId, 'checkpoint');
    expect(container.read(gameStateProvider).exercises, isNotEmpty);
  });

  testWidgets(
    'successful checkpoint Continue action returns to town and clears lesson state',
    (tester) async {
      api.accountALessons = [
        _lesson('checkpoint', LessonStatus.available, checkpoint: true),
      ];
      await notifier.logIn(email: 'a@example.test', password: 'pw');
      await notifier.startLesson('checkpoint');
      await notifier.checkAnswer('e1', selectedOptionId: 'yes');
      await notifier.completeLesson(idempotencyKey: 'checkpoint-pass');
      final router = GoRouter(
        initialLocation: '/result',
        routes: [
          GoRoute(path: '/result', builder: (_, _) => const LevelUpScreen()),
          GoRoute(
            path: '/battle-loading',
            builder: (_, _) =>
                const Scaffold(body: Text('Battle loading route')),
          ),
          GoRoute(
            path: '/town',
            builder: (_, _) => const Scaffold(body: Text('Town route')),
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
      await tester.pumpAndSettle();
      expect(find.text('CHECKPOINT PASSED'), findsOneWidget);
      expect(find.text('Words learned'), findsNothing);
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Town route'), findsOneWidget);
      expect(container.read(gameStateProvider).activeLessonId, isNull);
      expect(container.read(gameStateProvider).answers, isEmpty);
    },
  );

  test('successful checkpoint completion refreshes lessons and exposes newly unlocked lesson', () async {
    api.accountALessons = [
      _lesson('checkpoint', LessonStatus.available, checkpoint: true),
    ];
    await notifier.logIn(email: 'a@example.test', password: 'pw');
    await notifier.startLesson('checkpoint');
    await notifier.checkAnswer('e1', selectedOptionId: 'yes');
    api.accountALessons = [_lesson('next', LessonStatus.available)];
    await notifier.completeLesson(idempotencyKey: 'checkpoint-success');
    expect(container.read(gameStateProvider).lastPassed, isTrue);
    expect(container.read(gameStateProvider).lessons.map((l) => l.id), [
      'next',
    ]);
  });

  test(
    'town refresh fetches the updated map after successful completion',
    () async {
      api.townRows = [_townRow('one', 'available'), _townRow('two', 'locked')];
      await container.read(townMapProvider.future);
      api.townRows = [
        _townRow('one', 'completed'),
        _townRow('two', 'available'),
      ];
      container.invalidate(townMapProvider);
      final refreshed = await container.read(townMapProvider.future);
      expect(api.townCalls, 2);
      expect(refreshed.last.availability, 'available');
    },
  );

  test('town map marks a newly unlocked lesson available', () async {
    api.townRows = [_townRow('newly-unlocked', 'available')];
    final lessons = await container.read(townMapProvider.future);
    expect(lessons.single.status, LessonStatus.available);
    expect(lessons.single.availability, 'available');
  });

  test(
    'zero published lessons returns empty data without mock fallback',
    () async {
      api.townRows = [];
      final lessons = await container.read(townMapProvider.future);
      expect(lessons, isEmpty);
      expect(api.townCalls, 1);
    },
  );
}
