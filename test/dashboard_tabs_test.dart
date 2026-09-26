import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/screens/dashboard/dashboard_screen.dart';
import 'package:fandom_verse/widgets/liquid_floating_nav.dart';

/// Drains pending exceptions; only the known ReelsTab/webview noise
/// (flutter_test has no webview platform) is tolerated.
List<Object> _drainExceptions(WidgetTester tester) {
  final all = <Object>[];
  for (var i = 0; i < 50; i++) {
    final error = tester.takeException();
    if (error == null) break;
    all.add(error);
  }
  return all;
}

List<Object> _unexpected(List<Object> errors) => errors
    .where((Object e) => !e.toString().contains('webview_flutter'))
    .toList();

void main() {
  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Finder navLabel(String label) => find.descendant(
        of: find.byType(LiquidFloatingNav),
        matching: find.text(label),
      );

  /// Search is the detached circle in LiquidFloatingNav — icon only, no label.
  Finder navSearch() => find.descendant(
        of: find.byType(LiquidFloatingNav),
        matching: find.byIcon(Icons.search_rounded),
      );

  testWidgets('Trending tab reads live content and shows empty fallback',
      (tester) async {
    await pumpDashboard(tester);

    await tester.tap(navLabel('Trending'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nothing trending yet'), findsOneWidget);
    expect(find.text('Trending Now'), findsOneWidget);
    expect(_unexpected(_drainExceptions(tester)), isEmpty);
  });

  testWidgets('Search tab prompts, then reports no matches', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(navSearch());
    await tester.pump();
    await tester.pump();

    expect(find.text('Search the verse'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'zzzzzzz');
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);

    await tester.tap(find.text('Merch'));
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);

    expect(_unexpected(_drainExceptions(tester)), isEmpty);
  });

  testWidgets('Search filter chips switch sections', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(navSearch());
    await tester.pump();
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Discoveries'), findsOneWidget);

    // Chips row is a horizontal ListView; Events is offscreen at 400px.
    await tester.drag(find.text('Merch'), const Offset(-220, 0));
    await tester.pump();
    expect(find.text('Events'), findsOneWidget);

    await tester.tap(find.text('Events'));
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('Search the verse'), findsNothing);

    expect(_unexpected(_drainExceptions(tester)), isEmpty);
  });
}
