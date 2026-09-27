import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fandom_verse/models/content_docs.dart';
import 'package:fandom_verse/screens/content/content_deep_dive.dart';
import 'package:fandom_verse/services/entities/anilist_provider.dart';
import 'package:fandom_verse/services/entities/deep_dive_models.dart';
import 'package:fandom_verse/services/entities/deep_dive_registry.dart';
import 'package:fandom_verse/services/entities/itunes_provider.dart';
import 'package:fandom_verse/services/entities/rawg_provider.dart';
import 'package:fandom_verse/services/entities/tvmaze_provider.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  group('domain detection', () {
    test('detects domains from fandom, tags and title, strongest first', () {
      final gaming = ContentDoc(
        id: '1',
        type: ContentType.article,
        title: 'Speedrun record finally broken',
        tags: const ['gaming', 'speedrun'],
        fandomName: 'Gaming',
      );
      expect(DeepDiveRegistry.detectDomains(gaming).first, 'games');

      final movies = ContentDoc(
        id: '2',
        type: ContentType.news,
        title: 'Big premiere this weekend',
        fandomName: 'Movies & TV',
      );
      expect(DeepDiveRegistry.detectDomains(movies).first, 'screen');

      final kpop = ContentDoc(
        id: '3',
        type: ContentType.trivia,
        title: 'Guess the comeback song',
        tags: const ['kpop', 'title track'],
      );
      expect(DeepDiveRegistry.detectDomains(kpop).first, 'music');

      final anime = ContentDoc(
        id: '4',
        type: ContentType.lore,
        title: 'The grand line explained',
        tags: const ['anime', 'manga'],
      );
      expect(DeepDiveRegistry.detectDomains(anime).first, 'anime');

      final bland = ContentDoc(
        id: '5',
        type: ContentType.article,
        title: 'Random thoughts of the day',
      );
      expect(DeepDiveRegistry.detectDomains(bland), isEmpty);
    });

    test('forContent leads with the detected domain, skips unavailable', () {
      final content = ContentDoc(
        id: '6',
        type: ContentType.news,
        title: 'Inception movie review',
        tags: const ['movie'],
      );
      final ordered = DeepDiveRegistry.forContent(
        content,
        pool: [
          AniListProvider.instance,
          TvmazeProvider(),
          RawgProvider(apiKey: ''),
          ItunesProvider.instance,
        ],
      );
      expect(ordered.first.id, 'screen');
      expect(ordered.map((p) => p.id), isNot(contains('games')));
      expect(ordered.map((p) => p.id), containsAll(['anime', 'music']));
    });
  });

  group('provider labels', () {
    test('media labels are domain and kind aware', () {
      expect(
        TvmazeProvider()
            .mediaLabel(const DiveMedia(id: 1, title: 'X', kind: 'tv')),
        'THE SHOW',
      );
      expect(
        ItunesProvider.instance
            .mediaLabel(const DiveMedia(id: 1, title: 'X', kind: 'album')),
        'THE ALBUM',
      );
      expect(
        ItunesProvider.instance
            .mediaLabel(const DiveMedia(id: 1, title: 'X', kind: 'song')),
        'THE SONG',
      );
      expect(
        AniListProvider.instance.mediaLabel(
          const DiveMedia(id: 1, title: 'X', format: 'MANGA'),
        ),
        'THE MANGA',
      );
      expect(
        RawgProvider(apiKey: 'k')
            .mediaLabel(const DiveMedia(id: 1, title: 'X', kind: 'game')),
        'THE GAME',
      );
    });
  });

  testWidgets('TV chain: show → cast → actor → other shows',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = TvmazeProvider(
      client: MockClient((request) async {
        final path = request.url.path;
        if (path == '/search/shows') {
          return http.Response(
            jsonEncode([
              {
                'score': 1.18,
                'show': {
                  'id': 169,
                  'name': 'Breaking Bad',
                  'type': 'Scripted',
                  'premiered': '2008-01-20',
                  'rating': {'average': 9.2},
                  'image': {
                    'medium':
                        'https://static.tvmaze.com/uploads/images/medium_portrait/501/1253519.jpg',
                    'original':
                        'https://static.tvmaze.com/uploads/images/original_untouched/501/1253519.jpg',
                  },
                },
              },
            ]),
            200,
          );
        }
        if (path == '/shows/169/cast') {
          return http.Response(
            jsonEncode([
              {
                'person': {
                  'id': 14245,
                  'name': 'Bryan Cranston',
                  'image': {
                    'medium':
                        'https://static.tvmaze.com/uploads/images/medium_portrait/195/488839.jpg',
                  },
                },
                'character': {
                  'id': 45529,
                  'name': 'Walter White',
                  'image': {
                    'medium':
                        'https://static.tvmaze.com/uploads/images/medium_portrait/0/2404.jpg',
                  },
                },
                'self': false,
                'voice': false,
              },
              {
                'person': {
                  'id': 12328,
                  'name': 'Aaron Paul',
                  'image': {
                    'medium':
                        'https://static.tvmaze.com/uploads/images/medium_portrait/264/660079.jpg',
                  },
                },
                'character': {
                  'id': 45531,
                  'name': 'Jesse Pinkman',
                  'image': {
                    'medium':
                        'https://static.tvmaze.com/uploads/images/medium_portrait/0/2408.jpg',
                  },
                },
                'self': false,
                'voice': false,
              },
            ]),
            200,
          );
        }
        if (path == '/people/14245/castcredits') {
          return http.Response(
            jsonEncode([
              {
                'self': false,
                'voice': false,
                '_links': {
                  'show': {
                    'href': 'https://api.tvmaze.com/shows/169',
                    'name': 'Breaking Bad',
                  },
                },
              },
              {
                'self': false,
                'voice': false,
                '_links': {
                  'show': {
                    'href': 'https://api.tvmaze.com/shows/568',
                    'name': 'Malcolm in the Middle',
                  },
                },
              },
            ]),
            200,
          );
        }
        if (path == '/shows/169') {
          return http.Response(
            jsonEncode({
              'id': 169,
              'name': 'Breaking Bad',
              'type': 'Scripted',
              'premiered': '2008-01-20',
              'rating': {'average': 9.2},
              'image': {
                'medium':
                    'https://static.tvmaze.com/uploads/images/medium_portrait/501/1253519.jpg',
              },
            }),
            200,
          );
        }
        if (path == '/shows/568') {
          return http.Response(
            jsonEncode({
              'id': 568,
              'name': 'Malcolm in the Middle',
              'type': 'Scripted',
              'premiered': '2000-01-09',
              'rating': {'average': 7.7},
              'image': {
                'medium':
                    'https://static.tvmaze.com/uploads/images/medium_portrait/164/41727.jpg',
              },
            }),
            200,
          );
        }
        return http.Response('{"error":"not found"}', 404);
      }),
    );

    final content = ContentDoc(
      id: 'm1',
      type: ContentType.article,
      title: 'Breaking Bad: the ultimate TV guide',
      tags: const ['breaking bad', 'tv'],
    );

    await tester.pumpWidget(
      _host(ContentDeepDive(content: content, providers: [provider])),
    );
    await _settle(tester);

    expect(find.text('Deep Dive'), findsOneWidget);
    expect(find.text('THE SHOW'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('CAST'), findsOneWidget);
    expect(find.text('RELATED CHARACTERS'), findsNothing);
    expect(find.text('Walter White'), findsOneWidget);
    expect(find.text('ACTOR'), findsOneWidget);
    expect(find.text('Bryan Cranston'), findsOneWidget);
    expect(find.text('as Walter White'), findsOneWidget);
    expect(find.text('MORE FROM BRYAN CRANSTON'), findsOneWidget);
    expect(find.text('Malcolm in the Middle'), findsOneWidget);
  });

  testWidgets('music chain collapses to artist → albums',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = ItunesProvider(
      client: MockClient((request) async {
        final path = request.url.path;
        if (path == '/search') {
          return http.Response(
            jsonEncode({
              'resultCount': 1,
              'results': [
                {
                  'wrapperType': 'track',
                  'kind': 'song',
                  'trackId': 1649434293,
                  'artistId': 159260351,
                  'artistName': 'Taylor Swift',
                  'trackName': 'Anti-Hero',
                  'collectionName': 'Midnights',
                  'artworkUrl100':
                      'https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg',
                  'releaseDate': '2022-10-21T00:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        if (path == '/lookup') {
          return http.Response(
            jsonEncode({
              'resultCount': 2,
              'results': [
                {
                  'wrapperType': 'artist',
                  'artistId': 159260351,
                  'artistName': 'Taylor Swift',
                },
                {
                  'wrapperType': 'collection',
                  'collectionId': 1440857781,
                  'artistId': 159260351,
                  'artistName': 'Taylor Swift',
                  'collectionName': 'Midnights',
                  'artworkUrl100':
                      'https://is1-ssl.mzstatic.com/image/thumb/y/100x100bb.jpg',
                  'releaseDate': '2022-10-21T00:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{"errorMessage":"not found"}', 404);
      }),
    );

    final content = ContentDoc(
      id: 's1',
      type: ContentType.trivia,
      title: 'Anti-Hero: Taylor Swift breakdown',
      tags: const ['taylor swift', 'music'],
    );

    await tester.pumpWidget(
      _host(ContentDeepDive(content: content, providers: [provider])),
    );
    await _settle(tester);

    expect(find.text('Deep Dive'), findsOneWidget);
    expect(find.text('THE SONG'), findsOneWidget);
    expect(find.text('Anti-Hero'), findsOneWidget);
    expect(find.text('ARTIST'), findsOneWidget);
    expect(find.text('ARTISTS'), findsNothing);
    expect(find.text('Taylor Swift'), findsOneWidget);
    expect(find.text('MORE FROM TAYLOR SWIFT'), findsOneWidget);
    expect(find.text('Midnights'), findsOneWidget);
  });

  testWidgets('games chain walks game → studio → their other games',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = RawgProvider(
      apiKey: 'test-key',
      client: MockClient((request) async {
        final path = request.url.path;
        final params = request.url.queryParameters;
        if (path.endsWith('/games') && params.containsKey('search')) {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 3265,
                  'name': 'The Legend of Zelda: Tears of the Kingdom',
                  'background_image': 'https://media.rawg.io/totk.jpg',
                  'released': '2023-05-12',
                  'rating': 4.4,
                  'metacritic': 96,
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/games') && params.containsKey('developers')) {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 3264,
                  'name': 'The Legend of Zelda: Breath of the Wild',
                  'background_image': 'https://media.rawg.io/botw.jpg',
                  'released': '2017-03-03',
                  'rating': 4.6,
                  'metacritic': 97,
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/games/3265')) {
          return http.Response(
            jsonEncode({
              'id': 3265,
              'name': 'The Legend of Zelda: Tears of the Kingdom',
              'developers': [
                {
                  'id': 694,
                  'name': 'Nintendo EPD',
                  'image_background': 'https://media.rawg.io/n.jpg',
                },
              ],
              'publishers': [
                {
                  'id': 123,
                  'name': 'Nintendo',
                  'image_background': 'https://media.rawg.io/p.jpg',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{"errors":"not found"}', 404);
      }),
    );

    final content = ContentDoc(
      id: 'g1',
      type: ContentType.article,
      title: 'Why Zelda TotK is a masterpiece',
      tags: const ['zelda', 'gaming'],
    );

    await tester.pumpWidget(
      _host(ContentDeepDive(content: content, providers: [provider])),
    );
    await _settle(tester);

    expect(find.text('Deep Dive'), findsOneWidget);
    expect(find.text('THE GAME'), findsOneWidget);
    expect(
      find.text('The Legend of Zelda: Tears of the Kingdom'),
      findsOneWidget,
    );
    expect(find.text('DEVELOPERS'), findsNothing);
    expect(find.text('STUDIO'), findsOneWidget);
    expect(find.text('Nintendo EPD'), findsOneWidget);
    expect(find.text('Developer'), findsOneWidget);
    expect(find.text('MORE FROM NINTENDO EPD'), findsOneWidget);
    expect(
      find.text('The Legend of Zelda: Breath of the Wild'),
      findsOneWidget,
    );
  });
}
