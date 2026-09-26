import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/catalog_docs.dart';
import 'package:fandom_verse/screens/events/event_calendar_screen.dart';

FandomEventDoc _event({
  required String id,
  required String title,
  required String city,
  required DateTime startAt,
  String? ticketUrl,
  String dateLabel = 'TBD',
}) {
  return FandomEventDoc(
    id: id,
    title: title,
    city: city,
    dateLabel: dateLabel,
    startAt: startAt,
    ticketUrl: ticketUrl,
  );
}

void main() {
  late DateTime today;
  late List<FandomEventDoc> events;

  setUp(() {
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day, 18);
    events = [
      _event(
        id: 'e1',
        title: 'Tokyo Anime Meetup',
        city: 'Tokyo',
        startAt: today,
        dateLabel: 'Today',
        ticketUrl: 'https://tickets.example/tokyo',
      ),
      _event(
        id: 'e2',
        title: 'Osaka Fan Concert',
        city: 'Osaka',
        startAt: today.add(const Duration(days: 40)),
        dateLabel: 'Later',
        ticketUrl: 'https://tickets.example/osaka',
      ),
      _event(
        id: 'e3',
        title: 'Paris Expo',
        city: 'Paris',
        startAt: today.subtract(const Duration(days: 10)),
        dateLabel: 'Past',
      ),
    ];
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    void Function(String url)? onOpenTicket,
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: EventCalendarScreen(
          eventsStream: Stream.value(events),
          onOpenTicket: onOpenTicket,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders all events with city chips', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Tokyo Anime Meetup'), findsOneWidget);
    expect(find.text('Osaka Fan Concert'), findsOneWidget);
    expect(find.text('Paris Expo'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('city-chip-All')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('city-chip-Tokyo')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('city-chip-Osaka')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('city-chip-Paris')), findsOneWidget);
  });

  testWidgets('city chip filters the event list', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey<String>('city-chip-Osaka')));
    await tester.pump();
    expect(find.text('Osaka Fan Concert'), findsOneWidget);
    expect(find.text('Tokyo Anime Meetup'), findsNothing);
    expect(find.text('Paris Expo'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('city-chip-All')));
    await tester.pump();
    expect(find.text('Tokyo Anime Meetup'), findsOneWidget);
    expect(find.text('Paris Expo'), findsOneWidget);
  });

  testWidgets('tapping a calendar day filters to that day', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(ValueKey<int>(today.day)));
    await tester.pump();
    expect(find.text('Tokyo Anime Meetup'), findsOneWidget);
    expect(find.text('Osaka Fan Concert'), findsNothing);
    expect(find.text('Paris Expo'), findsNothing);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Osaka Fan Concert'), findsOneWidget);
    expect(find.text('Paris Expo'), findsOneWidget);
  });

  testWidgets('Get tickets opens the event ticket URL', (tester) async {
    String? opened;
    await pumpScreen(
      tester,
      onOpenTicket: (url) => opened = url,
    );
    // Paris has no ticket link, so only two buttons are rendered; the first
    // belongs to the earliest dated ticketed event (Tokyo, today).
    expect(find.text('Get tickets'), findsNWidgets(2));
    await tester.tap(find.text('Get tickets').first);
    await tester.pump();
    expect(opened, 'https://tickets.example/tokyo');
  });

  testWidgets('day + city with no match shows empty state and clears',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(ValueKey<int>(today.day)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('city-chip-Osaka')));
    await tester.pump();
    expect(find.text('No events match this filter'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('Tokyo Anime Meetup'), findsOneWidget);
    expect(find.text('Osaka Fan Concert'), findsOneWidget);
    expect(find.text('Paris Expo'), findsOneWidget);
  });
}
