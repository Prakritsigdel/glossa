import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glossa_app/features/progression/screens/level_up_screen.dart';
import 'package:glossa_app/features/town/screens/town_screen.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

void main() {
  const widths = [320.0, 360.0, 393.0, 430.0];

  for (final width in widths) {
    testWidgets('Town fits at ${width.toInt()} logical pixels', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 850);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lessons = List.generate(15, (index) {
        final planNumber = index + 1;
        final unit = (index ~/ 3) + 1;
        final position = (index % 3) + 1;
        final checkpoint = position == 3;
        return Lesson(
          id: 'en_new_u${unit}_l$position',
          unitId: unit,
          sequence: position,
          title: planNumber == 15 ? 'A Day in Newari' : 'Lesson $planNumber',
          subtitle: 'Planned lesson',
          exerciseType: ExerciseType.matchWords,
          status: index == 0
              ? LessonStatus.available
              : LessonStatus.unavailable,
          isPublished: index == 0,
          isCheckpoint: checkpoint,
          isCapstone: planNumber == 15,
          availability: index == 0 ? 'available' : 'unavailable',
          plannedExerciseCount: 5 + (index % 6),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [townMapProvider.overrideWith((ref) async => lessons)],
          child: const MaterialApp(home: TownScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TownScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Completion layout fits at ${width.toInt()} logical pixels', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 850);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LevelUpScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LevelUpScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
