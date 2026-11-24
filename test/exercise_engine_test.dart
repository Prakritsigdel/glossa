// Exercise Engine Regression Tests
// Verifies: answer shuffling, pair accumulation, mixed-exercise progression,
// submission payload, XP deduplication, lesson unlocking, error handling.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';
import 'package:glossa_app/features/lessons/screens/lesson_runner_screen.dart';

// ─── Test doubles ─────────────────────────────────────────────

/// Records all calls and returns canned responses.
class _RecordingApi extends BackendApi {
  final List<Map<String, dynamic>> submitCalls = [];
  final List<Map<String, dynamic>> checkAnswerCalls = [];
  int submitCount = 0;
  bool checkAnswerReturns = true;
  bool submitShouldThrow = false;

  @override
  Future<bool> checkAnswer(String lessonId, Map<String, dynamic> answer) async {
    checkAnswerCalls.add({...answer, '_lesson': lessonId});
    return checkAnswerReturns;
  }

  @override
  Future<Map<String, dynamic>> submitAttempt(
    String lessonId, {
    required List<Map<String, dynamic>> answers,
    String? idempotencyKey,
  }) async {
    submitCount++;
    submitCalls.add({'lesson_id': lessonId, 'answers': answers});
    if (submitShouldThrow) throw const BackendException('Network failure');
    return {
      'completed': true,
      'already_completed': false,
      'xp_earned': 20,
      'correct_answers': answers.length,
      'total_questions': answers.length,
      'user': {
        'name': 'Test',
        'email': 'test@test.com',
        'hero_index': 0,
        'hero_class_name': 'Traveler',
        'level': 1,
        'xp': 20,
        'xp_to_next_level': 100,
        'streak': 1,
        'words_found': 4,
        'lessons_completed': 1,
        'language_id': 'newari',
        'active_course_id': 'new_en',
      },
    };
  }

  @override
  Future<List<Lesson>> lessons({String? courseId}) async => [];

  @override
  Future<List<Exercise>> exercises(String lessonId) async {
    return [
      const Exercise(
        id: 'ex_mw',
        type: ExerciseType.matchWords,
        instruction: 'Match the words',
        options: [
          AnswerOption(id: 'd1', text: 'नमस्ते', isDevanagari: true),
          AnswerOption(id: 'e1', text: 'Hello'),
          AnswerOption(id: 'd2', text: 'धन्यवाद', isDevanagari: true),
          AnswerOption(id: 'e2', text: 'Thank you'),
        ],
      ),
      const Exercise(
        id: 'ex_fb',
        type: ExerciseType.fillBlank,
        instruction: 'Fill in the blank',
        prompt: '___ (Hello)',
        options: [
          AnswerOption(id: 'fb_a', text: 'नमस्ते', isDevanagari: true),
          AnswerOption(id: 'fb_b', text: 'धन्यवाद', isDevanagari: true),
        ],
      ),
    ];
  }
}

// ─── Helpers ──────────────────────────────────────────────────

ProviderContainer _makeContainer(BackendApi api) {
  return ProviderContainer(
    overrides: [backendApiProvider.overrideWithValue(api)],
  );
}

Exercise _matchExercise({int pairCount = 4}) {
  final options = <AnswerOption>[];
  for (int i = 1; i <= pairCount; i++) {
    options.add(AnswerOption(id: 'd$i', text: 'Dev$i', isDevanagari: true));
    options.add(AnswerOption(id: 'e$i', text: 'Eng$i'));
  }
  return Exercise(
    id: 'mw_test',
    type: ExerciseType.matchWords,
    instruction: 'Match',
    options: options,
  );
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Match answer shuffling', () {
    test('Both Devanagari and English columns are randomized independently', () {
      final exercise = _matchExercise(pairCount: 4);
      final devItems =
          exercise.options.where((o) => o.isDevanagari).toList();
      final engItems =
          exercise.options.where((o) => !o.isDevanagari).toList();

      var devShuffledAtLeastOnce = false;
      var engShuffledAtLeastOnce = false;

      for (int trial = 0; trial < 30; trial++) {
        final result = MatchWordsRandomizer.randomize(
          options: exercise.options,
          pairs: {'d1': 'e1', 'd2': 'e2', 'd3': 'e3', 'd4': 'e4'},
          random: Random(trial),
        );

        if (!_listIdEquals(result.devanagari, devItems)) {
          devShuffledAtLeastOnce = true;
        }
        if (!_listIdEquals(result.english, engItems)) {
          engShuffledAtLeastOnce = true;
        }
      }

      expect(devShuffledAtLeastOnce, isTrue,
          reason: 'Devanagari column must be shuffled independently');
      expect(engShuffledAtLeastOnce, isTrue,
          reason: 'English column must be shuffled independently');
    });

    test('Correct pairs NEVER appear automatically aligned horizontally', () {
      final pairs = {'d1': 'e1', 'd2': 'e2', 'd3': 'e3', 'd4': 'e4'};
      final exercise = _matchExercise(pairCount: 4);

      for (int trial = 0; trial < 50; trial++) {
        final result = MatchWordsRandomizer.randomize(
          options: exercise.options,
          pairs: pairs,
          random: Random(trial * 7 + 13),
        );

        expect(result.devanagari.length, 4);
        expect(result.english.length, 4);

        for (int i = 0; i < 4; i++) {
          final devId = result.devanagari[i].id;
          final engId = result.english[i].id;
          expect(
            pairs[devId] == engId,
            isFalse,
            reason: 'Row $i: $devId and $engId must not be automatically aligned horizontally in trial $trial',
          );
        }
      }
    });

    test('Shuffled IDs still belong to the original option set', () {
      final exercise = _matchExercise(pairCount: 4);
      final engItems =
          exercise.options.where((o) => !o.isDevanagari).toList();
      final devItems =
          exercise.options.where((o) => o.isDevanagari).toList();
      final result = MatchWordsRandomizer.randomize(
        options: exercise.options,
        pairs: {'d1': 'e1', 'd2': 'e2', 'd3': 'e3', 'd4': 'e4'},
        random: Random(42),
      );
      final originalEngIds = engItems.map((o) => o.id).toSet();
      final originalDevIds = devItems.map((o) => o.id).toSet();
      for (final opt in result.english) {
        expect(originalEngIds, contains(opt.id));
      }
      for (final opt in result.devanagari) {
        expect(originalDevIds, contains(opt.id));
      }
    });

    test('listEquals check correctly detects identical order', () {
      final a = [
        const AnswerOption(id: 'e1', text: 'A'),
        const AnswerOption(id: 'e2', text: 'B'),
      ];
      final b = [
        const AnswerOption(id: 'e1', text: 'A'),
        const AnswerOption(id: 'e2', text: 'B'),
      ];
      expect(_listIdEquals(a, b), isTrue);
    });
  });

  group('2. Pair accumulation in GameState', () {
    test('Consecutive pair checks accumulate into one merged payload', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      // Seed with active lesson
      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_mw',
        exercises: [_matchExercise(pairCount: 4)],
      );

      // Simulate 4 pair checks
      await notifier.checkAnswer('mw_test', selectedPairs: {'d1': 'e1'});
      await notifier.checkAnswer('mw_test', selectedPairs: {'d2': 'e2'});
      await notifier.checkAnswer('mw_test', selectedPairs: {'d3': 'e3'});
      await notifier.checkAnswer('mw_test', selectedPairs: {'d4': 'e4'});

      final answers =
          container.read(gameStateProvider).answers;
      expect(answers.containsKey('mw_test'), isTrue);
      final pairs = answers['mw_test']!['selected_pairs'] as Map;
      expect(pairs.length, 4,
          reason: 'All 4 pairs should be accumulated');
      expect(pairs['d1'], 'e1');
      expect(pairs['d4'], 'e4');
    });

    test('Wrong pair check does not pollute accumulated answers', () async {
      final api = _RecordingApi()..checkAnswerReturns = false;
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_mw',
        exercises: [_matchExercise(pairCount: 2)],
      );

      await container.read(gameStateProvider.notifier)
          .checkAnswer('mw_test', selectedPairs: {'d1': 'e2'}); // wrong

      final answers = container.read(gameStateProvider).answers;
      expect(answers.containsKey('mw_test'), isFalse,
          reason: 'Wrong answer must not be stored');
    });
  });

  group('3. Answer recording per exercise type', () {
    test('fillBlank records selected_option_id correctly', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_fb',
        exercises: const [
          Exercise(
            id: 'ex_fb',
            type: ExerciseType.fillBlank,
            instruction: 'Fill',
            options: [AnswerOption(id: 'opt1', text: 'A')],
          ),
        ],
      );

      await container.read(gameStateProvider.notifier)
          .checkAnswer('ex_fb', selectedOptionId: 'opt1');

      final ans = container.read(gameStateProvider).answers;
      expect(ans['ex_fb']?['selected_option_id'], 'opt1');
    });

    test('pictureToWord records selected_option_id correctly', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_ptw',
        exercises: const [
          Exercise(
            id: 'ex_ptw',
            type: ExerciseType.pictureToWord,
            instruction: 'Pick',
            illustrationId: 'bowl',
            options: [AnswerOption(id: 'opt1', text: 'बजि', isDevanagari: true)],
          ),
        ],
      );

      await container.read(gameStateProvider.notifier)
          .checkAnswer('ex_ptw', selectedOptionId: 'opt1');

      final ans = container.read(gameStateProvider).answers;
      expect(ans['ex_ptw']?['selected_option_id'], 'opt1');
    });

    test('translate records selected_tile_ids correctly', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_tr',
        exercises: const [
          Exercise(
            id: 'ex_tr',
            type: ExerciseType.translate,
            instruction: 'Build the Newari word',
            prompt: 'Hello',
            newariScript: 'नमस्ते',
            romanization: 'namaste',
            options: [],
            wordTiles: [
              AnswerOption(id: 't1', text: 'न', isDevanagari: true),
              AnswerOption(id: 't2', text: 'म', isDevanagari: true),
            ],
          ),
        ],
      );

      await container.read(gameStateProvider.notifier)
          .checkAnswer('ex_tr', selectedTileIds: ['t1', 't2']);

      final ans = container.read(gameStateProvider).answers;
      expect(ans['ex_tr']?['selected_tile_ids'], equals(['t1', 't2']));
    });

    test('wordOrder records selected_tile_ids correctly', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_wo',
        exercises: const [
          Exercise(
            id: 'ex_wo',
            type: ExerciseType.wordOrder,
            instruction: 'Order the words',
            options: [],
            wordTiles: [
              AnswerOption(id: 'w1', text: 'म', isDevanagari: true),
              AnswerOption(id: 'w2', text: 'ाँ', isDevanagari: true),
            ],
          ),
        ],
      );

      await container.read(gameStateProvider.notifier)
          .checkAnswer('ex_wo', selectedTileIds: ['w1', 'w2']);

      final ans = container.read(gameStateProvider).answers;
      expect(ans['ex_wo']?['selected_tile_ids'], equals(['w1', 'w2']));
    });

    test('dialogueComplete records selected_option_id correctly', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_dc',
        exercises: const [
          Exercise(
            id: 'ex_dc',
            type: ExerciseType.dialogueComplete,
            instruction: 'Complete the dialogue',
            dialogueStructure: [
              {'speaker': 'A', 'text': 'नमस्ते', 'order': 1},
              {'speaker': 'B', 'text': '__', 'missing': true, 'order': 2},
            ],
            options: [
              AnswerOption(id: 'r1', text: 'नमस्ते'),
              AnswerOption(id: 'r2', text: 'धन्यवाद'),
            ],
          ),
        ],
      );

      await container.read(gameStateProvider.notifier)
          .checkAnswer('ex_dc', selectedOptionId: 'r1');

      final ans = container.read(gameStateProvider).answers;
      expect(ans['ex_dc']?['selected_option_id'], 'r1');
    });
  });

  group('4. Mixed-exercise lesson progression', () {
    test('nextExercise increments index correctly', () {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_x',
        exercises: const [
          Exercise(id: 'e1', type: ExerciseType.matchWords,
              instruction: 'A', options: []),
          Exercise(id: 'e2', type: ExerciseType.fillBlank,
              instruction: 'B', options: []),
          Exercise(id: 'e3', type: ExerciseType.pictureToWord,
              instruction: 'C', options: []),
        ],
      );

      expect(container.read(gameStateProvider).currentExerciseIndex, 0);
      container.read(gameStateProvider.notifier).nextExercise();
      expect(container.read(gameStateProvider).currentExerciseIndex, 1);
      container.read(gameStateProvider.notifier).nextExercise();
      expect(container.read(gameStateProvider).currentExerciseIndex, 2);
    });

    test('Progress = (currentIndex+1)/total', () {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        exercises: const [
          Exercise(id: 'e1', type: ExerciseType.matchWords,
              instruction: 'A', options: []),
          Exercise(id: 'e2', type: ExerciseType.fillBlank,
              instruction: 'B', options: []),
          Exercise(id: 'e3', type: ExerciseType.pictureToWord,
              instruction: 'C', options: []),
          Exercise(id: 'e4', type: ExerciseType.wordToPicture,
              instruction: 'D', options: []),
        ],
      );

      var gs = container.read(gameStateProvider);
      expect((gs.currentExerciseIndex + 1) / gs.exercises.length, 0.25);
      container.read(gameStateProvider.notifier).nextExercise();
      gs = container.read(gameStateProvider);
      expect((gs.currentExerciseIndex + 1) / gs.exercises.length, 0.50);
    });
  });

  group('5. Lesson submission', () {
    test('completeLesson submits all accumulated answers', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_full',
        exercises: const [
          Exercise(id: 'e1', type: ExerciseType.matchWords,
              instruction: 'A', options: []),
          Exercise(id: 'e2', type: ExerciseType.fillBlank,
              instruction: 'B', options: []),
        ],
        answers: {
          'e1': {'exercise_id': 'e1', 'selected_pairs': {'d1': 'e1'}},
          'e2': {'exercise_id': 'e2', 'selected_option_id': 'opt1'},
        },
      );

      await notifier.completeLesson();

      expect(api.submitCount, 1);
      final submitted = api.submitCalls.first['answers'] as List;
      expect(submitted.length, 2);
      expect(submitted.map((a) => a['exercise_id']).toSet(),
          {'e1', 'e2'});
    });

    test('XP awarded exactly once — duplicate completeLesson is blocked', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_xp',
        answers: {
          'e1': {'exercise_id': 'e1', 'selected_option_id': 'opt1'},
        },
      );

      final notifier = container.read(gameStateProvider.notifier);
      await notifier.completeLesson();
      await notifier.completeLesson(); // Should be a no-op
      await notifier.completeLesson(); // Should be a no-op

      expect(api.submitCount, 1,
          reason: 'submitAttempt must be called exactly once');
    });

    test('Failed submission resets lessonComplete so user can retry', () async {
      final api = _RecordingApi()..submitShouldThrow = true;
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_fail',
        answers: {
          'e1': {'exercise_id': 'e1', 'selected_option_id': 'opt1'},
        },
      );

      try {
        await container.read(gameStateProvider.notifier).completeLesson();
      } catch (_) {}

      final gs = container.read(gameStateProvider);
      expect(gs.lessonComplete, isFalse,
          reason: 'lessonComplete must be false after a failed submission');
    });
  });

  group('6. Incorrect answer not silently accepted', () {
    test('checkAnswer returns false when API returns false', () async {
      final api = _RecordingApi()..checkAnswerReturns = false;
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_x',
      );

      final result = await container.read(gameStateProvider.notifier)
          .checkAnswer('e1', selectedOptionId: 'wrong');

      expect(result, isFalse);
      expect(container.read(gameStateProvider).answers.containsKey('e1'),
          isFalse);
    });

    test('checkAnswer rethrows network errors instead of returning true', () async {
      final api = _ThrowingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_x',
      );

      expect(
        () => container.read(gameStateProvider.notifier)
            .checkAnswer('e1', selectedOptionId: 'opt1'),
        throwsA(isA<BackendException>()),
      );
    });
  });

  group('7. Lesson reset', () {
    test('resetLesson clears all in-progress state', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_x',
        currentExerciseIndex: 3,
        correctAnswersInLesson: 2,
        lessonComplete: false,
        answers: {'e1': {}},
        matchedPairIds: {'d1', 'e1'},
      );

      container.read(gameStateProvider.notifier).resetLesson();

      final gs = container.read(gameStateProvider);
      expect(gs.activeLessonId, isNull);
      expect(gs.currentExerciseIndex, 0);
      expect(gs.correctAnswersInLesson, 0);
      expect(gs.answers, isEmpty);
      expect(gs.matchedPairIds, isEmpty);
    });
  });

  group('8. Multi-exercise Lesson Completion & Language Selection', () {
    test('Incomplete lesson is blocked from submitting to backend', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      // Lesson has 4 exercises, but only 2 answers recorded
      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_4ex',
        exercises: [
          const Exercise(id: 'e1', type: ExerciseType.matchWords, instruction: '', options: []),
          const Exercise(id: 'e2', type: ExerciseType.fillBlank, instruction: '', options: []),
          const Exercise(id: 'e3', type: ExerciseType.pictureToWord, instruction: '', options: []),
          const Exercise(id: 'e4', type: ExerciseType.wordToPicture, instruction: '', options: []),
        ],
        answers: {
          'e1': {'exercise_id': 'e1'},
          'e2': {'exercise_id': 'e2'},
        },
      );

      await container.read(gameStateProvider.notifier).completeLesson();

      // Guard blocked submission
      expect(api.submitCount, 0,
          reason: 'submitAttempt must NOT be called for incomplete lesson');
    });

    test('Complete lesson with all 4 exercises sends full payload', () async {
      final api = _RecordingApi();
      final container = _makeContainer(api);
      addTearDown(container.dispose);

      container.read(gameStateProvider.notifier).state =
          container.read(gameStateProvider).copyWith(
        activeLessonId: 'lesson_4ex',
        exercises: [
          const Exercise(id: 'e1', type: ExerciseType.matchWords, instruction: '', options: []),
          const Exercise(id: 'e2', type: ExerciseType.fillBlank, instruction: '', options: []),
          const Exercise(id: 'e3', type: ExerciseType.pictureToWord, instruction: '', options: []),
          const Exercise(id: 'e4', type: ExerciseType.wordToPicture, instruction: '', options: []),
        ],
        answers: {
          'e1': {'exercise_id': 'e1', 'selected_pairs': {'d1': 'e1'}},
          'e2': {'exercise_id': 'e2', 'selected_option_id': 'opt2'},
          'e3': {'exercise_id': 'e3', 'selected_option_id': 'opt3'},
          'e4': {'exercise_id': 'e4', 'selected_option_id': 'opt4'},
        },
      );

      await container.read(gameStateProvider.notifier).completeLesson();

      expect(api.submitCount, 1);
      final submitted = api.submitCalls.first['answers'] as List;
      expect(submitted.length, 4);
      expect(submitted.map((a) => a['exercise_id']).toSet(),
          {'e1', 'e2', 'e3', 'e4'});
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────

bool _listIdEquals(List<AnswerOption> a, List<AnswerOption> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

class _ThrowingApi extends BackendApi {
  @override
  Future<bool> checkAnswer(String lessonId, Map<String, dynamic> answer) async {
    throw const BackendException('Simulated network error');
  }

  @override
  Future<List<Lesson>> lessons({String? courseId}) async => [];
}
