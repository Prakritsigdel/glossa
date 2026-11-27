import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:glossa_app/features/lessons/screens/lesson_runner_screen.dart';
import 'package:glossa_app/features/progression/screens/level_up_screen.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/models/leaderboard_entry.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';

class _ResponsiveApi extends BackendApi {
  _ResponsiveApi({this.answerResults = const []});

  final List<Map<String, dynamic>> answerResults;
  final List<Map<String, dynamic>> answerCalls = [];
  bool failNextAnswer = false;
  Completer<Map<String, dynamic>>? pendingAnswer;
  final List<String> leaderboardFilters = [];
  final List<LeaderboardEntry> entries = [
    for (var index = 1; index <= 10; index++)
      LeaderboardEntry(
        rank: index,
        name: 'A very long adventurer username $index',
        level: 99,
        className: 'Legendary Master Adventurer',
        xp: 999999999 + index,
        heroIndex: index % 2,
        isCurrentUser: index == 1,
      ),
  ];

  @override
  Future<String?> get token async => null;

  @override
  Future<Map<String, dynamic>> answerExercise(
    String lessonId,
    Map<String, dynamic> answer,
  ) async {
    answerCalls.add(Map<String, dynamic>.from(answer));
    if (failNextAnswer) {
      failNextAnswer = false;
      throw const BackendException('Temporary network error');
    }
    final pending = pendingAnswer;
    if (pending != null) {
      pendingAnswer = null;
      return pending.future;
    }
    if (answerResults.isNotEmpty) return answerResults.removeAt(0);
    return {
      'correct': true,
      'is_final': true,
      'phase': answer['phase'],
      'review_complete': answer['phase'] == 'review',
      'matched_pairs': <String, String>{},
      'correct_answer': null,
    };
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(String filter) async {
    leaderboardFilters.add(filter);
    return entries;
  }
}

Exercise _longMatch() => Exercise(
  id: 'responsive-match',
  type: ExerciseType.matchWords,
  instruction: 'Match the Newari words with their meanings',
  options: [
    for (var index = 1; index <= 6; index++) ...[
      AnswerOption(
        id: 'd$index',
        text: 'दीर्घन्यूवारीपदशब्द$index',
        isDevanagari: true,
        romanization: 'extremely-long-newari-romanization-$index',
      ),
      AnswerOption(
        id: 'e$index',
        text: 'A very long English vocabulary meaning number $index',
      ),
    ],
  ],
);

List<Exercise> _exerciseCases() => [
  _longMatch(),
  Exercise(
    id: 'responsive-fill',
    type: ExerciseType.fillBlank,
    instruction: 'Fill in the blank',
    variant: 'recognition',
    layout: {
      'tile': {
        'text': 'दीर्घन्यूवारीपदशब्द',
        'roman': 'very-long-newari-romanization-value',
      },
      'sentence': [
        {
          'text':
              'This is a very long English prompt that should wrap correctly',
        },
        {'blank': true},
      ],
    },
    options: [
      for (var index = 0; index < 4; index++)
        AnswerOption(
          id: 'fill-$index',
          text: 'An exceptionally long answer choice that should wrap',
        ),
    ],
  ),
  Exercise(
    id: 'responsive-picture-word',
    type: ExerciseType.pictureToWord,
    instruction: 'Name the picture',
    imageKey: 'droplet',
    options: [
      for (var index = 0; index < 4; index++)
        AnswerOption(
          id: 'picture-$index',
          text: 'An exceptionally long Newari answer $index',
          isDevanagari: true,
          romanization: 'an-exceptionally-long-romanization-$index',
        ),
    ],
  ),
  Exercise(
    id: 'responsive-word-picture',
    type: ExerciseType.wordToPicture,
    instruction: 'Pick the picture',
    prompt: 'दीर्घन्यूवारीपदशब्द',
    romanization: 'very-long-newari-romanization',
    options: [
      for (var index = 0; index < 4; index++)
        AnswerOption(
          id: 'word-picture-$index',
          text: 'A long picture answer $index',
          imageKey: index.isEven ? 'house' : 'droplet',
          romanization: 'very-long-romanization-$index',
        ),
    ],
  ),
];

Widget _responsiveApp({
  required ProviderContainer container,
  required Widget child,
  required double textScale,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'all exercise layouts stay usable across narrow, scaled, short and tall viewports',
    (tester) async {
      final viewportCases = [
        for (final width in [320.0, 360.0, 393.0, 430.0])
          for (final height in [568.0, 900.0])
            for (final scale in [1.0, 1.3, 1.5])
              (width: width, height: height, scale: scale),
      ];

      for (final viewport in viewportCases) {
        await tester.binding.setSurfaceSize(
          Size(viewport.width, viewport.height),
        );
        for (final exercise in _exerciseCases()) {
          final api = _ResponsiveApi();
          final container = ProviderContainer(
            overrides: [backendApiProvider.overrideWithValue(api)],
          );
          container.read(gameStateProvider.notifier).state = container
              .read(gameStateProvider)
              .copyWith(
                activeLessonId: 'responsive-lesson',
                runId: 'responsive-run-id',
                exercises: [exercise],
                isReviewingMistakes: true,
                reviewQueue: [exercise.id],
                reviewTotalCount: 1,
              );
          await tester.pumpWidget(
            _responsiveApp(
              container: container,
              child: const LessonRunnerScreen(),
              textScale: viewport.scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason:
                '${exercise.type} at ${viewport.width}x${viewport.height}, '
                'text scale ${viewport.scale}',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'review Check, Try Again and Continue remain scroll-reachable at 320px and 1.5x',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      final exercise = _exerciseCases()[1];
      final api = _ResponsiveApi(
        answerResults: [
          {
            'correct': false,
            'is_final': true,
            'phase': 'review',
            'correct_option_id': 'fill-0',
            'correct_answer': {
              'newari': 'दीर्घन्यूवारीपदशब्द',
              'romanization': 'very-long-newari-romanization',
              'english': 'Long corrective meaning',
            },
          },
          {
            'correct': true,
            'is_final': true,
            'phase': 'review',
            'review_complete': true,
            'correct_answer': null,
          },
        ],
      );
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.read(gameStateProvider.notifier).state = container
          .read(gameStateProvider)
          .copyWith(
            activeLessonId: 'responsive-lesson',
            runId: 'responsive-run-id',
            exercises: [exercise],
            isReviewingMistakes: true,
            reviewQueue: [exercise.id],
            reviewTotalCount: 1,
          );
      await tester.pumpWidget(
        _responsiveApp(
          container: container,
          child: const LessonRunnerScreen(),
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.text('An exceptionally long answer choice that should wrap').first,
      );
      await tester.tap(
        find.text('An exceptionally long answer choice that should wrap').first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check'));
      expect(find.text('Check'), findsOneWidget);
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(find.text('Try Again'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Try Again'));
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check'));
      await tester.ensureVisible(
        find.text('An exceptionally long answer choice that should wrap').first,
      );
      await tester.tap(
        find.text('An exceptionally long answer choice that should wrap').first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check'));
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'checking shows loading and recovers with selection after error',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      final pending = Completer<Map<String, dynamic>>();
      final api = _ResponsiveApi()
        ..failNextAnswer = true
        ..pendingAnswer = pending;
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final exercise = _exerciseCases()[2];
      container.read(gameStateProvider.notifier).state = container
          .read(gameStateProvider)
          .copyWith(
            activeLessonId: 'responsive-lesson',
            runId: 'responsive-run-id',
            exercises: [exercise],
          );
      await tester.pumpWidget(
        _responsiveApp(
          container: container,
          child: const LessonRunnerScreen(),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Name the picture'));
      await tester.tap(
        find.text('An exceptionally long Newari answer 0').first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after answer selection');
      await tester.ensureVisible(find.text('Check answer'));
      await tester.tap(find.text('Check answer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after network error');
      expect(find.text('Unable to check your answer.'), findsOneWidget);
      expect(find.text('Retry check'), findsOneWidget);

      await tester.tap(find.text('Retry check'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'while retry is loading');
      expect(find.text('Checking...'), findsOneWidget);

      pending.complete({
        'correct': true,
        'is_final': true,
        'matched_pairs': <String, String>{},
        'correct_answer': null,
      });
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsOneWidget);
      final layoutError = tester.takeException();
      expect(layoutError, isNull, reason: '$layoutError');
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('leaderboard fits long names and XP at responsive viewports', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 393.0, 430.0]) {
      for (final height in [568.0, 900.0]) {
        for (final scale in [1.0, 1.3, 1.5]) {
          await tester.binding.setSurfaceSize(Size(width, height));
          final api = _ResponsiveApi();
          final container = ProviderContainer(
            overrides: [backendApiProvider.overrideWithValue(api)],
          );
          await tester.pumpWidget(
            _responsiveApp(
              container: container,
              child: const LeaderboardScreen(),
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Leaderboard'), findsOneWidget);
          expect(api.leaderboardFilters, ['weekly']);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('All time'));
          await tester.pumpAndSettle();
          expect(api.leaderboardFilters, ['weekly', 'alltime']);
          await tester.ensureVisible(find.text('Top Adventurers'));
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -1800),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('A very long adventurer username 10'),
            findsOneWidget,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'Leaderboard at $width x $height, scale $scale',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'lesson results remain scrollable at narrow width and large text',
    (tester) async {
      for (final width in [320.0, 360.0, 393.0, 430.0]) {
        for (final height in [568.0, 900.0]) {
          for (final scale in [1.0, 1.3, 1.5]) {
            await tester.binding.setSurfaceSize(Size(width, height));
            final container = ProviderContainer(
              overrides: [
                backendApiProvider.overrideWithValue(_ResponsiveApi()),
              ],
            );
            container.read(gameStateProvider.notifier).state = container
                .read(gameStateProvider)
                .copyWith(
                  activeLessonId: 'checkpoint',
                  lessons: const [
                    Lesson(
                      id: 'checkpoint',
                      sequence: 3,
                      title: 'Checkpoint',
                      subtitle: 'Checkpoint results',
                      exerciseType: ExerciseType.matchWords,
                      status: LessonStatus.available,
                      isCheckpoint: true,
                    ),
                  ],
                  lastPassed: false,
                  lastCorrectAnswers: 9,
                  lastTotalQuestions: 10,
                  lastScore: 0.9,
                  lastPassingThreshold: 80,
                  lastXpEarned: 999999,
                  lastEarnedXp: 999999,
                  lastXpMax: 999999,
                  lastMistakesCorrected: 10,
                  lastMasteredExercises: 10,
                  lastStatGains: const {
                    'hp': 10,
                    'attack': 10,
                    'defense': 10,
                    'speed': 10,
                    'magic': 10,
                  },
                  lastExerciseResults: List.generate(
                    10,
                    (index) => {
                      'correct': false,
                      'review_corrected': true,
                      'mastered': true,
                    },
                  ),
                );
            final router = GoRouter(
              initialLocation: AppRoutes.levelUp,
              routes: [
                GoRoute(
                  path: AppRoutes.levelUp,
                  builder: (context, state) => const LevelUpScreen(),
                ),
                GoRoute(
                  path: AppRoutes.town,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Town')),
                ),
              ],
            );
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp.router(
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('CHECKPOINT NOT PASSED'), findsOneWidget);
            expect(find.textContaining('Mistakes corrected'), findsOneWidget);
            await tester.ensureVisible(find.text('Retry Lesson'));
            expect(find.text('Retry Lesson'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Results at $width x $height, scale $scale',
            );
            await tester.pumpWidget(const SizedBox.shrink());
            router.dispose();
            container.dispose();
          }
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
