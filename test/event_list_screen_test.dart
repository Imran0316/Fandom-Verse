import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/core/streams.dart';
import 'package:fandom_verse/models/catalog_docs.dart';
import 'package:fandom_verse/screens/events/event_list_screen.dart';

const MethodChannel _geoChannel = MethodChannel(
  'flutter.baseflow.com/geolocator',
);

/// Unmocked platform channels never reply under `flutter test`, which would
/// leave the screen's location request pending forever. Report "services
/// off" so the page renders its friendly fallback notice instead.
void _mockGeolocator(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _geoChannel,
    (call) async => call.method == 'isLocationServiceEnabled' ? false : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _geoChannel,
      null,
    ),
  );
}

FandomEventDoc _event() => FandomEventDoc(
  id: 'e1',
  title: 'Ek Khaas Shaam',
  city: 'Lahore',
  dateLabel: 'Oct 3',
  eventType: 'Concert',
  venue: 'DHA Sports Club',
  address: 'Block N, DHA Phase 5',
  latitude: 31.47,
  longitude: 74.41,
  description: 'Watch your favorite artists live at DHA Sports Club!',
);

Widget _host(Widget child) => MaterialApp(
  home: child,
  routes: {
    '/events/detail': (_) => const Scaffold(body: Text('DETAIL_PAGE')),
  },
);

void _setPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpEvents(WidgetTester tester) async {
  await tester.pumpWidget(
    _host(EventListScreen(eventsStream: onceStream([_event()]))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('long venue rows fit a phone-width screen without overflow', (
    tester,
  ) async {
    _setPhone(tester);
    _mockGeolocator(tester);
    await _pumpEvents(tester);

    expect(find.text('Ek Khaas Shaam'), findsOneWidget);
    expect(find.textContaining('DHA Sports Club'), findsWidgets);
    expect(find.text('Concert'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an event card opens the detail route', (tester) async {
    _setPhone(tester);
    _mockGeolocator(tester);
    await _pumpEvents(tester);

    await tester.tap(find.text('Ek Khaas Shaam'), warnIfMissed: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('DETAIL_PAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled location services fall back to a friendly notice', (
    tester,
  ) async {
    _setPhone(tester);
    _mockGeolocator(tester);
    await _pumpEvents(tester);

    expect(find.textContaining('still browse by city'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Ek Khaas Shaam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
