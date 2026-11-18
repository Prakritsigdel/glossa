import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glossa/app.dart';

void main() {
  testWidgets('splash moves to the welcome screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GlossaApp()));

    // Splash is showing.
    expect(find.text('GLOSSA'), findsWidgets);
    expect(find.text('New Game'), findsNothing);

    // Wait out the splash timer, then the route transition.
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('New Game'), findsOneWidget);
    expect(find.text('Continue (load save)'), findsOneWidget);
  });

  testWidgets('New game opens the character screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GlossaApp()));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('New Game'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Choose your character'), findsOneWidget);
  });
}
