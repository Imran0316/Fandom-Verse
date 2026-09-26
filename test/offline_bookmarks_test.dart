import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fandom_verse/models/content_docs.dart';
import 'package:fandom_verse/screens/content/saved_screen.dart';
import 'package:fandom_verse/services/offline_bookmark_store.dart';

Map<String, dynamic> _entry({String id = 'c1', String title = 'Offline Pick'}) {
  return OfflineBookmarkStore.entryFor(
    id: id,
    title: title,
    summary: 'A cached discovery body',
    fandomName: 'Anime',
    categoryName: 'Lore',
    type: 'article',
    savedAt: DateTime.fromMillisecondsSinceEpoch(1750000000000),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineBookmarkStore', () {
    test('round-trips entries through shared_preferences', () async {
      SharedPreferences.setMockInitialValues({
        OfflineBookmarkStore.prefsKey: [jsonEncode(_entry())],
      });
      final store = OfflineBookmarkStore();

      final read = await store.readAll();
      expect(read, hasLength(1));
      expect(read.first['title'], 'Offline Pick');
      expect(read.first['id'], 'c1');

      await store.writeAll([_entry(id: 'a'), _entry(id: 'b', title: 'Two')]);
      expect(await store.readAll(), hasLength(2));

      await store.remove('a');
      final after = await store.readAll();
      expect(after, hasLength(1));
      expect(after.first['id'], 'b');
    });

    test('never throws on corrupt payloads', () async {
      SharedPreferences.setMockInitialValues({
        OfflineBookmarkStore.prefsKey: ['{not valid json'],
      });
      final store = OfflineBookmarkStore();
      expect(await store.readAll(), isEmpty);
    });
  });

  group('SavedScreen', () {
    Future<void> pumpSaved(
      WidgetTester tester, {
      required Stream<List<ContentDoc>>? content,
      required Stream<List<BookmarkDoc>>? bookmarks,
      required OfflineBookmarkStore store,
    }) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SavedScreen(
            contentStream: content,
            bookmarkStream: bookmarks,
            store: store,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('renders the offline cache when streams never emit',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        OfflineBookmarkStore.prefsKey: [jsonEncode(_entry())],
      });
      final store = OfflineBookmarkStore();

      await pumpSaved(
        tester,
        content: const Stream.empty(),
        bookmarks: const Stream.empty(),
        store: store,
      );

      expect(find.text('Offline Pick'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('1 saved discovery (offline)'), findsOneWidget);
    });

    testWidgets('cached rows can be removed and the cache updates',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        OfflineBookmarkStore.prefsKey: [jsonEncode(_entry())],
      });
      final store = OfflineBookmarkStore();

      await pumpSaved(
        tester,
        content: const Stream.empty(),
        bookmarks: const Stream.empty(),
        store: store,
      );

      await tester.tap(find.byIcon(Icons.bookmark_remove_outlined));
      await tester.pump();

      expect(find.text('Offline Pick'), findsNothing);
      expect(await store.readAll(), isEmpty);
    });

    testWidgets('live-empty still shows the standard empty state',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        OfflineBookmarkStore.prefsKey: <String>[],
      });
      final store = OfflineBookmarkStore();

      await pumpSaved(
        tester,
        content: Stream<List<ContentDoc>>.value(const []),
        bookmarks: Stream<List<BookmarkDoc>>.value(const []),
        store: store,
      );

      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.text('OFFLINE'), findsNothing);
    });
  });
}
