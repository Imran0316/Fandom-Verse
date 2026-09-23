import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/app.dart';

void main() {
  testWidgets('Get Started screen is minimal', (WidgetTester tester) async {
    await tester.pumpWidget(const FandomVerseApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Get Started'), findsOneWidget);
    expect(
      find.textContaining('Privacy Policy', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('FandomVerse'), findsNothing);
    expect(find.text('Create Account'), findsNothing);
    expect(find.textContaining('Dancing between'), findsNothing);
  });

  testWidgets('Get Started opens auth form', (WidgetTester tester) async {
    await tester.pumpWidget(const FandomVerseApp());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Get Started'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Join FandomVerse'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Home hero does not show fake play controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FandomVerseApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.textContaining('trailer'), findsNothing);
  });
}
