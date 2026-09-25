import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/content_docs.dart';
import 'package:fandom_verse/widgets/content_widgets.dart';

ContentDoc _doc({
  ContentType type = ContentType.article,
  String summary = '',
  String body = '',
  String question = '',
  ContentStatus status = ContentStatus.published,
  DateTime? publishedAt,
  List<String> tags = const [],
}) {
  return ContentDoc(
    id: 'c1',
    type: type,
    title: '10 Hidden Facts About One Piece',
    summary: summary,
    body: body,
    question: question,
    status: status,
    publishedAt: publishedAt,
    tags: tags,
    fandomName: 'Anime',
    categoryName: 'Trivia',
  );
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(backgroundColor: const Color(0xFF050508), body: child),
    );

void main() {
  group('ContentType / ContentStatus', () {
    test('maps firestore strings and defaults safely', () {
      expect(ContentType.fromString('trivia'), ContentType.trivia);
      expect(ContentType.fromString('news'), ContentType.news);
      expect(ContentType.fromString('lore'), ContentType.lore);
      expect(ContentType.fromString('article'), ContentType.article);
      expect(ContentType.fromString('unknown'), ContentType.article);
      expect(ContentType.fromString(null), ContentType.article);
    });

    test('only trivia uses the question workflow', () {
      expect(ContentType.trivia.usesQuestion, isTrue);
      expect(ContentType.article.usesQuestion, isFalse);
      expect(ContentType.news.usesQuestion, isFalse);
      expect(ContentType.lore.usesQuestion, isFalse);
    });

    test('status defaults to draft unless published', () {
      expect(ContentStatus.fromString('published'), ContentStatus.published);
      expect(ContentStatus.fromString('draft'), ContentStatus.draft);
      expect(ContentStatus.fromString(null), ContentStatus.draft);
      expect(ContentStatus.published.isPublished, isTrue);
      expect(ContentStatus.draft.isPublished, isFalse);
    });
  });

  group('ContentDoc presentation logic', () {
    test('teaser prefers summary', () {
      final doc = _doc(summary: 'Ten details fans miss.', body: 'Long body.');
      expect(doc.teaser, 'Ten details fans miss.');
    });

    test('teaser falls back to the trivia question', () {
      final doc = _doc(
        type: ContentType.trivia,
        question: "What is Luffy's first ship?",
      );
      expect(doc.teaser, "What is Luffy's first ship?");
    });

    test('teaser truncates long bodies', () {
      final doc = _doc(body: 'word ' * 80);
      expect(doc.teaser.length, lessThanOrEqualTo(141));
      expect(doc.teaser.endsWith('…'), isTrue);
    });

    test('reading time is at least one minute', () {
      expect(_doc().readingMinutes, greaterThanOrEqualTo(1));
    });

    test('display date prefers publishedAt', () {
      final published = DateTime(2026, 3, 4);
      expect(_doc(publishedAt: published).displayDate, published);
      expect(_doc().displayDate, isNull);
    });

    test('toMap carries the fields Firestore rules rely on', () {
      final map = _doc(tags: const ['one piece']).toMap();
      expect(map['type'], 'article');
      expect(map['status'], 'published');
      expect(map['tags'], ['one piece']);
      expect(map['isFeatured'], isFalse);
      expect(map['isTrending'], isFalse);
      expect(map.containsKey('createdBy'), isTrue);
    });
  });

  group('BookmarkDoc', () {
    test('toMap stores the owner and content ids', () {
      const bookmark = BookmarkDoc(
        id: 'u1_c1',
        userId: 'u1',
        contentId: 'c1',
      );
      final map = bookmark.toMap();
      expect(map['userId'], 'u1');
      expect(map['contentId'], 'c1');
    });
  });

  group('ContentRow variations', () {
    testWidgets('news renders its compact news label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentRow(
            content: _doc(type: ContentType.news, summary: 'Fresh news.'),
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('NEWS'), findsOneWidget);
    });

    testWidgets('trivia renders the question focus', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentRow(
            content: _doc(
              type: ContentType.trivia,
              question: "What is Luffy's first ship?",
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('TRIVIA'), findsOneWidget);
      expect(
        find.textContaining("What is Luffy's first ship?"),
        findsOneWidget,
      );
    });

    testWidgets('article renders an editorial eyebrow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentRow(
            content: _doc(type: ContentType.article),
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('ARTICLE'), findsOneWidget);
    });
  });

  group('ContentEmptyState', () {
    testWidgets('shows title, message and action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          ContentEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'Nothing saved yet',
            message: 'Bookmark discoveries to build your library.',
            action: () => tapped = true,
            actionLabel: 'Explore Fandoms',
          ),
        ),
      );
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.text('Explore Fandoms'), findsOneWidget);
      await tester.tap(find.text('Explore Fandoms'));
      expect(tapped, isTrue);
    });
  });
}
