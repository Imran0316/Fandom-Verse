import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/screens/admin/content_editor_screen.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: ContentEditorScreen()),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Advances past route transitions (dialog 150ms, editor exit ~450ms).
  Future<void> pumpSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  }

  Future<void> tapBackThenPumpDialog(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await pumpSettle(tester);
  }

  testWidgets('clean editor closes on back without asking', (tester) async {
    await pumpEditor(tester);
    expect(find.byType(ContentEditorScreen), findsOneWidget);

    await tapBackThenPumpDialog(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(ContentEditorScreen), findsNothing);
  });

  testWidgets('edited editor asks before discarding', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Half-written lore');
    await tester.pump();

    await tapBackThenPumpDialog(tester);
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await pumpSettle(tester);
    expect(find.byType(ContentEditorScreen), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);

    await tapBackThenPumpDialog(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await pumpSettle(tester);
    expect(find.byType(ContentEditorScreen), findsNothing);
  });

  testWidgets('Save Draft button asks for confirmation', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Draft title');
    await tester.pump();

    await tester.tap(find.text('Save Draft'));
    await pumpSettle(tester);

    expect(find.text('Save as draft?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await pumpSettle(tester);
    expect(find.text('Save as draft?'), findsNothing);
    expect(find.byType(ContentEditorScreen), findsOneWidget);
  });
}
