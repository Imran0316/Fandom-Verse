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

/// Explore-first flow: the dashboard is the entry screen for everyone.
/// Signed-out visitors browse freely and hit the Get Started screen only
/// when they tap a gated action (or the Profile tab's CTA).
void main() {
  testWidgets('app opens straight into the dashboard (explore mode)', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    // Dashboard nav is visible without any sign-in step.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // No forced auth form on launch.
    expect(find.text('Join FandomVerse'), findsNothing);
  });

  testWidgets('guest profile tab offers Get Started which opens auth', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('You are exploring as a guest'), findsOneWidget);

    // Profile CTA pushes the GetStarted screen (landing first). Extra
    // pumps let the fade transition fully settle before the next tap.
    await tester.tap(find.text('Get Started').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));

    // Landing CTA opens the auth form.
    await tester.tap(find.text('Get Started').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Join FandomVerse'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Home hero does not show fake play controls', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.textContaining('trailer'), findsNothing);
  });
}
