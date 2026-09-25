import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/screens/dashboard/dashboard_screen.dart';

/// Drains all pending exceptions from [tester].
///
/// Known test-env-only noise: ReelsTab eagerly built by IndexedStack mounts
/// a YouTube webview, and webview_flutter has no platform registered under
/// `flutter test` (the app guards this path with kIsWeb on web). Anything
/// else — including "Stream has already been listened to" — is a failure.
List<Object> _drainExceptions(WidgetTester tester) {
  final all = <Object>[];
  for (var i = 0; i < 50; i++) {
    final error = tester.takeException();
    if (error == null) break;
    all.add(error);
  }
  return all;
}

List<Object> _unexpected(List<Object> errors) {
  return errors
      .where((Object e) => !e.toString().contains('webview_flutter'))
      .toList();
}

void main() {
  testWidgets('Dashboard renders with fallback streams and no exceptions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
    expect(_unexpected(_drainExceptions(tester)), isEmpty);

    // Rebuild the whole tree: every inline StreamBuilder gets a brand-new
    // stream object and must resubscribe without "already been listened to".
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(_unexpected(_drainExceptions(tester)), isEmpty);

    // Scroll the home list so lazy children and their StreamBuilders mount.
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_unexpected(_drainExceptions(tester)), isEmpty);
  });
}
