import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glossa_app/features/lessons/screens/lesson_runner_screen.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/models/demo_user.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';

class _RecordingApi extends BackendApi {
  final List<Map<String, dynamic>> answerCalls = [];
  final List<Map<String, dynamic>> submitCalls = [];
  final List<Map<String, dynamic>> answerResponses = [];
  bool throwAnswer = false;
  bool throwSubmit = false;
  Completer<Map<String, dynamic>>? pendingAnswer;
  Map<String, dynamic> startResponse = {
    'run_id': 'recorded-run',
    'answered_exercise_ids': <String>[],
    'original_results': <String, bool>{},
    'review_queue': <String>[],
    'corrected_exercise_ids': <String>[],
    'matched_pairs_by_exercise': <String, dynamic>{},
    'needs_completion': false,
  };
  Map<String, dynamic> reviewQueueResponse = {
    'review_queue': <String>[],
    'corrected_exercise_ids': <String>[],
  };
  List<Exercise> lessonExercises = const [];

  @override
  Future<String?> get token async => null;

  @override
  Future<Map<String, dynamic>> startLessonRun(String lessonId) async =>
      startResponse;

  @override
  Future<Map<String, dynamic>> reviewQueue(
    String lessonId,
    String runId,
  ) async => reviewQueueResponse;

  @override
  Future<List<Exercise>> exercises(String lessonId) async => lessonExercises;

  @override
  Future<bool> checkAnswer(String lessonId, Map<String, dynamic> answer) async {
    answerCalls.add({...answer, 'lesson_id': lessonId});
    return true;
  }

  @override
  Future<Map<String, dynamic>> answerExercise(
    String lessonId,
    Map<String, dynamic> answer,
  ) async {
    answerCalls.add({...answer, 'lesson_id': lessonId});
    if (throwAnswer) throw const BackendException('Network failure');
    final pending = pendingAnswer;
    if (pending != null) {
      pendingAnswer = null;
      return pending.future;
    }
    return answerResponses.isEmpty
        ? {
            'correct': true,
            'is_final': true,
            'matched_pairs': <String, String>{},
          }
        : answerResponses.removeAt(0);
  }

  @override
  Future<Map<String, dynamic>> submitAttempt(
    String lessonId, {
    required List<Map<String, dynamic>> answers,
    String? idempotencyKey,
  }) async {
    submitCalls.add({
      'lesson_id': lessonId,
      'answers': answers,
      'idempotency_key': idempotencyKey,
    });
    if (throwSubmit) throw const BackendException('Network failure');
    return {
      'completed': true,
      'passed': true,
      'already_completed': false,
      'xp_earned': 2,
      'earned_xp': 2,
      'xp_max': 2,
      'correct_answers': 1,
      'total_questions': 1,
      'score': 1.0,
      'passing_threshold': 80,
      'missed_vocabulary': <Map<String, dynamic>>[],
      'stat_gains': <String, int>{},
      'hero_stats': <String, int>{},
      'level_up': false,
      'old_level': 1,
      'new_level': 1,
    };
  }

  @override
  Future<DemoUser> me() async => guestUser;

  @override
  Future<List<Lesson>> lessons({String? courseId}) async => [];
}

ProviderContainer _container(_RecordingApi api) =>
    ProviderContainer(overrides: [backendApiProvider.overrideWithValue(api)]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Match words randomization', () {
    test('randomizes both columns without aligning correct pairs', () {
      final options = [
        for (var index = 1; index <= 4; index++) ...[
          AnswerOption(
            id: 'd$index',
            text: 'Newari $index',
            isDevanagari: true,
          ),
          AnswerOption(id: 'e$index', text: 'Meaning $index'),
        ],
      ];
      const pairs = {'d1': 'e1', 'd2': 'e2', 'd3': 'e3', 'd4': 'e4'};
      var devanagariShuffled = false;
      var englishShuffled = false;

      for (var seed = 0; seed < 30; seed++) {
        final result = MatchWordsRandomizer.randomize(
          options: options,
          pairs: pairs,
          random: Random(seed),
        );
        devanagariShuffled |=
            result.devanagari.map((option) => option.id).join() != 'd1d2d3d4';
        englishShuffled |=
            result.english.map((option) => option.id).join() != 'e1e2e3e4';
        for (var index = 0; index < result.devanagari.length; index++) {
          expect(
            pairs[result.devanagari[index].id] == result.english[index].id,
            isFalse,
          );
        }
      }

      expect(devanagariShuffled, isTrue);
      expect(englishShuffled, isTrue);
    });
  });

  group('Per-exercise answer flow', () {
    test(
      'review answers do not replace original results or accuracy',
      () async {
        final api = _RecordingApi()
          ..answerResponses.add({
            'correct': true,
            'is_final': true,
            'phase': 'review',
            'review_complete': true,
            'xp_earned': 0,
            'matched_pairs': <String, String>{},
          });
        final container = _container(api);
        addTearDown(container.dispose);
        final notifier = container.read(gameStateProvider.notifier);
        notifier.state = notifier.state.copyWith(
          activeLessonId: 'L01',
          runId: 'run-id-123',
          answers: const {
            'L01-E02': {'exercise_id': 'L01-E02', 'correct': false},
          },
          answeredExerciseIds: const {'L01-E02'},
          correctAnswersInLesson: 0,
        );

        final feedback = await notifier.submitExerciseAnswer(
          'L01-E02',
          submissionId: 'review-request',
          review: true,
          selectedOptionId: 'correct-option',
        );

        expect(feedback['review_complete'], isTrue);
        expect(api.answerCalls.single['phase'], 'review');
        expect(
          container.read(gameStateProvider).answers['L01-E02']?['correct'],
          isFalse,
        );
        expect(container.read(gameStateProvider).correctAnswersInLesson, 0);
      },
    );

    test('one option submission is stored only after final feedback', () async {
      final api = _RecordingApi()
        ..answerResponses.addAll([
          {
            'correct': false,
            'is_final': true,
            'matched_pairs': <String, String>{},
            'correct_answer': {'newari': 'उत्तर'},
          },
        ]);
      final container = _container(api);
      addTearDown(container.dispose);
      final notifier = container.read(gameStateProvider.notifier);
      notifier.state = notifier.state.copyWith(
        activeLessonId: 'L01',
        runId: 'run-id-123',
      );

      final feedback = await notifier.submitExerciseAnswer(
        'L01-E02',
        selectedOptionId: 'option-wrong',
      );

      expect(feedback['correct'], isFalse);
      expect(
        container.read(gameStateProvider).answers['L01-E02']?['correct'],
        isFalse,
      );
      expect(container.read(gameStateProvider).correctAnswersInLesson, 0);
      expect(api.answerCalls.single['run_id'], 'run-id-123');
      expect(api.answerCalls.single['selected_option_id'], 'option-wrong');
    });

    test(
      'matching records mistakes and completes after every pair is correct',
      () async {
        final api = _RecordingApi()
          ..answerResponses.addAll([
            {
              'correct': false,
              'pair_correct': true,
              'is_final': false,
              'matched_pairs': {'d1': 'e1'},
              'mistake_count': 0,
            },
            {
              'correct': false,
              'pair_correct': false,
              'is_final': false,
              'matched_pairs': {'d1': 'e1'},
              'correct_answer': null,
              'mistake_count': 1,
            },
            {
              'correct': false,
              'pair_correct': true,
              'is_final': true,
              'matched_pairs': {'d1': 'e1', 'd2': 'e2'},
              'correct_answer': null,
              'mistake_count': 1,
            },
          ]);
        final container = _container(api);
        addTearDown(container.dispose);
        final notifier = container.read(gameStateProvider.notifier);
        notifier.state = notifier.state.copyWith(
          activeLessonId: 'L01',
          runId: 'run-id-123',
        );

        final first = await notifier.submitExerciseAnswer(
          'L01-E01',
          selectedPairs: const {'d1': 'e1'},
        );
        expect(first['is_final'], isFalse);
        expect(first['pair_correct'], isTrue);
        expect(container.read(gameStateProvider).answers, isEmpty);
        expect(container.read(gameStateProvider).matchedPairIds, {'d1', 'e1'});

        final second = await notifier.submitExerciseAnswer(
          'L01-E01',
          selectedPairs: const {'d2': 'e3'},
        );
        expect(second['correct'], isFalse);
        expect(second['pair_correct'], isFalse);
        expect(second['is_final'], isFalse);
        expect(second['correct_answer'], isNull);
        expect(container.read(gameStateProvider).matchedPairIds, {'d1', 'e1'});

        final finalResponse = await notifier.submitExerciseAnswer(
          'L01-E01',
          selectedPairs: const {'d2': 'e2'},
        );
        expect(finalResponse['is_final'], isTrue);
        expect(finalResponse['correct'], isFalse);
        expect(finalResponse['mistake_count'], 1);
        expect(
          container.read(gameStateProvider).answers['L01-E01']?['correct'],
          isFalse,
        );
      },
    );

    test('stale answer responses do not mutate a newer lesson run', () async {
      final pending = Completer<Map<String, dynamic>>();
      final api = _RecordingApi()..pendingAnswer = pending;
      final container = _container(api);
      addTearDown(container.dispose);
      final notifier = container.read(gameStateProvider.notifier);
      notifier.state = notifier.state.copyWith(
        activeLessonId: 'L01',
        runId: 'run-id-123',
      );

      final submission = notifier.submitExerciseAnswer(
        'L01-E01',
        selectedPairs: const {'d1': 'e1'},
      );
      await Future<void>.delayed(Duration.zero);
      notifier.state = notifier.state.copyWith(
        activeLessonId: 'L02',
        runId: 'run-id-456',
      );
      pending.complete({
        'correct': true,
        'is_final': true,
        'matched_pairs': {'d1': 'e1'},
      });
      await submission;

      expect(container.read(gameStateProvider).activeLessonId, 'L02');
      expect(container.read(gameStateProvider).answers, isEmpty);
      expect(container.read(gameStateProvider).matchedPairIds, isEmpty);
      expect(container.read(gameStateProvider).correctAnswersInLesson, 0);
    });

    test(
      'network failure is rethrown without recording an incorrect answer',
      () async {
        final api = _RecordingApi()..throwAnswer = true;
        final container = _container(api);
        addTearDown(container.dispose);
        final notifier = container.read(gameStateProvider.notifier);
        notifier.state = notifier.state.copyWith(
          activeLessonId: 'L01',
          runId: 'run-id-123',
        );

        await expectLater(
          notifier.submitExerciseAnswer(
            'L01-E02',
            selectedOptionId: 'option-1',
          ),
          throwsA(isA<BackendException>()),
        );
        expect(container.read(gameStateProvider).answers, isEmpty);
      },
    );
  });

  group('Run completion', () {
    test('lesson start restores server run and review progress', () async {
      final api = _RecordingApi()
        ..startResponse = {
          'run_id': 'resumed-run',
          'answered_exercise_ids': ['L01-E01', 'L01-E02'],
          'original_results': {'L01-E01': true, 'L01-E02': false},
          'review_queue': ['L01-E02'],
          'corrected_exercise_ids': <String>[],
          'matched_pairs_by_exercise': <String, dynamic>{},
          'needs_completion': false,
        }
        ..lessonExercises = const [
          Exercise(
            id: 'L01-E01',
            type: ExerciseType.fillBlank,
            instruction: 'Fill',
            options: [],
          ),
          Exercise(
            id: 'L01-E02',
            type: ExerciseType.pictureToWord,
            instruction: 'Identify',
            options: [],
          ),
        ];
      final container = _container(api);
      addTearDown(container.dispose);
      final notifier = container.read(gameStateProvider.notifier);
      notifier.state = notifier.state.copyWith(
        lessons: const [
          Lesson(
            id: 'L01',
            sequence: 1,
            title: 'Lesson',
            subtitle: 'Subtitle',
            exerciseType: ExerciseType.fillBlank,
            status: LessonStatus.available,
          ),
        ],
      );

      await notifier.startLesson('L01');

      final state = container.read(gameStateProvider);
      expect(state.runId, 'resumed-run');
      expect(state.answeredExerciseIds, {'L01-E01', 'L01-E02'});
      expect(state.answers['L01-E01']?['correct'], isTrue);
      expect(state.currentExerciseIndex, 0);
      expect(state.reviewQueue, ['L01-E02']);
      expect(state.isReviewingMistakes, isTrue);
      expect(state.reviewTotalCount, 1);
    });

    test(
      'submits the server-side run id once and does not resend answers',
      () async {
        final api = _RecordingApi();
        final container = _container(api);
        addTearDown(container.dispose);
        final notifier = container.read(gameStateProvider.notifier);
        notifier.state = notifier.state.copyWith(
          activeLessonId: 'L01',
          runId: 'run-id-123',
          exercises: const [
            Exercise(
              id: 'L01-E01',
              type: ExerciseType.fillBlank,
              instruction: 'Fill',
              options: [],
            ),
          ],
          answers: const {
            'L01-E01': {'exercise_id': 'L01-E01', 'correct': true},
          },
        );

        await notifier.completeLesson();
        await notifier.completeLesson();

        expect(api.submitCalls, hasLength(1));
        expect(api.submitCalls.single['lesson_id'], 'L01');
        expect(api.submitCalls.single['answers'], isEmpty);
        expect(api.submitCalls.single['idempotency_key'], 'run-id-123');
        expect(container.read(gameStateProvider).lessonComplete, isTrue);
      },
    );

    test('failed completion resets state and permits a retry', () async {
      final api = _RecordingApi()..throwSubmit = true;
      final container = _container(api);
      addTearDown(container.dispose);
      final notifier = container.read(gameStateProvider.notifier);
      notifier.state = notifier.state.copyWith(
        activeLessonId: 'L01',
        runId: 'run-id-123',
      );

      await expectLater(
        notifier.completeLesson(),
        throwsA(isA<BackendException>()),
      );
      expect(container.read(gameStateProvider).lessonComplete, isFalse);

      api.throwSubmit = false;
      await notifier.completeLesson();
      expect(api.submitCalls, hasLength(2));
      expect(container.read(gameStateProvider).lessonComplete, isTrue);
    });

    test('next exercise advances by one', () {
      final container = _container(_RecordingApi());
      addTearDown(container.dispose);
      final notifier = container.read(gameStateProvider.notifier);
      notifier.state = notifier.state.copyWith(
        exercises: const [
          Exercise(
            id: 'E1',
            type: ExerciseType.matchWords,
            instruction: 'Match',
            options: [],
          ),
          Exercise(
            id: 'E2',
            type: ExerciseType.fillBlank,
            instruction: 'Fill',
            options: [],
          ),
        ],
      );

      notifier.nextExercise();
      expect(container.read(gameStateProvider).currentExerciseIndex, 1);
    });
  });
}
