import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/app.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const FandomVerseApp());
  // Splash timeline (fake time): reveal/nav timer 2.4s + bounded Firebase
  // ready poll (8s, never ready in tests — auth restore wait is skipped
  // when Firebase isn't ready) = ~10.4s, then the route transition.
  await tester.pump(const Duration(milliseconds: 12000));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('Get Started screen is minimal', (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('Get Started'), findsOneWidget);
    expect(
      find.textContaining('Privacy Policy', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Join FandomVerse'), findsNothing);
    expect(find.text('Create Account'), findsNothing);
  });

  testWidgets('Get Started opens auth form', (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Get Started'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Join FandomVerse'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Home hero does not show fake play controls', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Get Started'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.textContaining('trailer'), findsNothing);
  });
}
