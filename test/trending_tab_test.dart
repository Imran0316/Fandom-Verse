import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/core/streams.dart';
import 'package:fandom_verse/models/catalog_docs.dart';
import 'package:fandom_verse/models/community_docs.dart';
import 'package:fandom_verse/models/post_docs.dart';
import 'package:fandom_verse/models/reel_docs.dart';
import 'package:fandom_verse/screens/dashboard/trending_tab.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

PostDoc _post(
  String id, {
  String body = '',
  int likes = 0,
  int comments = 0,
}) => PostDoc(
  id: id,
  authorUid: 'author-$id',
  authorName: 'Fan $id',
  body: body,
  likeCount: likes,
  commentCount: comments,
);

ReelDoc _reel(String id) => ReelDoc(
  id: id,
  authorUid: 'u1',
  authorName: 'Clipper',
  caption: 'Clip $id',
  videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/$id.mp4',
  communityId: 'c1',
  communityName: 'Community c1',
);

CommunityDoc _community(String id, {int members = 1}) => CommunityDoc(
  id: id,
  name: 'Community $id',
  ownerUid: 'owner-1',
  memberCount: members,
);

FandomEventDoc _event(String id, String title) =>
    FandomEventDoc(id: id, title: title, city: 'Lagos', dateLabel: 'Sat 12');

void _setSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  testWidgets('renders every live section when streams have data', (
    tester,
  ) async {
    _setSurface(tester);
    await tester.pumpWidget(
      _host(
        TrendingTab(
          postsStream: onceStream([_post('a', body: 'Top fan take')]),
          reelsStream: onceStream([_reel('r1')]),
          communitiesStream: onceStream([_community('c1', members: 42)]),
          eventsStream: onceStream([_event('e1', 'Anime Expo')]),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Fan posts on fire'), findsOneWidget);
    expect(find.text('Reels on fire'), findsOneWidget);
    expect(find.text('Rising communities'), findsOneWidget);
    expect(find.text('Events on the horizon'), findsOneWidget);
    expect(find.text('Top fan take'), findsOneWidget);
    expect(find.text('Anime Expo'), findsOneWidget);
    expect(find.text('Community c1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranks hot posts by heat (likes + comments x2)', (tester) async {
    _setSurface(tester);
    await tester.pumpWidget(
      _host(
        TrendingTab(
          postsStream: onceStream([
            _post('cold', body: 'Cold take', likes: 1),
            _post('hot', body: 'Blazing hot take', comments: 5),
          ]),
          reelsStream: onceStream(const <ReelDoc>[]),
          communitiesStream: onceStream(const <CommunityDoc>[]),
          eventsStream: onceStream(const <FandomEventDoc>[]),
        ),
      ),
    );
    await _settle(tester);

    final hot = tester.getTopLeft(find.text('Blazing hot take'));
    final cold = tester.getTopLeft(find.text('Cold take'));
    expect(hot.dy, lessThan(cold.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Watch action hands off to the reels tab', (tester) async {
    _setSurface(tester);
    var opened = false;
    await tester.pumpWidget(
      _host(
        TrendingTab(
          postsStream: onceStream(const <PostDoc>[]),
          reelsStream: onceStream([_reel('r1')]),
          communitiesStream: onceStream(const <CommunityDoc>[]),
          eventsStream: onceStream(const <FandomEventDoc>[]),
          onOpenReels: () => opened = true,
        ),
      ),
    );
    await _settle(tester);

    final watch = find.text('Watch ›');
    expect(watch, findsOneWidget);
    await tester.ensureVisible(watch);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(watch);
    expect(opened, isTrue);
  });

  testWidgets('quiet card shows only when every stream is empty', (
    tester,
  ) async {
    _setSurface(tester);
    await tester.pumpWidget(
      _host(
        TrendingTab(
          postsStream: onceStream(const <PostDoc>[]),
          reelsStream: onceStream(const <ReelDoc>[]),
          communitiesStream: onceStream(const <CommunityDoc>[]),
          eventsStream: onceStream(const <FandomEventDoc>[]),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('The verse is warming up'), findsOneWidget);
    expect(find.textContaining('Nothing is trending yet'), findsOneWidget);
    expect(find.text('Fan posts on fire'), findsNothing);
    expect(find.text('Reels on fire'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
