import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/reel_docs.dart';
import 'package:fandom_verse/screens/reels/reel_comments_sheet.dart';

ReelDoc _reel() => ReelDoc(
  id: 'r1',
  authorUid: 'u1',
  authorName: 'Clipper',
  caption: 'My first clip',
  videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/clip.mp4',
  communityId: 'c1',
  communityName: 'Anime Hub',
  commentCount: 3,
);

void main() {
  /// Host with the named GetStarted route registered — the explore-mode
  /// gate navigates to it when a signed-out user tries to comment.
  Widget host() => MaterialApp(
        routes: {
          '/': (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showReelCommentsSheet(context, _reel()),
                  child: const Text('open'),
                ),
              ),
        },
      );

  testWidgets('sheet opens with header, list and composer', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('No comments yet — start the conversation.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-out send surfaces a friendly sign-in message', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'Nice one!');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();

    // The gate surfaces the sign-in message (snackbar) and pushes the
    // GetStarted route.
    expect(find.text('Sign in to comment on reels.'), findsWidgets);

    // Let the snackbar dismiss so no timers are left pending.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
