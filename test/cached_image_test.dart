import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/widgets/cached_image.dart';

void main() {
  testWidgets('CachedImage builds a real Image and survives a dead URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CachedImage(url: 'https://example.com/a.png')),
      ),
    );
    expect(find.byType(Image), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    expect(tester.takeException(), isNull);
  });

  testWidgets('CachedImage without a URL renders the placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CachedImage(url: null))),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CachedImage), findsOneWidget);
  });
}
