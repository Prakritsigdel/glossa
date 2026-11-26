import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glossa_app/core/widgets/simple_illustration.dart';
import 'package:glossa_app/features/lessons/widgets/translate_widget.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/repositories/backend_api.dart';
import 'package:glossa_app/features/lessons/screens/lesson_runner_screen.dart';

class _OfflineApi extends BackendApi {
  @override
  Future<String?> get token async => null;
}

void main() {
  test('unsupported illustration keys never map to a misleading drawing', () {
    expect(SimpleIllustration.supports('unknown-content'), isFalse);
    expect(SimpleIllustration.supports(null), isFalse);
    // The illustration catalog has expanded to 50+ concept keys.
    // Verify that original core keys are present and the set is non-trivial.
    expect(SimpleIllustration.supportedImageKeys, containsAll([
      'house', 'droplet', 'bowl', 'person', 'hello', 'mother', 'father',
    ]));
    expect(SimpleIllustration.supportedImageKeys.length, greaterThanOrEqualTo(40));
  });

  testWidgets(
    'translate keeps pronunciation on Newari tiles, not English prompt',
    (tester) async {
      const exercise = Exercise(
        id: 'translation-widget-test',
        type: ExerciseType.translate,
        instruction: 'Translate this word',
        prompt: 'TEST English prompt',
        romanization: 'TEST prompt answer leak',
        options: [],
        wordTiles: [
          AnswerOption(
            id: 'tile-1',
            text: 'TEST Newari tile',
            isDevanagari: true,
            romanization: 'tile-pronunciation',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TranslateContent(exercise: exercise, onComplete: () {}),
            ),
          ),
        ),
      );

      expect(find.text('TEST English prompt'), findsOneWidget);
      expect(find.text('tile-pronunciation'), findsOneWidget);
      expect(find.text('TEST prompt answer leak'), findsNothing);
    },
  );

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
        options: [AnswerOption(id: 'f1', text: 'TEST answer')],
      ),
      marker: 'TEST fill',
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
    (
      exercise: const Exercise(
        id: 'translate',
        type: ExerciseType.translate,
        instruction: 'TEST translate',
        prompt: 'TEST English',
        options: [],
        wordTiles: [
          AnswerOption(id: 't1', text: 'TEST tile', isDevanagari: true),
        ],
      ),
      marker: 'Newari word tiles',
    ),
    (
      exercise: const Exercise(
        id: 'word-order',
        type: ExerciseType.wordOrder,
        instruction: 'TEST word order',
        options: [],
        wordTiles: [
          AnswerOption(id: 'o1', text: 'TEST tile', isDevanagari: true),
        ],
      ),
      marker: 'Scrambled tiles — tap to add to sentence',
    ),
    (
      exercise: const Exercise(
        id: 'dialogue',
        type: ExerciseType.dialogueComplete,
        instruction: 'TEST dialogue',
        dialogueStructure: [
          {'speaker': 'A', 'text': 'TEST prompt', 'missing': false},
          {'speaker': 'B', 'text': '', 'missing': true},
        ],
        options: [AnswerOption(id: 'd1', text: 'TEST response')],
      ),
      marker: 'Select the missing response',
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

      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LessonRunnerScreen()),
        ),
      );
      await tester.pump();

      expect(find.text(item.marker), findsWidgets);
    });
  }
}
