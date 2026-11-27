import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glossa_app/core/widgets/simple_illustration.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';
import 'package:glossa_app/features/lessons/screens/lesson_runner_screen.dart';

class _OfflineApi extends BackendApi {
  @override
  Future<String?> get token async => null;
}

class _AnsweringApi extends BackendApi {
  _AnsweringApi({
    this.responses = const [],
    this.failNextAnswer = false,
    this.pendingAnswer,
  });

  final List<Map<String, dynamic>> responses;
  final List<Map<String, dynamic>> answerCalls = [];
  bool failNextAnswer;
  Completer<Map<String, dynamic>>? pendingAnswer;
  Map<String, dynamic> reviewQueueResponse = {
    'review_queue': <String>[],
    'corrected_exercise_ids': <String>[],
  };

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
      throw StateError('temporary network failure');
    }
    final pending = pendingAnswer;
    if (pending != null) {
      pendingAnswer = null;
      return pending.future;
    }
    if (responses.isNotEmpty) return responses.removeAt(0);
    return {
      'correct': true,
      'is_final': true,
      'pair_correct': true,
      'matched_pairs': <String, String>{},
      'xp_earned': 2,
      'mistake_count': 0,
    };
  }

  @override
  Future<Map<String, dynamic>> reviewQueue(
    String lessonId,
    String runId,
  ) async => reviewQueueResponse;
}

Exercise _l01MatchExercise() => const Exercise(
  id: 'L01-E01',
  type: ExerciseType.matchWords,
  instruction: 'Match each Newari word to its meaning',
  options: [
    AnswerOption(
      id: 'L01-E01-D-w01',
      text: 'ज्वजलपा',
      isDevanagari: true,
      romanization: 'jwajalapa',
    ),
    AnswerOption(
      id: 'L01-E01-D-w02',
      text: 'सुभाय्',
      isDevanagari: true,
      romanization: 'subhāy',
    ),
    AnswerOption(
      id: 'L01-E01-D-w03',
      text: 'खः',
      isDevanagari: true,
      romanization: 'khaḥ',
    ),
    AnswerOption(
      id: 'L01-E01-D-w04',
      text: 'मखु',
      isDevanagari: true,
      romanization: 'makhu',
    ),
    AnswerOption(
      id: 'L01-E01-D-w05',
      text: 'बांलाः',
      isDevanagari: true,
      romanization: 'bāṅlāḥ',
    ),
    AnswerOption(
      id: 'L01-E01-D-w06',
      text: 'भिं',
      isDevanagari: true,
      romanization: 'bhiṃ',
    ),
    AnswerOption(id: 'L01-E01-E-w01', text: 'Hello'),
    AnswerOption(id: 'L01-E01-E-w02', text: 'Thank you'),
    AnswerOption(id: 'L01-E01-E-w03', text: 'Yes'),
    AnswerOption(id: 'L01-E01-E-w04', text: 'No'),
    AnswerOption(id: 'L01-E01-E-w05', text: 'Good'),
    AnswerOption(id: 'L01-E01-E-w06', text: 'Well / fine'),
  ],
);

Exercise _l01FillBlank({
  required String id,
  required String prompt,
  required String tileText,
  required String romanization,
  required List<AnswerOption> options,
}) {
  return Exercise(
    id: id,
    type: ExerciseType.fillBlank,
    instruction: 'Fill in the blank',
    prompt: prompt,
    variant: 'recognition',
    options: options,
    layout: {
      'template': 'picture-sentence-chips',
      'tile': {'text': tileText, 'roman': romanization},
      'sentence': [
        {'text': 'This word means'},
        {'blank': true},
      ],
      'chips': 'options',
      'fill_behavior':
          'tap chip moves it into the blank; tap again to return it',
    },
  );
}

void main() {
  test('unsupported illustration keys never map to a misleading drawing', () {
    expect(SimpleIllustration.supports('unknown-content'), isFalse);
    expect(SimpleIllustration.supports(null), isFalse);
    // The illustration catalog has expanded to 50+ concept keys.
    // Verify that original core keys are present and the set is non-trivial.
    expect(
      SimpleIllustration.supportedImageKeys,
      containsAll([
        'house',
        'droplet',
        'bowl',
        'person',
        'hello',
        'mother',
        'father',
      ]),
    );
    expect(
      SimpleIllustration.supportedImageKeys.length,
      greaterThanOrEqualTo(40),
    );
  });

  final renderCases = <({Exercise exercise, String marker})>[
    (
      exercise: const Exercise(
        id: 'match',
        type: ExerciseType.matchWords,
        instruction: 'TEST match',
        options: [
          AnswerOption(id: 'md', text: 'TEST word', isDevanagari: true),
          AnswerOption(id: 'me', text: 'TEST meaning'),
        ],
      ),
      marker: 'Match the words',
    ),
    (
      exercise: const Exercise(
        id: 'fill',
        type: ExerciseType.fillBlank,
        instruction: 'TEST fill',
        layout: {
          'tile': {'text': 'TEST Newari', 'roman': 'test'},
          'sentence': [
            {'text': 'This word means'},
            {'blank': true},
          ],
        },
        options: [AnswerOption(id: 'f1', text: 'TEST answer')],
      ),
      marker: 'Fill in the blank',
    ),
    (
      exercise: const Exercise(
        id: 'picture-word',
        type: ExerciseType.pictureToWord,
        instruction: 'TEST picture word',
        imageKey: 'droplet',
        options: [
          AnswerOption(id: 'p1', text: 'TEST water', isDevanagari: true),
        ],
      ),
      marker: 'Name the picture',
    ),
    (
      exercise: const Exercise(
        id: 'word-picture',
        type: ExerciseType.wordToPicture,
        instruction: 'TEST word picture',
        prompt: 'TEST word',
        options: [
          AnswerOption(id: 'w1', text: 'TEST image', imageKey: 'house'),
        ],
      ),
      marker: 'Pick the picture',
    ),
  ];

  for (final item in renderCases) {
    testWidgets('${item.exercise.type.name} renders in unified lesson runner', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(_OfflineApi())],
      );
      addTearDown(container.dispose);
      container.read(gameStateProvider.notifier).state = container
          .read(gameStateProvider)
          .copyWith(
            activeLessonId: 'stage8-test-lesson',
            exercises: [item.exercise],
          );

      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LessonRunnerScreen()),
        ),
      );
      await tester.pump();

      expect(find.text(item.marker), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('L01 E02 to E03 resets the selected answer state', (
    tester,
  ) async {
    final exercise2 = _l01FillBlank(
      id: 'L01-E02',
      prompt: 'What does ज्वजलपा mean?',
      tileText: 'ज्वजलपा',
      romanization: 'jwajalapa',
      options: const [
        AnswerOption(id: 'L01-E02-O1', text: 'Well / fine'),
        AnswerOption(id: 'L01-E02-O2', text: 'Yes'),
        AnswerOption(id: 'L01-E02-O3', text: 'Thank you'),
        AnswerOption(id: 'L01-E02-O4', text: 'Hello'),
      ],
    );
    final exercise3 = _l01FillBlank(
      id: 'L01-E03',
      prompt: 'What does सुभाय् mean?',
      tileText: 'सुभाय्',
      romanization: 'subhāy',
      options: const [
        AnswerOption(id: 'L01-E03-O1', text: 'Thank you'),
        AnswerOption(id: 'L01-E03-O2', text: 'No'),
        AnswerOption(id: 'L01-E03-O3', text: 'Well / fine'),
        AnswerOption(id: 'L01-E03-O4', text: 'Good'),
      ],
    );
    final container = ProviderContainer(
      overrides: [backendApiProvider.overrideWithValue(_AnsweringApi())],
    );
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).state = container
        .read(gameStateProvider)
        .copyWith(
          activeLessonId: 'L01',
          runId: 'stage821-test-run',
          exercises: [exercise2, exercise3],
        );
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LessonRunnerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello'));
    await tester.ensureVisible(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(container.read(gameStateProvider).currentExerciseIndex, 1);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Correct!'), findsNothing);
    expect(find.text('Check'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mistake review reveals correction and allows Try Again', (
    tester,
  ) async {
    final exercise = _l01FillBlank(
      id: 'L01-E02',
      prompt: 'What does ज्वजलपा mean?',
      tileText: 'ज्वजलपा',
      romanization: 'jwajalapa',
      options: const [
        AnswerOption(id: 'wrong', text: 'Yes'),
        AnswerOption(id: 'correct', text: 'Hello'),
      ],
    );
    final api = _AnsweringApi(
      responses: [
        {
          'correct': false,
          'is_final': true,
          'phase': 'review',
          'correct_option_id': 'correct',
          'correct_answer': {
            'newari': 'ज्वजलपा',
            'romanization': 'jwajalapa',
            'english': 'Hello',
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
          activeLessonId: 'L01',
          runId: 'review-test-run',
          exercises: [exercise],
          answers: const {
            'L01-E02': {'exercise_id': 'L01-E02', 'correct': false},
          },
          answeredExerciseIds: const {'L01-E02'},
          reviewQueue: const ['L01-E02'],
          isReviewingMistakes: true,
          reviewTotalCount: 1,
        );
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LessonRunnerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reviewing mistakes'), findsOneWidget);
    expect(find.text('Fill in the blank'), findsOneWidget);
    await tester.ensureVisible(find.text('Yes'));
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Check'));
    expect(
      tester
          .widget<GlossaButton>(
            find.ancestor(
              of: find.text('Check'),
              matching: find.byType(GlossaButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(api.answerCalls, hasLength(1));
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Correct!'), findsNothing);
    expect(find.text('jwajalapa'), findsWidgets);
    expect(api.answerCalls.single['phase'], 'review');

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsNothing);
    await tester.tap(find.text('Hello').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Check'));
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(api.answerCalls, hasLength(2));
    expect(find.text('Correct!'), findsOneWidget);
    expect(api.answerCalls.last['phase'], 'review');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported exercise formats show a recoverable message', (
    tester,
  ) async {
    final exercise = const Exercise(
      id: 'unsupported',
      type: ExerciseType.translate,
      instruction: 'Unsupported legacy format',
      options: [],
    );
    final container = ProviderContainer(
      overrides: [backendApiProvider.overrideWithValue(_OfflineApi())],
    );
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).state = container
        .read(gameStateProvider)
        .copyWith(exercises: [exercise]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LessonRunnerScreen()),
      ),
    );

    expect(
      find.text('This exercise format is not supported in this lesson.'),
      findsOneWidget,
    );
    expect(find.text('Back to Town'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumed matching pairs stay locked', (tester) async {
    final api = _AnsweringApi();
    final container = ProviderContainer(
      overrides: [backendApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).state = container
        .read(gameStateProvider)
        .copyWith(
          activeLessonId: 'L01',
          runId: 'resumed-match-run',
          exercises: [_l01MatchExercise()],
          matchedPairsByExercise: const {
            'L01-E01': {'L01-E01-D-w01': 'L01-E01-E-w01'},
          },
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LessonRunnerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ज्वजलपा'));
    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(api.answerCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'L01 matching allows retries, locks correct pairs, and finishes after multiple mistakes',
    (tester) async {
      const d1 = 'L01-E01-D-w01';
      const d2 = 'L01-E01-D-w02';
      const d3 = 'L01-E01-D-w03';
      const d4 = 'L01-E01-D-w04';
      const d5 = 'L01-E01-D-w05';
      const d6 = 'L01-E01-D-w06';
      const e1 = 'L01-E01-E-w01';
      const e2 = 'L01-E01-E-w02';
      const e3 = 'L01-E01-E-w03';
      const e4 = 'L01-E01-E-w04';
      const e5 = 'L01-E01-E-w05';
      const e6 = 'L01-E01-E-w06';

      Map<String, dynamic> pairResult({
        required Map<String, String> pairs,
        required bool pairCorrect,
        required bool isFinal,
        required int mistakes,
      }) => {
        'correct': isFinal && mistakes == 0,
        'pair_correct': pairCorrect,
        'is_final': isFinal,
        'matched_pairs': pairs,
        'xp_earned': isFinal && mistakes == 0 ? 2 : 0,
        'mistake_count': mistakes,
        'correct_answer': null,
      };

      final api = _AnsweringApi(
        responses: [
          pairResult(
            pairs: {},
            pairCorrect: false,
            isFinal: false,
            mistakes: 1,
          ),
          pairResult(
            pairs: {d1: e1},
            pairCorrect: true,
            isFinal: false,
            mistakes: 1,
          ),
          pairResult(
            pairs: {d1: e1},
            pairCorrect: false,
            isFinal: false,
            mistakes: 2,
          ),
          pairResult(
            pairs: {d1: e1, d2: e2},
            pairCorrect: true,
            isFinal: false,
            mistakes: 2,
          ),
          pairResult(
            pairs: {d1: e1, d2: e2, d3: e3},
            pairCorrect: true,
            isFinal: false,
            mistakes: 2,
          ),
          pairResult(
            pairs: {d1: e1, d2: e2, d3: e3, d4: e4},
            pairCorrect: true,
            isFinal: false,
            mistakes: 2,
          ),
          pairResult(
            pairs: {d1: e1, d2: e2, d3: e3, d4: e4, d5: e5},
            pairCorrect: true,
            isFinal: false,
            mistakes: 2,
          ),
          pairResult(
            pairs: {d1: e1, d2: e2, d3: e3, d4: e4, d5: e5, d6: e6},
            pairCorrect: true,
            isFinal: true,
            mistakes: 2,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.read(gameStateProvider.notifier).state = container
          .read(gameStateProvider)
          .copyWith(
            activeLessonId: 'L01',
            runId: 'stage822-match-run',
            exercises: [_l01MatchExercise()],
          );
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LessonRunnerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> tapWord(String word) async {
        final finder = find.text(word).first;
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
      }

      await tapWord('Thank you');
      await tapWord('Thank you');
      expect(api.answerCalls, isEmpty);

      await tapWord('ज्वजलपा');
      await tapWord('Thank you');
      await tester.pumpAndSettle();
      expect(api.answerCalls, hasLength(1));
      expect(find.text('Continue'), findsNothing);
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pump();

      await tapWord('Hello');
      await tapWord('ज्वजलपा');
      await tester.pumpAndSettle();
      expect(api.answerCalls, hasLength(2));
      await tapWord('ज्वजलपा');
      await tapWord('Hello');
      expect(api.answerCalls, hasLength(2));

      await tapWord('सुभाय्');
      await tapWord('Yes');
      await tester.pumpAndSettle();
      expect(api.answerCalls, hasLength(3));
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pump();

      await tapWord('सुभाय्');
      await tapWord('Thank you');
      await tester.pumpAndSettle();
      await tapWord('खः');
      await tapWord('Yes');
      await tester.pumpAndSettle();
      await tapWord('मखु');
      await tapWord('No');
      await tester.pumpAndSettle();
      await tapWord('बांलाः');
      await tapWord('Good');
      await tester.pumpAndSettle();
      await tapWord('भिं');
      await tapWord('Well / fine');
      await tester.pumpAndSettle();

      expect(api.answerCalls, hasLength(8));
      expect(
        find.text('All pairs matched. Matching mistakes: 2.'),
        findsOneWidget,
      );
      expect(api.answerCalls.first['submission_id'], isA<String>());
      expect(api.answerCalls.first['selected_pairs'], {d1: e2});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'single-answer selection can change and network retry is idempotent',
    (tester) async {
      final api = _AnsweringApi(
        failNextAnswer: true,
        responses: [
          {
            'correct': false,
            'is_final': true,
            'matched_pairs': <String, String>{},
            'xp_earned': 0,
            'correct_option_id': 'L01-E02-O4',
            'correct_answer': {
              'newari': 'ज्वजलपा',
              'romanization': 'jwajalapa',
              'english': 'Hello',
            },
          },
        ],
      );
      final exercise = _l01FillBlank(
        id: 'L01-E02',
        prompt: 'What does ज्वजलपा mean?',
        tileText: 'ज्वजलपा',
        romanization: 'jwajalapa',
        options: const [
          AnswerOption(id: 'L01-E02-O1', text: 'Well / fine'),
          AnswerOption(id: 'L01-E02-O2', text: 'Yes'),
          AnswerOption(id: 'L01-E02-O3', text: 'Thank you'),
          AnswerOption(id: 'L01-E02-O4', text: 'Hello'),
        ],
      );
      final container = ProviderContainer(
        overrides: [backendApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.read(gameStateProvider.notifier).state = container
          .read(gameStateProvider)
          .copyWith(
            activeLessonId: 'L01',
            runId: 'stage822-single-run',
            exercises: [exercise],
          );
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LessonRunnerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Well / fine').last);
      await tester.pump();
      await tester.tap(find.text('Well / fine').first);
      await tester.pump();
      await tester.ensureVisible(find.text('Check'));
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(api.answerCalls, isEmpty);

      await tester.tap(find.text('Yes'));
      await tester.pump();
      await tester.tap(find.text('Thank you'));
      await tester.pump();
      await tester.tap(find.text('Well / fine'));
      await tester.pump();
      await tester.ensureVisible(find.text('Check'));
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to check your answer.'), findsOneWidget);
      expect(api.answerCalls, hasLength(1));

      await tester.tap(find.text('Retry check'));
      await tester.pumpAndSettle();
      expect(api.answerCalls, hasLength(2));
      expect(
        api.answerCalls[0]['submission_id'],
        api.answerCalls[1]['submission_id'],
      );
      expect(
        api.answerCalls[0]['selected_option_id'],
        api.answerCalls[1]['selected_option_id'],
      );
      expect(find.text('ज्वजलपा'), findsWidgets);
      expect(find.text('jwajalapa'), findsWidgets);
      expect(find.text('Hello'), findsWidgets);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid matching taps submit exactly one pending pair', (
    tester,
  ) async {
    const d1 = 'L01-E01-D-w01';
    const e1 = 'L01-E01-E-w01';
    final pending = Completer<Map<String, dynamic>>();
    final api = _AnsweringApi(pendingAnswer: pending);
    final exercise = Exercise(
      id: 'L01-E01',
      type: ExerciseType.matchWords,
      instruction: 'Match each Newari word to its meaning',
      options: [
        _l01MatchExercise().options[0],
        _l01MatchExercise().options[1],
        _l01MatchExercise().options[6],
        _l01MatchExercise().options[7],
      ],
    );
    final container = ProviderContainer(
      overrides: [backendApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).state = container
        .read(gameStateProvider)
        .copyWith(
          activeLessonId: 'L01',
          runId: 'stage822-rapid-run',
          exercises: [exercise],
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LessonRunnerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello'));
    await tester.pump();
    await tester.tap(find.text('ज्वजलपा'));
    await tester.pump();
    await tester.tap(find.text('Hello'));
    await tester.pump();
    await tester.tap(find.text('ज्वजलपा'));
    await tester.pump();
    expect(api.answerCalls, hasLength(1));
    expect(api.answerCalls.single['selected_pairs'], {d1: e1});

    pending.complete({
      'correct': false,
      'pair_correct': true,
      'is_final': false,
      'matched_pairs': {d1: e1},
      'xp_earned': 0,
      'mistake_count': 0,
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
