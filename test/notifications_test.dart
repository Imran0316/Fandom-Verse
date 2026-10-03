import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/core/streams.dart';
import 'package:fandom_verse/models/notification_docs.dart';
import 'package:fandom_verse/screens/dashboard/dashboard_screen.dart';
import 'package:fandom_verse/screens/profile/notifications_screen.dart';

void main() {
  test('NotificationKind parses known types and falls back to unknown', () {
    expect(NotificationKind.fromString('post_liked'), NotificationKind.postLiked);
    expect(
      NotificationKind.fromString('post_commented'),
      NotificationKind.postCommented,
    );
    expect(
      NotificationKind.fromString('comment_replied'),
      NotificationKind.commentReplied,
    );
    expect(
      NotificationKind.fromString('follow_requested'),
      NotificationKind.followRequested,
    );
    expect(NotificationKind.fromString('something_else'), NotificationKind.unknown);
    expect(NotificationKind.fromString(null), NotificationKind.unknown);
  });

  testWidgets('Notifications screen shows the live feed empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text("You're all caught up"), findsOneWidget);
    // Nothing unread — the bulk action stays hidden.
    expect(find.text('Mark all read'), findsNothing);
    expect(find.text('Clear'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping a notification row only marks it read — no navigation', (
    tester,
  ) async {
    final row = NotificationDoc(
      id: 'n1',
      recipientUid: 'user-1',
      actorUid: 'system',
      type: 'fandomContent',
      contentId: 'c1',
      title: 'New update',
      body: 'Fresh fandom content is live.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(items: onceStream([row])),
        routes: {
          '/content': (_) => const Text('content page'),
          '/dashboard': (_) => const Text('dashboard page'),
          '/explore': (_) => const Text('explore page'),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('New update'), findsOneWidget);

    await tester.tap(find.text('New update'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('New update'), findsOneWidget);
    expect(find.text('content page'), findsNothing);
    expect(find.text('dashboard page'), findsNothing);
    expect(find.text('explore page'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shows the communities section with its promo when the '
      'list is empty', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Start a community'), findsOneWidget);

    // Drain test-env-only noise: ReelsTab mounts a YouTube webview with no
    // platform registered under `flutter test` (same as dashboard_smoke).
    final unexpected = <Object>[];
    for (var i = 0; i < 50; i++) {
      final error = tester.takeException();
      if (error == null) break;
      if (!error.toString().contains('webview_flutter')) {
        unexpected.add(error);
      }
    }
    expect(unexpected, isEmpty);
  });
}
