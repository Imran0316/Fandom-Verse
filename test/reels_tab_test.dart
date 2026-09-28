import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/core/streams.dart';
import 'package:fandom_verse/models/reel_docs.dart';
import 'package:fandom_verse/screens/reels/reels_tab.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

ReelDoc _liveReel() => ReelDoc(
  id: 'r1',
  authorUid: 'u1',
  authorName: 'Clipper',
  caption: 'My first clip',
  videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/clip.mp4',
  thumbnailUrl: 'https://res.cloudinary.com/demo/video/upload/so_1/clip.jpg',
  communityId: 'c1',
  communityName: 'Anime Hub',
  likeCount: 1234,
  commentCount: 7,
);

void main() {
  testWidgets('spotlight feed and first-reel CTA show when reels are empty', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ReelsTab(reelsStream: onceStream(const []))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('LIVE FEED'), findsOneWidget);
    expect(find.text('No reels yet — post the first one'), findsOneWidget);
    expect(find.text('COMMUNITY'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live reel renders caption, community chip and action rail', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(ReelsTab(reelsStream: onceStream([_liveReel()]))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('COMMUNITY'), findsOneWidget);
    expect(find.text('LIVE FEED'), findsNothing);
    expect(find.text('My first clip'), findsOneWidget);
    expect(find.text('Clipper'), findsOneWidget);
    expect(find.text('Anime Hub'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caption is anchored to the bottom of the reel', (tester) async {
    await tester.pumpWidget(
      _host(ReelsTab(reelsStream: onceStream([_liveReel()]))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final caption = tester.getBottomLeft(find.text('My first clip'));
    // Default test surface is 600 logical px tall; the meta card hugs the
    // lower quarter of the screen instead of floating mid-feed.
    expect(caption.dy, greaterThan(600 * 0.65));
    expect(caption.dy, lessThan(600 - 100));
    expect(tester.takeException(), isNull);
  });

  test('formatCount compacts large numbers', () {
    expect(formatCount(0), '0');
    expect(formatCount(999), '999');
    expect(formatCount(1234), '1.2k');
    expect(formatCount(15000), '15k');
    expect(formatCount(1500000), '1.5M');
    expect(formatCount(23000000), '23M');
  });
}
