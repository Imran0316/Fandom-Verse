import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/core/streams.dart';
import 'package:fandom_verse/models/post_docs.dart';
import 'package:fandom_verse/screens/communities/communities_screen.dart';
import 'package:fandom_verse/screens/communities/feed_screen.dart';
import 'package:fandom_verse/screens/communities/post_card.dart';

/// Lets a test force a full rebuild of its child — the kind of rebuild route
/// pushes, keyboard changes and MediaQuery changes trigger on the routes
/// underneath.
class RebuildHost extends StatefulWidget {
  const RebuildHost({super.key, required this.child});

  final Widget child;

  @override
  State<RebuildHost> createState() => RebuildHostState();
}

class RebuildHostState extends State<RebuildHost> {
  /// Forces a rebuild of the child, as route pushes and keyboard changes do.
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.child;
}

PostDoc _post() => const PostDoc(
      id: 'p1',
      authorUid: 'u1',
      authorName: 'Ada',
      body: 'Hello fandom world',
      likeCount: 3,
      commentCount: 1,
    );

void main() {
  test('onceStream can be listened to more than once', () async {
    final stream = onceStream(7);
    expect(await stream.toList(), [7]);
    expect(await stream.toList(), [7]);
  });

  testWidgets('post interactions never remount the card', (tester) async {
    final hostKey = GlobalKey<RebuildHostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RebuildHost(
            key: hostKey,
            child: ListView(children: [PostCard(post: _post())]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final card = tester.element(find.byType(PostCard));

    // Like tap (falls back to a snackbar in tests — must not tear down).
    await tester.tap(find.text('3'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.element(find.byType(PostCard)), same(card));

    // Comment chip opens the thread in place.
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(find.text('Add a comment…'), findsOneWidget);
    expect(tester.element(find.byType(PostCard)), same(card));

    // Tapping the post body closes it again — same element throughout.
    await tester.tap(find.text('Hello fandom world'));
    await tester.pump();
    expect(find.text('Add a comment…'), findsNothing);
    expect(tester.element(find.byType(PostCard)), same(card));

    // A parent rebuild (route push / keyboard) keeps the same element.
    hostKey.currentState!.rebuild();
    await tester.pump();
    expect(tester.element(find.byType(PostCard)), same(card));

    expect(tester.takeException(), isNull);
  });

  testWidgets('comment thread survives close, reopen and rebuilds', (
    tester,
  ) async {
    final hostKey = GlobalKey<RebuildHostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RebuildHost(
            key: hostKey,
            child: ListView(children: [PostCard(post: _post())]),
          ),
        ),
      ),
    );
    await tester.pump();

    Future<void> toggleComments() async {
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    await toggleComments();
    expect(find.text('No comments yet'), findsOneWidget);
    expect(find.text('Add a comment…'), findsOneWidget);

    await toggleComments();
    expect(find.text('Add a comment…'), findsNothing);

    await toggleComments();
    expect(find.text('Add a comment…'), findsOneWidget);

    hostKey.currentState!.rebuild();
    await tester.pump();
    expect(find.text('Add a comment…'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('feed keeps content across rebuilds (no spinner flash)', (
    tester,
  ) async {
    final hostKey = GlobalKey<RebuildHostState>();
    await tester.pumpWidget(
      MaterialApp(home: RebuildHost(key: hostKey, child: const FeedScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Feed is quiet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    for (var i = 0; i < 3; i++) {
      hostKey.currentState!.rebuild();
      await tester.pump();
    }

    expect(find.text('Feed is quiet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('communities list keeps content across rebuilds', (
    tester,
  ) async {
    final hostKey = GlobalKey<RebuildHostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: RebuildHost(key: hostKey, child: const CommunitiesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No communities found'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    for (var i = 0; i < 3; i++) {
      hostKey.currentState!.rebuild();
      await tester.pump();
    }

    expect(find.text('No communities found'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
