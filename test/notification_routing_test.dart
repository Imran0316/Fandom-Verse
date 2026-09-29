import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/core/routes/app_routes.dart';
import 'package:fandom_verse/models/notification_docs.dart';
import 'package:fandom_verse/services/notification_service.dart';

NotificationDoc _doc(
  String type, {
  String id = 'n1',
  String? postId,
  String? contentId,
  String? communityId,
  String?   targetId,
  NotificationTargetType? targetType,
}) => NotificationDoc(
  id: id,
  recipientUid: 'user-1',
  actorUid: 'user-2',
  type: type,
  postId: postId,
  contentId: contentId,
  communityId: communityId,
  targetId: targetId,
  targetType: targetType,
);

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
      routes: {
        AppRoutes.feed: (_) =>
            const Text('feed', textDirection: TextDirection.ltr),
        AppRoutes.contentDetail: (_) =>
            const Text('content', textDirection: TextDirection.ltr),
        AppRoutes.communityDetail: (_) =>
            const Text('community', textDirection: TextDirection.ltr),
        AppRoutes.followRequests: (_) =>
            const Text('follow', textDirection: TextDirection.ltr),
        AppRoutes.dashboard: (_) =>
            const Text('dashboard', textDirection: TextDirection.ltr),
      },
    ),
  );
  await tester.pump();
  return ctx;
}

void main() {
  testWidgets('post activity opens the feed, never the content detail', (
    WidgetTester tester,
  ) async {
    final ctx = await _pumpHost(tester);

    NotificationService.openTarget(
      ctx,
      _doc('post_liked', postId: 'post-1'),
      markRead: false,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('feed'), findsOneWidget);
    expect(find.text('content'), findsNothing);
  });

  testWidgets('fandom content opens the content detail', (
    WidgetTester tester,
  ) async {
    final ctx = await _pumpHost(tester);

    NotificationService.openTarget(
      ctx,
      _doc('fandomContent', contentId: 'c1'),
      markRead: false,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('a payload with only a postId never opens the content detail', (
    WidgetTester tester,
  ) async {
    final ctx = await _pumpHost(tester);

    NotificationService.openTarget(
      ctx,
      _doc(
        'system',
        postId: 'post-1',
        targetType: NotificationTargetType.content,
      ),
      markRead: false,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('dashboard'), findsOneWidget);
    expect(find.text('content'), findsNothing);
  });

  testWidgets('follow requests open the follow request screen', (
    WidgetTester tester,
  ) async {
    final ctx = await _pumpHost(tester);

    NotificationService.openTarget(
      ctx,
      _doc('follow_requested', id: 'follow_user-2'),
      markRead: false,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('follow'), findsOneWidget);
  });

  testWidgets('community announcements open the community detail', (
    WidgetTester tester,
  ) async {
    final ctx = await _pumpHost(tester);

    NotificationService.openTarget(
      ctx,
      _doc('communityAnnouncement', communityId: 'com-1'),
      markRead: false,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('community'), findsOneWidget);
  });
}
