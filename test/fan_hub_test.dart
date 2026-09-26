import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/data/fan_hub_data.dart';
import 'package:fandom_verse/screens/hub/fan_hub_screen.dart';
import 'package:fandom_verse/screens/hub/glossary_screen.dart';

/// Small set so every card fits the viewport — the real 37-term vocab
/// renders past the lazy ListView's built range in the test font.
const _miniTerms = [
  GlossaryTerm(
    term: 'Canon',
    definition: 'The official source material of a story.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Cosplay',
    definition: 'Dressing up as a favorite character.',
    category: 'Con Life',
  ),
  GlossaryTerm(
    term: 'Fanon',
    definition: 'What fans widely treat as true.',
    category: 'Fandom 101',
  ),
  GlossaryTerm(
    term: 'Ship',
    definition: 'Wanting two characters as a couple.',
    category: 'Shipping',
  ),
];

void main() {
  Future<void> pumpGlossary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: GlossaryScreen(terms: _miniTerms)),
    );
    await tester.pump();
  }

  testWidgets('glossary renders terms grouped by letter', (tester) async {
    await pumpGlossary(tester);
    expect(find.text('Fandom Glossary'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('Canon'), findsOneWidget);
    expect(find.text('Ship'), findsOneWidget);
    expect(find.text('Cosplay'), findsOneWidget);
    expect(find.textContaining('terms'), findsOneWidget);
  });

  testWidgets('glossary search narrows the list', (tester) async {
    await pumpGlossary(tester);
    await tester.enterText(find.byType(TextField).first, 'ship');
    await tester.pump();
    expect(find.text('Ship'), findsOneWidget);
    expect(find.text('Cosplay'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'zzzzz');
    await tester.pump();
    expect(find.text('No terms found'), findsOneWidget);
  });

  testWidgets('fan hub expands a guide and opens the glossary',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var openedGlossary = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FanHubScreen(
          onOpenGlossary: () => openedGlossary = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Fan Hub'), findsOneWidget);
    expect(find.text('New to fandom? Start here.'), findsOneWidget);
    expect(find.text('Find your fandom'), findsOneWidget);

    await tester.tap(find.text('Find your fandom'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('Pick one show'), findsOneWidget);

    await tester.tap(find.text('Explore glossary'));
    await tester.pump();
    expect(openedGlossary, isTrue);
  });
}
