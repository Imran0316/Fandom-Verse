import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/community_docs.dart';
import 'package:fandom_verse/models/user_profile.dart';
import 'package:fandom_verse/screens/communities/edit_community_screen.dart';
import 'package:fandom_verse/screens/profile/follow_requests_screen.dart';
import 'package:fandom_verse/screens/profile/user_profile_screen.dart';
import 'package:fandom_verse/widgets/follow_button.dart';

void main() {
  testWidgets('Edit community form prefills from the passed community', (
    tester,
  ) async {
    const community = CommunityDoc(
      id: 'c1',
      name: 'Anime Hub',
      ownerUid: 'owner1',
      description: 'All things anime',
      iconName: 'anime',
      colorName: 'purple',
    );

    await tester.pumpWidget(
      const MaterialApp(home: EditCommunityScreen(community: community)),
    );
    await tester.pump();

    expect(find.text('Edit community'), findsOneWidget);
    expect(find.text('Anime Hub'), findsOneWidget);
    expect(find.text('All things anime'), findsOneWidget);
    expect(find.text('Cover image'), findsOneWidget);
    expect(find.text('Profile image'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Save changes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Follow requests inbox renders the empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FollowRequestsScreen()),
    );
    await tester.pump();

    expect(find.text('Follow requests'), findsOneWidget);
    expect(find.text('No pending requests'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Follow button settles on Follow and fails safely when signed '
      'out', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: FollowButton(targetUid: 'u2')),
        ),
      ),
    );
    // Let the one-shot relationship checks resolve.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Follow'), findsOneWidget);

    // Tapping without a session must not crash — it reverts and opens the
    // sign-in popup instead of following anyone.
    await tester.tap(find.text('Follow'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Follow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile screen falls back to not-found without Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: UserProfileScreen(uid: 'missing')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Profile not found'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('UserProfile copyWith carries followingCount', () {
    const profile = UserProfile(
      uid: 'u1',
      name: 'Ada',
      email: 'ada@example.com',
      followerCount: 10,
    );
    expect(profile.followingCount, 0);

    final updated = profile.copyWith(followingCount: 4, followerCount: 12);
    expect(updated.followingCount, 4);
    expect(updated.followerCount, 12);
    expect(updated.uid, 'u1');
    expect(updated.name, 'Ada');
  });
}
