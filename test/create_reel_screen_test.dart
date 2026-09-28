import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/core/streams.dart';
import 'package:fandom_verse/models/community_docs.dart';
import 'package:fandom_verse/screens/reels/create_reel_screen.dart';

Widget _host(Widget child) => MaterialApp(home: child);

CommunityDoc _community(String id, String name) =>
    CommunityDoc(id: id, name: name, ownerUid: 'owner-1');

Future<void> _dismissSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('renders composer with caption field and post action', (
    tester,
  ) async {
    final community = _community('c1', 'Anime Hub');
    await tester.pumpWidget(
      _host(
        CreateReelScreen(
          initialCommunity: community,
          joinedCommunities: onceStream([community]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('New reel'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Post reel'), findsOneWidget);
    expect(find.text('Anime Hub'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting without a video shows validation snack', (
    tester,
  ) async {
    final community = _community('c1', 'Anime Hub');
    await tester.pumpWidget(
      _host(
        CreateReelScreen(
          initialCommunity: community,
          joinedCommunities: onceStream([community]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Post reel'));
    await tester.pump();

    expect(find.text('Pick a video first.'), findsOneWidget);
    await _dismissSnack(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty community list shows join prompt', (tester) async {
    await tester.pumpWidget(
      _host(CreateReelScreen(joinedCommunities: onceStream(const []))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('No community selected'), findsOneWidget);
    expect(find.text('Browse communities'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
