import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'catalog_docs.dart';

/// V1 content types. Designed so new types can be added without a schema change.
enum ContentType {
  article('Article', Icons.article_rounded),
  news('News', Icons.newspaper_rounded),
  trivia('Trivia', Icons.quiz_rounded),
  lore('Lore', Icons.auto_stories_rounded);

  const ContentType(this.label, this.icon);

  final String label;
  final IconData icon;

  static ContentType fromString(String? raw) {
    switch (raw) {
      case 'news':
        return ContentType.news;
      case 'trivia':
        return ContentType.trivia;
      case 'lore':
        return ContentType.lore;
      default:
        return ContentType.article;
    }
  }

  String get value => name;

  /// Trivia swaps the free-form body for a question / answer / explanation.
  bool get usesQuestion => this == ContentType.trivia;
}

enum ContentStatus {
  draft('Draft'),
  published('Published');

  const ContentStatus(this.label);

  final String label;

  static ContentStatus fromString(String? raw) =>
      raw == 'published' ? ContentStatus.published : ContentStatus.draft;

  String get value => name;

  bool get isPublished => this == ContentStatus.published;
}

/// Unified V1 content document stored in the `contents` collection.
class ContentDoc {
  const ContentDoc({
    required this.id,
    required this.type,
    required this.title,
    this.summary = '',
    this.body = '',
    this.question = '',
    this.answer = '',
    this.explanation = '',
    this.coverImageUrl,
    this.fandomId = '',
    this.fandomName = '',
    this.categoryId = '',
    this.categoryName = '',
    this.tags = const [],
    this.status = ContentStatus.draft,
    this.isFeatured = false,
    this.isTrending = false,
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  final String id;
  final ContentType type;
  final String title;
  final String summary;

  /// Long-form copy for Article / News / Lore.
  final String body;

  /// Trivia-only fields.
  final String question;
  final String answer;
  final String explanation;

  final String? coverImageUrl;

  final String fandomId;
  final String fandomName;
  final String categoryId;
  final String categoryName;

  final List<String> tags;
  final ContentStatus status;
  final bool isFeatured;
  final bool isTrending;

  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  bool get isPublished => status.isPublished;

  DateTime? get displayDate => publishedAt ?? createdAt ?? updatedAt;

  /// "10 Hidden Facts About One Piece" → the teaser text shown on cards.
  String get teaser {
    if (summary.trim().isNotEmpty) return summary.trim();
    if (type.usesQuestion && question.trim().isNotEmpty) return question.trim();
    final raw = body.trim();
    if (raw.isEmpty) return '';
    return raw.length <= 140 ? raw : '${raw.substring(0, 140).trimRight()}…';
  }

  /// Approximate reading time from the readable copy (≥1 minute).
  int get readingMinutes {
    final text = type.usesQuestion
        ? '$question $answer $explanation'
        : '$summary $body';
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return (words / 200).ceil().clamp(1, 60);
  }

  static String? _cleanUrl(String? raw) {
    final value = raw?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  factory ContentDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    final published = data['publishedAt'];
    return ContentDoc(
      id: doc.id,
      type: ContentType.fromString(data['type'] as String?),
      title: (data['title'] as String?) ?? '',
      summary: (data['summary'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      question: (data['question'] as String?) ?? '',
      answer: (data['answer'] as String?) ?? '',
      explanation: (data['explanation'] as String?) ?? '',
      coverImageUrl: _cleanUrl(data['coverImageUrl'] as String?),
      fandomId: (data['fandomId'] as String?) ?? '',
      fandomName: (data['fandomName'] as String?) ?? '',
      categoryId: (data['categoryId'] as String?) ?? '',
      categoryName: (data['categoryName'] as String?) ?? '',
      tags: List<String>.from((data['tags'] as List?) ?? const []),
      status: ContentStatus.fromString(data['status'] as String?),
      isFeatured: (data['isFeatured'] as bool?) ?? false,
      isTrending: (data['isTrending'] as bool?) ?? false,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
      publishedAt: published is Timestamp ? published.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
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
        'fandomId': fandomId,
        'fandomName': fandomName,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'tags': tags,
        'status': status.value,
        'isFeatured': isFeatured,
        'isTrending': isTrending,
        'createdBy': createdBy,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'publishedAt': publishedAt != null
            ? Timestamp.fromDate(publishedAt!)
            : null,
      };
}

/// A fandom (e.g. Anime, Gaming) managed by admins. Backs "Trending Fandoms"
/// and fandom-based discovery. Readable by any signed-in user.
class FandomDoc {
  const FandomDoc({
    required this.id,
    required this.name,
    this.iconName = 'explore',
    this.colorName = 'red',
    this.coverImageUrl,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String iconName;
  final String colorName;
  final String? coverImageUrl;
  final int sortOrder;

  IconData get icon => CatalogIcons.fromName(iconName);
  Color get color => CatalogIcons.colorFromName(colorName);

  factory FandomDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return FandomDoc(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      iconName: (data['iconName'] as String?) ?? 'explore',
      colorName: (data['colorName'] as String?) ?? 'red',
      coverImageUrl: data['coverImageUrl'] as String?,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'iconName': iconName,
        'colorName': colorName,
        'coverImageUrl': coverImageUrl,
        'sortOrder': sortOrder,
      };
}

/// An editorial content category (e.g. Guides, Characters, World Building).
class ContentCategoryDoc {
  const ContentCategoryDoc({
    required this.id,
    required this.name,
    this.iconName = 'grid',
    this.colorName = 'red',
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String iconName;
  final String colorName;
  final int sortOrder;

  IconData get icon => CatalogIcons.fromName(iconName);
  Color get color => CatalogIcons.colorFromName(colorName);

  factory ContentCategoryDoc.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return ContentCategoryDoc(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      iconName: (data['iconName'] as String?) ?? 'grid',
      colorName: (data['colorName'] as String?) ?? 'red',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'iconName': iconName,
        'colorName': colorName,
        'sortOrder': sortOrder,
      };
}

/// Fan → Bookmark → Content relationship. One doc per (user, content) pair.
class BookmarkDoc {
  const BookmarkDoc({
    required this.id,
    required this.userId,
    required this.contentId,
    this.savedAt,
  });

  final String id;
  final String userId;
  final String contentId;
  final DateTime? savedAt;

  factory BookmarkDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final saved = data['savedAt'];
    return BookmarkDoc(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      contentId: (data['contentId'] as String?) ?? '',
      savedAt: saved is Timestamp ? saved.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'contentId': contentId,
        'savedAt':
            savedAt != null ? Timestamp.fromDate(savedAt!) : FieldValue.serverTimestamp(),
      };
}
