import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/widgets/article_video.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: const Color(0xFF050508), body: child),
);

void main() {
  testWidgets('degrades to a placeholder when video init fails', (tester) async {
    await tester.pumpWidget(
      _host(
        const ArticleVideo(url: 'https://example.com/clips/highlight.mp4'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ArticleVideo), findsOneWidget);
    expect(find.text('Video unavailable'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty url never throws', (tester) async {
    await tester.pumpWidget(_host(const ArticleVideo(url: '')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Video unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
