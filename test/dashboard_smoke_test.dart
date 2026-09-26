import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/content_docs.dart';
import 'package:fandom_verse/models/user_profile.dart';
import 'package:fandom_verse/screens/dashboard/dashboard_screen.dart';

/// Drains all pending exceptions from [tester].
///
/// Known test-env-only noise: ReelsTab eagerly built by IndexedStack mounts
/// a YouTube webview, and webview_flutter has no platform registered under
/// `flutter test` (the app guards this path with kIsWeb on web). Anything
/// else — including "Stream has already been listened to" — is a failure.
List<Object> _drainExceptions(WidgetTester tester) {
  final all = <Object>[];
  for (var i = 0; i < 50; i++) {
    final error = tester.takeException();
    if (error == null) break;
    all.add(error);
  }
  return all;
}

List<Object> _unexpected(List<Object> errors) {
  return errors
      .where((Object e) => !e.toString().contains('webview_flutter'))
      .toList();
}

void main() {
  test(
    'selected fandoms drive dynamic recommendations before unrelated content',
    () {
      final now = DateTime.now();
      final published = <ContentDoc>[
        ContentDoc(
          id: '1',
          type: ContentType.article,
          title: 'Anime deep dive',
          summary: '',
          body: '',
          question: '',
          answer: '',
          explanation: '',
          fandomId: 'anime-id',
          fandomName: 'Anime',
          status: ContentStatus.published,
          publishedAt: now,
        ),
        ContentDoc(
          id: '2',
          type: ContentType.news,
          title: 'Gaming update',
          summary: '',
          body: '',
          question: '',
          answer: '',
          explanation: '',
          fandomId: 'gaming-id',
          fandomName: 'Gaming',
          status: ContentStatus.published,
          publishedAt: now.add(const Duration(hours: -1)),
        ),
        ContentDoc(
          id: '3',
          type: ContentType.article,
          title: 'Movies weekly recap',
          summary: '',
          body: '',
          question: '',
          answer: '',
          explanation: '',
          fandomId: 'movies-id',
          fandomName: 'Movies & TV',
          status: ContentStatus.published,
          publishedAt: now.add(const Duration(hours: -2)),
        ),
      ];

      final recommended = buildRecommendedContentForUser(
        const UserProfile(
          uid: 'u1',
          name: 'Fan',
          email: 'fan@example.com',
          selectedFandoms: ['Anime', 'Gaming'],
        ),
        published,
      );

      expect(recommended.map((item) => item.title).take(2).toList(), [
        'Anime deep dive',
        'Gaming update',
      ]);
    },
  );

  test(
    'fall back to published content when no fandom interests are selected',
    () {
      final published = <ContentDoc>[
        ContentDoc(
          id: '1',
          type: ContentType.article,
          title: 'Latest feature',
          summary: '',
          body: '',
          question: '',
          answer: '',
          explanation: '',
          fandomId: 'anime-id',
          fandomName: 'Anime',
          status: ContentStatus.published,
          isFeatured: true,
          publishedAt: DateTime.now(),
        ),
        ContentDoc(
          id: '2',
          type: ContentType.news,
          title: 'Another story',
          summary: '',
          body: '',
          question: '',
          answer: '',
          explanation: '',
          fandomId: 'gaming-id',
          fandomName: 'Gaming',
          status: ContentStatus.published,
          publishedAt: DateTime.now().add(const Duration(hours: -1)),
        ),
      ];

      final recommended = buildRecommendedContentForUser(null, published);

      expect(recommended.first.title, 'Latest feature');
      expect(recommended.length, 2);
    },
  );

  testWidgets('Dashboard renders with fallback streams and no exceptions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
    expect(_unexpected(_drainExceptions(tester)), isEmpty);

    // Rebuild the whole tree: every inline StreamBuilder gets a brand-new
    // stream object and must resubscribe without "already been listened to".
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(_unexpected(_drainExceptions(tester)), isEmpty);

    // Scroll the home list so lazy children and their StreamBuilders mount.
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_unexpected(_drainExceptions(tester)), isEmpty);
  });
}
