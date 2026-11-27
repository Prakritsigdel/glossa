import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glossa_app/core/widgets/simple_illustration.dart';
import 'package:glossa_app/features/lessons/screens/lesson_runner_screen.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';

class _OfflineApi extends BackendApi {
  @override
  Future<String?> get token async => null;

  @override
  Future<Map<String, dynamic>> answerExercise(
    String lessonId,
    Map<String, dynamic> answer,
  ) async {
    final pairs = answer['selected_pairs'];
    if (pairs != null && pairs is Map) {
      return {
        'correct': true,
        'pair_correct': true,
        'is_final': false,
        'matched_pairs': Map<String, String>.from(pairs),
        'xp_earned': 0,
        'mistake_count': 0,
        'correct_answer': null,
      };
    }
    return {
      'correct': true,
      'is_final': true,
      'matched_pairs': <String, String>{},
      'xp_earned': 0,
      'mistake_count': 0,
      'correct_answer': null,
    };
  }
}

String _defaultInstruction(String typeString) {
  switch (typeString) {
    case 'matchWords':
      return 'Match the words';
    case 'fillBlank':
      return 'Fill in the blank';
    case 'pictureToWord':
      return 'Name the picture';
    case 'wordToPicture':
      return 'Pick the picture';
    default:
      return 'Complete the exercise';
  }
}

Exercise _exerciseFromJson(Map<String, dynamic> source, String lessonId) {
  final id = source['id'] as String;
  final typeString = source['type'] as String;
  final type = ExerciseType.values.firstWhere(
    (e) => e.name == typeString,
    orElse: () => ExerciseType.fillBlank,
  );
  final instruction =
      (source['instruction'] as String?) ?? _defaultInstruction(typeString);
  final prompt = source['prompt'] as String?;
  final imageKey = source['image_key'] as String?;

  List<AnswerOption> options = [];
  if (typeString == 'matchWords') {
    final pairs = source['pairs'] as List;
    for (final pair in pairs) {
      final pairMap = pair as Map<String, dynamic>;
      options.add(AnswerOption(
        id: '$id-D-${pairMap['word_id']}',
        text: pairMap['newari'] as String,
        isDevanagari: true,
        romanization: pairMap['roman'] as String?,
      ));
      options.add(AnswerOption(
        id: '$id-E-${pairMap['word_id']}',
        text: pairMap['english'] as String,
        isDevanagari: false,
      ));
    }
  } else if (typeString == 'pictureToWord' || typeString == 'wordToPicture') {
    final opts = (source['options'] as List?) ?? const [];
    for (var i = 0; i < opts.length; i++) {
      final opt = opts[i] as Map<String, dynamic>;
      final optText = opt['text'] as String?;
      final optionNum = i + 1;
      options.add(AnswerOption(
        id: '$id-O$optionNum',
        text: optText ?? opt['image_key'] as String? ?? 'Option $optionNum',
        isDevanagari: true,
        romanization: opt['roman'] as String?,
        imageKey: opt['image_key'] as String?,
      ));
    }
  } else {
    final opts = source['options'] as List;
    for (var i = 0; i < opts.length; i++) {
      final opt = opts[i] as Map<String, dynamic>;
      final optionNum = i + 1;
      options.add(AnswerOption(
        id: '$id-O$optionNum',
        text: opt['text'] as String,
        isDevanagari: opt['roman'] != null,
        romanization: opt['roman'] as String?,
        imageKey: opt['image_key'] as String?,
      ));
    }
  }

  return Exercise(
    id: id,
    type: type,
    instruction: instruction,
    prompt: prompt,
    imageKey: imageKey,
    options: options,
    newariScript: source['newari_script'] as String?,
    romanization: source['romanization'] as String?,
  );
}

List<Map<String, dynamic>> _loadCurriculumLessonsSync() {
  final file = File('newari_lessons_content.json');
  final content = file.readAsStringSync(encoding: utf8);
  final data = jsonDecode(content) as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['lessons'] as List);
}

final List<Map<String, dynamic>> _lessons = _loadCurriculumLessonsSync();

void main() {
  group('Stage 8.2.6 — Full curriculum widget coverage (all 162 exercises)', () {
    test('curriculum loads with expected totals', () {
      expect(_lessons, hasLength(15));
      var totalExercises = 0;
      for (final lesson in _lessons) {
        totalExercises += (lesson['exercises'] as List).length;
      }
      expect(totalExercises, 162);
    });

    for (final lesson in _lessons) {
      final lessonId = lesson['id'] as String;
      final exercises = List<Map<String, dynamic>>.from(lesson['exercises'] as List);

      for (final exerciseSource in exercises) {
        final exerciseId = exerciseSource['id'] as String;
        final typeString = exerciseSource['type'] as String;

        testWidgets(
          '$lessonId $exerciseId ($typeString) renders and interacts',
          (tester) async {
            final exercise = _exerciseFromJson(exerciseSource, lessonId);

            // 1. Payload deserialization: Exercise object created correctly
            expect(exercise.id, exerciseId);
            expect(exercise.options.isNotEmpty, isTrue);
            expect(exercise.instruction.isNotEmpty, isTrue);

            // 2. Unique option IDs
            final optionIds = exercise.options.map((o) => o.id).toList();
            expect(optionIds.toSet().length, optionIds.length);

            // 3. Valid illustration references for illustration-based types
            if (typeString == 'pictureToWord') {
              expect(
                SimpleIllustration.supports(exercise.imageKey),
                isTrue,
                reason: '$exerciseId illustration key ${exercise.imageKey} not supported',
              );
            } else if (typeString == 'wordToPicture') {
              for (final option in exercise.options) {
                if (option.imageKey != null) {
                  expect(
                    SimpleIllustration.supports(option.imageKey!),
                    isTrue,
                    reason: '$exerciseId option ${option.id} illustration ${option.imageKey} not supported',
                  );
                }
              }
            }

            // 4. Match words: balanced Devanagari/English options
            if (typeString == 'matchWords') {
              final devCount = exercise.options.where((o) => o.isDevanagari).length;
              final engCount = exercise.options.length - devCount;
              expect(devCount, engCount);
              expect(devCount, greaterThan(0));
            }

            final container = ProviderContainer(
              overrides: [backendApiProvider.overrideWithValue(_OfflineApi())],
            );
            addTearDown(container.dispose);
            container.read(gameStateProvider.notifier).state = container
                .read(gameStateProvider)
                .copyWith(
              activeLessonId: lessonId,
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

            // 5. No runtime exceptions
            expect(tester.takeException(), isNull);

            // 6. Exercise renders with its type-specific instruction label
            final expectedLabel = _defaultInstruction(typeString);
            expect(find.text(expectedLabel), findsOneWidget);

            // 7. Answer options are findable and tappable
            if (exercise.options.isNotEmpty) {
              final firstOption = exercise.options.first;
              await tester.ensureVisible(find.text(firstOption.text));
              await tester.tap(find.text(firstOption.text).first);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }

            // 8. Matching: verify pair selection works
            if (typeString == 'matchWords' && exercise.options.length >= 2) {
              final devOptions = exercise.options.where((o) => o.isDevanagari).toList();
              final engOptions = exercise.options.where((o) => !o.isDevanagari).toList();
              if (devOptions.isNotEmpty && engOptions.isNotEmpty) {
                await tester.tap(find.text(devOptions.first.text).first);
                await tester.pump();
                await tester.tap(find.text(engOptions.first.text).first);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
            }
          },
        );
      }
    }
  });
}
