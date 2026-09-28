import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/core/streams.dart';
import 'package:fandom_verse/models/content_docs.dart';
import 'package:fandom_verse/screens/content/content_detail_screen.dart';
import 'package:fandom_verse/widgets/article_video.dart';

ContentDoc _doc({String? videoUrl}) => ContentDoc(
  id: 'c1',
  type: ContentType.article,
  title: '10 Hidden Facts About One Piece',
  summary: 'Ten details fans miss.',
  body: 'Paragraph one.\n\nParagraph two.',
  videoUrl: videoUrl,
  status: ContentStatus.published,
  fandomName: 'Anime',
  categoryName: 'Guides',
  publishedAt: DateTime(2026, 3, 4),
  tags: const ['one piece'],
);

Widget _host(ContentDoc doc) => MaterialApp(
  home: ContentDetailScreen(
    args: const ContentDetailArgs(contentId: 'c1'),
    contentStream: onceStream(doc),
  ),
);

/// Bounded settle: initial frame, then a few short pumps for the async
/// video init + deep-dive bootstrap to resolve. Never pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('renders the video block between the header and the body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _doc(videoUrl: 'https://res.cloudinary.com/demo/video/upload/clip.mp4'),
      ),
    );
    await _settle(tester);

    expect(find.byType(ArticleVideo), findsOneWidget);
    // VideoPlayer init fails fast in tests, so the widget must degrade to
    // its placeholder instead of hanging or throwing.
    expect(find.text('Video unavailable'), findsOneWidget);
    expect(find.text('Paragraph one.'), findsOneWidget);

    final videoTop = tester.getTopLeft(find.byType(ArticleVideo)).dy;
    final bodyTop = tester.getTopLeft(find.text('Paragraph one.')).dy;
    expect(videoTop, lessThan(bodyTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('skips the video block when no videoUrl is set', (tester) async {
    await tester.pumpWidget(_host(_doc()));
    await _settle(tester);

    expect(find.byType(ArticleVideo), findsNothing);
    expect(find.text('Video unavailable'), findsNothing);
    expect(find.text('Paragraph one.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('whitespace videoUrl is treated as no video', (tester) async {
    await tester.pumpWidget(_host(_doc(videoUrl: '   ')));
    await _settle(tester);

    expect(find.byType(ArticleVideo), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
