import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/widgets/expandable_text.dart';

void main() {
  const longText =
      'Can we all agree that Bayju Noyan was the best villain in the whole '
      'show and no one else could have played this role better, an '
      'incredible performance across every single episode of the series.';

  testWidgets('Long caption clamps to 2 lines and expands via See More', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: ExpandableText(
              text: longText,
              maxLines: 2,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );

    expect(find.text('See More'), findsOneWidget);
    expect(tester.widget<Text>(find.text(longText)).maxLines, 2);

    await tester.tap(find.text('See More'));
    await tester.pump();

    expect(find.text('See Less'), findsOneWidget);
    expect(find.text('See More'), findsNothing);
    expect(tester.widget<Text>(find.text(longText)).maxLines, isNull);

    await tester.tap(find.text('See Less'));
    await tester.pump();

    expect(find.text('See More'), findsOneWidget);
    expect(tester.widget<Text>(find.text(longText)).maxLines, 2);
  });

  testWidgets('Short caption shows no See More toggle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: ExpandableText(
              text: 'Short and sweet',
              maxLines: 2,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Short and sweet'), findsOneWidget);
    expect(find.text('See More'), findsNothing);
    expect(find.text('See Less'), findsNothing);
  });
}
