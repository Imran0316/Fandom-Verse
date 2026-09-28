import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/content_docs.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'taxonomy_service.dart';

/// Firestore repository for the unified `contents` collection.
///
/// Fans may only read published docs, so every fan-facing stream filters on
/// `status == 'published'` (also required by firestore.rules). Ordering is
/// applied client-side to avoid composite index setup.
class ContentService {
  ContentService._();

  static final ContentService instance = ContentService._();

  static const String collection = 'contents';
  static const int _maxDocs = 300;

  bool get _ready => AuthService.firebaseReady;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(collection);

  /* --------------------------------- Reads -------------------------------- */

  /// Admin list: every status, newest edit first.
  Stream<List<ContentDoc>> watchAll() {
    if (!_ready) return Stream.value(const []);
    return _col
        .orderBy('updatedAt', descending: true)
        .limit(_maxDocs)
        .snapshots()
        .map((s) => s.docs.map(ContentDoc.fromDoc).toList());
  }

  /// Fan list: published only, newest discovery first. Public per the
  /// security rules, so signed-out users browse the live feed too.
  Stream<List<ContentDoc>> watchPublished({int limit = 200}) {
    if (!_ready) return Stream.value(const []);
    return _col
        .where('status', isEqualTo: ContentStatus.published.value)
        .limit(limit)
        .snapshots()
        .map((s) {
          final items = s.docs.map(ContentDoc.fromDoc).toList();
          items.sort(_byPublishedDesc);
          return items;
        });
  }

  Stream<ContentDoc?> watchById(String id) {
    if (!_ready || id.isEmpty) return Stream.value(null);
    return _col.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ContentDoc.fromDoc(snap);
    });
  }

  Future<ContentDoc?> fetchById(String id) async {
    if (!_ready || id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ContentDoc.fromDoc(snap);
  }

  /* --------------------------------- Writes ------------------------------- */

  Future<String> createContent({
    required ContentType type,
    required String title,
    required String summary,
    required String body,
    required String question,
    required String answer,
    required String explanation,
    required String fandomId,
    required String fandomName,
    required String categoryId,
    required String categoryName,
    required List<String> tags,
    required ContentStatus status,
    required bool isFeatured,
    required bool isTrending,
    String? coverImageUrl,
    String? videoUrl,
  }) async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final doc = ContentDoc(
      id: '',
      type: type,
      title: title,
      summary: summary,
      body: body,
      question: question,
      answer: answer,
      explanation: explanation,
      coverImageUrl: coverImageUrl,
      videoUrl: videoUrl,
      fandomId: fandomId,
      fandomName: fandomName,
      categoryId: categoryId,
      categoryName: categoryName,
      tags: tags,
      status: status,
      isFeatured: isFeatured,
      isTrending: isTrending,
      createdBy: uid,
      createdAt: DateTime.now(),
      publishedAt: status.isPublished ? DateTime.now() : null,
    );
    final ref = await _col.add(doc.toMap());
    if (status.isPublished) {
      await NotificationService.instance.notifyPublishedContent(
        contentId: ref.id,
        title: title,
        body: summary.isNotEmpty ? summary : title,
        fandomId: fandomId,
        imageUrl: coverImageUrl,
        fandomName: fandomName,
      );
    }
    return ref.id;
  }

  Future<void> updateContent(
    String id, {
    required ContentType type,
    required String title,
    required String summary,
    required String body,
    required String question,
    required String answer,
    required String explanation,
    required String fandomId,
    required String fandomName,
    required String categoryId,
    required String categoryName,
    required List<String> tags,
    required ContentStatus status,
    required bool isFeatured,
    required bool isTrending,
    String? coverImageUrl,
    String? videoUrl,
    DateTime? existingPublishedAt,
  }) async {
    final data = <String, dynamic>{
      'type': type.value,
      'title': title.trim(),
      'summary': summary.trim(),
      'body': body.trim(),
      'question': question.trim(),
      'answer': answer.trim(),
      'explanation': explanation.trim(),
      'coverImageUrl': (coverImageUrl ?? '').trim().isEmpty
          ? null
          : coverImageUrl!.trim(),
      // Clearing the field in the editor removes the video from the doc.
      'videoUrl': (videoUrl ?? '').trim().isEmpty ? null : videoUrl!.trim(),
      'fandomId': fandomId,
      'fandomName': fandomName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'tags': tags,
      'status': status.value,
      'isFeatured': isFeatured,
      'isTrending': isTrending,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // Only stamp publishedAt the first time content becomes published.
    if (status.isPublished && existingPublishedAt == null) {
      data['publishedAt'] = FieldValue.serverTimestamp();
    }
    await _col.doc(id).update(data);
    if (status.isPublished && existingPublishedAt == null) {
      await NotificationService.instance.notifyPublishedContent(
        contentId: id,
        title: title,
        body: summary.isNotEmpty ? summary : title,
        fandomId: fandomId,
        imageUrl: coverImageUrl,
        fandomName: fandomName,
      );
    }
  }

  Future<void> setStatus(String id, ContentStatus status) async {
    final current = await fetchById(id);
    final data = <String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status.isPublished) {
      data['publishedAt'] = FieldValue.serverTimestamp();
    }
    await _col.doc(id).update(data);
    if (status.isPublished && (current == null || !current.isPublished)) {
      final payload =
          current ??
          const ContentDoc(
            id: '',
            type: ContentType.article,
            title: '',
            summary: '',
            body: '',
            question: '',
            answer: '',
            explanation: '',
            fandomId: '',
            fandomName: '',
            categoryId: '',
            categoryName: '',
          );
      await NotificationService.instance.notifyPublishedContent(
        contentId: id,
        title: payload.title.isNotEmpty ? payload.title : 'New publication',
        body: payload.summary.isNotEmpty
            ? payload.summary
            : 'A new update is live.',
        fandomId: payload.fandomId,
        imageUrl: payload.coverImageUrl,
        fandomName: payload.fandomName,
      );
    }
  }

  Future<void> setFeatured(String id, bool value) => _col.doc(id).update({
    'isFeatured': value,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> setTrending(String id, bool value) => _col.doc(id).update({
    'isTrending': value,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> deleteContent(String id) => _col.doc(id).delete();

  /* -------------------------------- Seeding ------------------------------- */

  /// Creates a handful of editorial sample discoveries (admin-only) plus the
  /// default fandoms/categories. Mirrors the SRS test scenario.
  Future<void> seedSampleContent() async {
    if (!_ready) return;
    await TaxonomyService.instance.seedDefaultsIfEmpty();

    final fandoms = await TaxonomyService.instance.watchFandoms().first;
    final categories = await TaxonomyService.instance.watchCategories().first;

    String fandomId(String name) => fandoms
        .firstWhere(
          (f) => f.name.toLowerCase() == name.toLowerCase(),
          orElse: () => const FandomDoc(id: '', name: ''),
        )
        .id;
    String fandomName(String name) => fandoms
        .firstWhere(
          (f) => f.name.toLowerCase() == name.toLowerCase(),
          orElse: () => const FandomDoc(id: '', name: ''),
        )
        .name;
    String catId(String name) => categories
        .firstWhere(
          (c) => c.name.toLowerCase() == name.toLowerCase(),
          orElse: () => const ContentCategoryDoc(id: '', name: ''),
        )
        .id;
    String catName(String name) => categories
        .firstWhere(
          (c) => c.name.toLowerCase() == name.toLowerCase(),
          orElse: () => const ContentCategoryDoc(id: '', name: ''),
        )
        .name;

    final uid = AuthService.instance.currentUser?.uid ?? '';
    final now = DateTime.now();

    final samples = <Map<String, dynamic>>[
      {
        'type': ContentType.trivia.value,
        'title': '10 Hidden Facts About One Piece',
        'summary': 'Ten details even long-time fans miss about the Grand Line.',
        'question': 'What is the name of Luffy\'s first ship?',
        'answer': 'The Going Merry.',
        'explanation':
            'Given to the Straw Hats by Kaya, the Going Merry carried them '
            'through the East Blue and into the Grand Line before its '
            'farewell at Water 7.',
        'fandomId': fandomId('Anime'),
        'fandomName': fandomName('Anime'),
        'categoryId': catId('Trivia'),
        'categoryName': catName('Trivia'),
        'tags': ['one piece', 'anime', 'straw hats'],
        'status': ContentStatus.published.value,
        'isFeatured': true,
        'isTrending': true,
        'publishedAt': Timestamp.fromDate(
          now.subtract(const Duration(days: 2)),
        ),
      },
      {
        'type': ContentType.lore.value,
        'title': 'The Complete Guide to the Grand Line',
        'summary': 'Navigating the seas, islands and legends of One Piece.',
        'body':
            'The Grand Line is a stretch of ocean that runs around the world, '
            'bordered by the Calm Belt on both sides. Its unpredictable '
            'weather, magnetic currents and legendary islands make it the '
            'most dangerous route a pirate can sail — and the only one that '
            'leads to the One Piece.',
        'fandomId': fandomId('Anime'),
        'fandomName': fandomName('Anime'),
        'categoryId': catId('World Building'),
        'categoryName': catName('World Building'),
        'tags': ['one piece', 'grand line', 'world'],
        'status': ContentStatus.published.value,
        'isFeatured': false,
        'isTrending': true,
        'publishedAt': Timestamp.fromDate(
          now.subtract(const Duration(days: 5)),
        ),
      },
      {
        'type': ContentType.news.value,
        'title': 'Latest Anime Universe News',
        'summary': 'A quick round-up of what the anime world is buzzing about.',
        'body':
            'Studios have announced a new slate of adaptations for the coming '
            'season, alongside re-releases of beloved classics. Fans can '
            'expect fresh simulcasts and a returning fan-favourite franchise.',
        'fandomId': fandomId('Anime'),
        'fandomName': fandomName('Anime'),
        'categoryId': catId('News'),
        'categoryName': catName('News'),
        'tags': ['anime', 'news', 'season'],
        'status': ContentStatus.published.value,
        'isFeatured': true,
        'isTrending': false,
        'publishedAt': Timestamp.fromDate(
          now.subtract(const Duration(hours: 20)),
        ),
      },
      {
        'type': ContentType.article.value,
        'title': 'Understanding the World of Fandom',
        'summary':
            'Why fans build universes of knowledge around what they love.',
        'body':
            'Fandom is more than a hobby — it is a shared language. Communities '
            'document lore, debate theories and celebrate creators together. '
            'This piece explores how that culture shapes the way we read and '
            'share stories.',
        'fandomId': fandomId('Gaming'),
        'fandomName': fandomName('Gaming'),
        'categoryId': catId('Guides'),
        'categoryName': catName('Guides'),
        'tags': ['culture', 'community', 'fandom'],
        'status': ContentStatus.published.value,
        'isFeatured': false,
        'isTrending': true,
        'publishedAt': Timestamp.fromDate(
          now.subtract(const Duration(days: 8)),
        ),
      },
      {
        'type': ContentType.article.value,
        'title': 'Origins of the Shonen Genre',
        'summary': 'A draft deep dive into the history of shonen storytelling.',
        'body':
            'From post-war magazine serials to global streaming hits, shonen has '
            'grown into one of the most influential genres in entertainment.',
        'fandomId': fandomId('Manga'),
        'fandomName': fandomName('Manga'),
        'categoryId': catId('World Building'),
        'categoryName': catName('World Building'),
        'tags': ['manga', 'history'],
        'status': ContentStatus.draft.value,
        'isFeatured': false,
        'isTrending': false,
        'publishedAt': null,
      },
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (final sample in samples) {
      batch.set(_col.doc(), {
        ...sample,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static int _byPublishedDesc(ContentDoc a, ContentDoc b) {
    final left = a.displayDate;
    final right = b.displayDate;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }
}
