import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/services/auth_service.dart';
import 'package:fandom_verse/services/stream_cache.dart';

class _TwoBuilders extends StatelessWidget {
  const _TwoBuilders(this.stream);

  final Stream<int> stream;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<int>(
          stream: stream,
          builder: (context, snap) => Text('A:${snap.data ?? -1}'),
        ),
        StreamBuilder<int>(
          stream: stream,
          builder: (context, snap) => Text('B:${snap.data ?? -1}'),
        ),
      ],
    );
  }
}

void main() {
  late bool originalReady;

  setUp(() {
    originalReady = AuthService.firebaseReady;
    AuthService.firebaseReady = true;
  });

  tearDown(() {
    AuthService.firebaseReady = originalReady;
  });

  test('call() returns a stable view instance across rebuilds', () {
    final cache = StreamCache<int>(() => Stream<int>.value(1));
    expect(identical(cache(), cache()), isTrue);
  });

  test('multiple listeners share one source subscription', () async {
    var created = 0;
    final source = StreamController<int>();
    final cache = StreamCache<int>(() {
      created++;
      return source.stream;
    });
    final view = cache();
    final a = <int>[];
    final b = <int>[];
    final subA = view.listen(a.add);
    final subB = view.listen(b.add);
    await pumpEventQueue();
    source.add(1);
    source.add(2);
    await pumpEventQueue();
    expect(a, <int>[1, 2]);
    expect(b, <int>[1, 2]);
    expect(created, 1);
    await subA.cancel();
    await subB.cancel();
    await source.close();
  });

  test('late listener replays the latest event, then continues', () async {
    final source = StreamController<int>();
    final cache = StreamCache<int>(() => source.stream);
    final view = cache();
    final a = <int>[];
    final subA = view.listen(a.add);
    await pumpEventQueue();
    source.add(1);
    await pumpEventQueue();
    final b = <int>[];
    final subB = view.listen(b.add);
    await pumpEventQueue();
    expect(b, <int>[1], reason: 'late joiner must not wait for the next event');
    source.add(2);
    await pumpEventQueue();
    expect(a, <int>[1, 2]);
    expect(b, <int>[1, 2]);
    await subA.cancel();
    await subB.cancel();
    await source.close();
  });

  test('after all listeners cancel, a fresh source is created with replay',
      () async {
    var created = 0;
    final sources = <StreamController<int>>[];
    final cache = StreamCache<int>(() {
      created++;
      final source = StreamController<int>();
      sources.add(source);
      return source.stream;
    });
    final view = cache();
    final first = view.listen((_) {});
    await pumpEventQueue();
    sources.single.add(1);
    await pumpEventQueue();
    await first.cancel();
    expect(created, 1);
    final got = <int>[];
    final second = view.listen(got.add);
    await pumpEventQueue();
    expect(created, 2, reason: 'new listener must get a fresh source');
    expect(got, <int>[1], reason: 'replay must survive the source restart');
    sources.last.add(2);
    await pumpEventQueue();
    expect(got, <int>[1, 2]);
    await second.cancel();
    for (final source in sources) {
      await source.close();
    }
  });

  test('done reaches all listeners and late joiners', () async {
    final source = StreamController<int>();
    final cache = StreamCache<int>(() => source.stream);
    final view = cache();
    var firstDone = false;
    final first = view.listen((_) {}, onDone: () => firstDone = true);
    await pumpEventQueue();
    source.add(1);
    await pumpEventQueue();
    await source.close();
    await pumpEventQueue();
    expect(firstDone, isTrue);
    final got = <int>[];
    var lateDone = false;
    final late = view.listen(got.add, onDone: () => lateDone = true);
    await pumpEventQueue();
    expect(got, <int>[1]);
    expect(lateDone, isTrue);
    await first.cancel();
    await late.cancel();
  });

  test('while firebase is not ready every call builds a fresh guard stream',
      () {
    AuthService.firebaseReady = false;
    var created = 0;
    final cache = StreamCache<int>(() {
      created++;
      return Stream<int>.value(created);
    });
    final first = cache();
    final second = cache();
    expect(identical(first, second), isFalse);
    expect(created, 2);
  });

  testWidgets(
      'two StreamBuilders sharing one cached stream do not throw '
      '"Stream has already been listened to"', (tester) async {
    final source = StreamController<int>();
    final cache = StreamCache<int>(() => source.stream);
    final view = cache();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _TwoBuilders(view))),
    );
    expect(tester.takeException(), isNull);
    source.add(1);
    await tester.pump();
    await tester.pump();
    expect(find.text('A:1'), findsOneWidget);
    expect(find.text('B:1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Close before unmount: awaiting close() *after* the subscription is
    // cancelled hangs the FakeAsync test zone (reproduced with a plain
    // StreamController, no StreamCache involved).
    await source.close();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));
}
