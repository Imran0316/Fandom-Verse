import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:fandom_verse/models/catalog_docs.dart';
import 'package:fandom_verse/screens/events/event_map_screen.dart';
import 'package:fandom_verse/services/geocode_service.dart';

void main() {
  group('GeocodeService.parseGeocodeResponse', () {
    test('extracts location from an OK payload', () {
      final loc = GeocodeService.parseGeocodeResponse('''
      {"status":"OK","results":[{"geometry":{"location":{"lat":35.68,"lng":139.76}}}]}
      ''');
      expect(loc, isNotNull);
      expect(loc!.lat, 35.68);
      expect(loc.lng, 139.76);
    });

    test('returns null for error payloads and garbage', () {
      expect(
        GeocodeService.parseGeocodeResponse('{"status":"ZERO_RESULTS","results":[]}'),
        isNull,
      );
      expect(GeocodeService.parseGeocodeResponse('not json at all'), isNull);
      expect(GeocodeService.parseGeocodeResponse('[]'), isNull);
    });
  });

  group('GeocodeService.fetch', () {
    test('fetches, parses and memoizes a city', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/maps/api/geocode/json');
        expect(request.url.queryParameters['address'], 'Tokyo');
        return http.Response(
          '{"status":"OK","results":[{"geometry":{"location":{"lat":1,"lng":2}}}]}',
          200,
        );
      });
      final service = GeocodeService(client: client, apiKey: 'test-key');

      final first = await service.geocode('Tokyo');
      final second = await service.geocode('tokyo  ');
      expect(first?.lat, 1);
      expect(second?.lng, 2);
      expect(calls, 1, reason: 'second lookup must hit the memo cache');
    });

    test('never throws when the network fails', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      final service = GeocodeService(client: client, apiKey: 'test-key');
      expect(await service.geocode('Osaka'), isNull);
    });
  });

  group('EventMapScreen', () {
    FandomEventDoc event({
      required String id,
      required String title,
      required String city,
      String? ticketUrl,
    }) {
      return FandomEventDoc(
        id: id,
        title: title,
        city: city,
        dateLabel: 'Jul 12',
        startAt: DateTime(2026, 7, 12, 18),
        ticketUrl: ticketUrl,
      );
    }

    Future<void> pumpMap(
      WidgetTester tester, {
      required List<FandomEventDoc> events,
      Future<({double lat, double lng})?> Function(String city)? geocode,
      Widget Function(dynamic, dynamic)? mapBuilder,
      void Function(String url)? onOpenTicket,
    }) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: EventMapScreen(
            eventsStream: Stream.value(events),
            geocode: geocode,
            mapBuilder: mapBuilder == null
                ? null
                : (center, markers) => mapBuilder(center, markers),
            onOpenTicket: onOpenTicket,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('geocodes each city and renders one marker per event',
        (tester) async {
      final asked = <String>[];
      await pumpMap(
        tester,
        events: [
          event(id: 'a', title: 'Tokyo Meetup', city: 'Tokyo'),
          event(id: 'b', title: 'Osaka Fest', city: 'Osaka'),
        ],
        geocode: (city) async {
          asked.add(city);
          return (lat: 1.0, lng: 2.0);
        },
        mapBuilder: (center, markers) => Text('markers:${markers.length}'),
      );

      expect(find.text('markers:2'), findsOneWidget);
      expect(find.text('2 cities'), findsOneWidget);
      expect(asked, containsAll(['Tokyo', 'Osaka']));
      expect(find.text('Tokyo Meetup'), findsNothing, reason: 'no card until a marker is tapped');
    });

    testWidgets('falls back to the event list when geocoding fails',
        (tester) async {
      String? opened;
      await pumpMap(
        tester,
        events: [
          event(
            id: 'a',
            title: 'Tokyo Meetup',
            city: 'Tokyo',
            ticketUrl: 'https://tickets.example/a',
          ),
          event(id: 'b', title: 'Osaka Fest', city: 'Osaka'),
        ],
        geocode: (_) async => null,
        onOpenTicket: (url) => opened = url,
      );

      expect(
        find.textContaining('Map locations are unavailable'),
        findsOneWidget,
      );
      expect(find.text('Tokyo Meetup'), findsOneWidget);
      expect(find.text('Osaka Fest'), findsOneWidget);
      expect(find.text('Get tickets'), findsOneWidget);
      await tester.tap(find.text('Get tickets'));
      await tester.pump();
      expect(opened, 'https://tickets.example/a');
    });

    testWidgets('shows an empty state when there are no events',
        (tester) async {
      await pumpMap(tester, events: const []);
      expect(find.text('No events yet'), findsOneWidget);
    });
  });
}
