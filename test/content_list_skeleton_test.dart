import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/widgets/skeletons.dart';

void main() {
  testWidgets('list skeleton clips inside a tight 400px box without overflow', (
    tester,
  ) async {
    // Regression: a Column of 5 rows (~490px) inside a tight, shorter
    // Expanded (e.g. 451px on Explore) asserted a RenderFlex overflow.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 400,
              child: ContentListSkeleton(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ContentListSkeleton), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list skeleton sizes to its content in an unbounded parent', (
    tester,
  ) async {
    // Mirrors admin/content_management.dart, where the skeleton sits in a
    // SingleChildScrollView with no height bound.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ContentListSkeleton(count: 4)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // 4 rows x (84px thumbnail + 14px bottom padding) = 392px.
    expect(
      tester.getSize(find.byType(ContentListSkeleton)),
      const Size(800, 392),
    );
  });
}
