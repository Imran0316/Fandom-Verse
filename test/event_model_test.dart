import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:fandom_verse/models/catalog_docs.dart';
import 'package:fandom_verse/screens/events/event_detail_screen.dart';

void main() {
  group('FandomEventDoc', () {
    test('accepts only valid coordinate pairs for map use', () {
      const event = FandomEventDoc(
        id: 'event-1',
        title: 'Fan convention',
        city: 'Toronto',
        dateLabel: 'Oct 12',
        latitude: 43.6532,
        longitude: -79.3832,
      );
      const invalid = FandomEventDoc(
        id: 'event-2',
        title: 'Bad pin',
        city: 'Toronto',
        dateLabel: 'Oct 12',
        latitude: 91,
        longitude: 0,
      );

      expect(event.hasLocation, isTrue);
      expect(invalid.hasLocation, isFalse);
    });

    test('builds a location label from available venue details', () {
      const event = FandomEventDoc(
        id: 'event-1',
        title: 'Screening',
        city: 'Toronto',
        dateLabel: 'Oct 12',
        venue: 'Community Hall',
        address: '10 Main Street',
      );

      expect(event.locationLabel, 'Community Hall, 10 Main Street, Toronto');
      expect(event.hasDescription, isFalse);
    });

    test('serializes the event fields used by discovery and the map', () {
      final startsAt = DateTime(2026, 10, 12, 18);
      final event = FandomEventDoc(
        id: 'event-1',
        title: 'Cosplay meetup',
        city: 'Toronto',
        dateLabel: 'Oct 12',
        eventType: 'Cosplay Meetup',
        venue: 'Community Hall',
        latitude: 43.6532,
        longitude: -79.3832,
        startAt: startsAt,
        ticketUrl: 'https://tickets.example/event-1',
      );
      final data = event.toMap();

      expect(data['eventType'], 'Cosplay Meetup');
      expect(data['cityName'], 'Toronto');
      expect(data['latitude'], 43.6532);
      expect(data['longitude'], -79.3832);
      expect(data['eventDate'], isNotNull);
      expect(data['ticketUrl'], 'https://tickets.example/event-1');
    });
  });

  testWidgets('event details lays out at a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const event = FandomEventDoc(
      id: 'event-1',
      title: 'Fandom convention',
      city: 'Toronto',
      dateLabel: 'Oct 12',
      description: 'A gathering for fans.',
      venue: 'Community Hall',
      latitude: 43.6532,
      longitude: -79.3832,
      ticketUrl: 'https://tickets.example/event-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(name: '/events/detail', arguments: event),
          builder: (_) => const EventDetailScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fandom convention'), findsNWidgets(2));
    expect(find.text("I'm going"), findsOneWidget);
    expect(find.text('Open map'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
