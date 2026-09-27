import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fandom_verse/models/content_docs.dart';
import 'package:fandom_verse/screens/content/content_deep_dive.dart';
import 'package:fandom_verse/services/entities/anilist_provider.dart';
import 'package:fandom_verse/services/entities/deep_dive_models.dart';

const Map<String, dynamic> _mediaJson = {
  'id': 21,
  'title': {'romaji': 'ONE PIECE', 'english': 'ONE PIECE'},
  'coverImage': {'large': 'https://example.com/one-piece.jpg'},
  'startDate': {'year': 1999},
  'format': 'TV',
  'averageScore': 87,
  'characters': {
    'edges': [
      {
        'role': 'MAIN',
        'node': {
          'id': 40,
          'name': {'full': 'Luffy Monkey'},
          'image': {'large': 'https://example.com/luffy.png'},
        },
        'voiceActors': [
          {
            'id': 95075,
            'name': {'full': 'Mayumi Tanaka'},
            'image': {'large': 'https://example.com/tanaka.png'},
          },
        ],
      },
      {
        'role': 'SUPPORTING',
        'node': {
          'id': 41,
          'name': {'full': 'Zoro Roronoa'},
          'image': {'large': 'https://example.com/zoro.png'},
        },
        'voiceActors': <Map<String, dynamic>>[],
      },
    ],
  },
};

const Map<String, dynamic> _staffJson = {
  'id': 95075,
  'name': {'full': 'Mayumi Tanaka'},
  'image': {'large': 'https://example.com/tanaka.png'},
  'staffMedia': {
    'nodes': [
      {
        'id': 1165,
        'title': {'romaji': 'Sakura Taisen', 'english': null},
        'coverImage': {'large': 'https://example.com/sakura.jpg'},
        'startDate': {'year': 1997},
        'format': 'OVA',
      },
    ],
  },
};

MockClient _fixtureClient() => MockClient((request) async {
      final body = request.body;
      if (body.contains('Staff(')) {
        return http.Response(
          jsonEncode({
            'data': {'Staff': _staffJson},
          }),
          200,
        );
      }
      if (body.contains('Page(')) {
        return http.Response(
          jsonEncode({
            'data': {
              'Page': {
                'media': [_mediaJson],
              },
            },
          }),
          200,
        );
      }
      if (body.contains('Media(')) {
        return http.Response(
          jsonEncode({
            'data': {'Media': _mediaJson},
          }),
          200,
        );
      }
      return http.Response('{"errors":[{"message":"unexpected"}]}', 400);
    });

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('AniList parsing', () {
    test('parses media with cast and voice actors', () async {
      final provider = AniListProvider(client: _fixtureClient());
      final results = await provider.search('one piece');
      final media = results.single;
      expect(media.id, 21);
      expect(media.title, 'ONE PIECE');
      expect(media.year, 1999);
      expect(media.score, 87);
      expect(media.cast, hasLength(2));
      expect(media.cast.first.role, 'MAIN');
      expect(media.cast.first.character.name, 'Luffy Monkey');
      expect(media.cast.first.voiceActors.single.name, 'Mayumi Tanaka');
      expect(media.cast.last.role, 'SUPPORTING');
      expect(media.cast.last.voiceActors, isEmpty);
    });

    test('resolves a person with their other works', () async {
      final provider = AniListProvider(client: _fixtureClient());
      final person = await provider.loadPerson(
        const DivePerson(id: 95075, name: 'Mayumi Tanaka'),
      );
      expect(person, isNotNull);
      expect(person!.id, 95075);
      expect(person.name, 'Mayumi Tanaka');
      expect(person.works, hasLength(1));
      expect(person.works.single.title, 'Sakura Taisen');
      expect(person.works.single.year, 1997);
    });
  });

  group('anchorQueries', () {
    test('skips generic tags, dedupes, keeps title, caps at three', () {
      final content = ContentDoc(
        id: 'c1',
        type: ContentType.news,
        title: 'Latest Anime Universe News',
        tags: ['anime', 'news', 'one piece', 'One Piece', 'world'],
      );
      expect(
        ContentDeepDive.anchorQueries(content),
        ['one piece', 'Latest Anime Universe News'],
      );

      final article = ContentDoc(
        id: 'c2',
        type: ContentType.article,
        title: 'One Piece guide',
        tags: const ['grand line', 'one piece', 'straw hats'],
      );
      expect(
        ContentDeepDive.anchorQueries(article),
        ['grand line', 'one piece', 'straw hats'],
      );
    });
  });

  testWidgets('renders the full chain from a fixture response',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = AniListProvider(client: _fixtureClient());

    final content = ContentDoc(
      id: 'c1',
      type: ContentType.trivia,
      title: '10 Hidden Facts About One Piece',
      tags: const ['one piece', 'anime'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContentDeepDive(content: content, providers: [provider]),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Deep Dive'), findsOneWidget);
    expect(find.text('THE ANIME'), findsOneWidget);
    expect(find.text('ONE PIECE'), findsOneWidget);
    expect(find.text('RELATED CHARACTERS'), findsOneWidget);
    expect(find.text('Luffy Monkey'), findsOneWidget);
    expect(find.text('VOICE ACTOR'), findsOneWidget);
    expect(find.text('Mayumi Tanaka'), findsOneWidget);
    expect(find.text('Voice of Luffy Monkey'), findsOneWidget);
    expect(find.text('MORE FROM MAYUMI TANAKA'), findsOneWidget);
    expect(find.text('Sakura Taisen'), findsOneWidget);
  });

  testWidgets('hides itself when nothing matches the story',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = AniListProvider(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'data': {
              'Page': {'media': []},
            },
          }),
          200,
        );
      }),
    );

    final content = ContentDoc(
      id: 'c1',
      type: ContentType.news,
      title: 'Latest Anime Universe News',
      tags: const ['anime', 'news', 'season'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContentDeepDive(content: content, providers: [provider]),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Deep Dive'), findsNothing);
  });
}
