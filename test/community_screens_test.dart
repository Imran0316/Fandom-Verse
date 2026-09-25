import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/post_docs.dart';
import 'package:fandom_verse/screens/communities/communities_screen.dart';
import 'package:fandom_verse/screens/communities/community_detail_screen.dart';
import 'package:fandom_verse/screens/communities/post_card.dart';

void main() {
  testWidgets('Create community form has cover and profile image sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CreateCommunityScreen()),
    );

    expect(find.text('New community'), findsOneWidget);
    expect(find.text('Community name'), findsOneWidget);
    expect(find.text('Cover image'), findsOneWidget);
    expect(find.text('Profile image'), findsOneWidget);
    expect(find.text('Tap to add a cover'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Create community'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Create community'), findsOneWidget);
  });

  testWidgets('Community detail shows not-found with a back button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CommunityDetailScreen(communityId: 'missing')),
    );
    await tester.pump();

    expect(find.text('Community not found'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('PostCard renders image posts and a share action', (
    WidgetTester tester,
  ) async {
    final post = PostDoc(
      id: 'p1',
      authorUid: 'u1',
      authorName: 'Ada',
      body: 'Look at this',
      imageUrl: 'https://example.com/fan-art.png',
      likeCount: 3,
      commentCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PostCard(post: post))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Look at this'), findsOneWidget);
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('PostCard with no body and no image still renders actions', (
    WidgetTester tester,
  ) async {
    final post = PostDoc(id: 'p2', authorUid: 'u2', authorName: 'Bob');

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PostCard(post: post))),
    );
    await tester.pump();

    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });
}
