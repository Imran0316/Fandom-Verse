import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shared icon + color vocabulary for categories / events / merch cards.
abstract final class CatalogIcons {
  static const map = <String, IconData>{
    'anime': Icons.theaters_rounded,
    'gaming': Icons.sports_esports_rounded,
    'movies': Icons.movie_rounded,
    'comics': Icons.auto_stories_rounded,
    'kpop': Icons.headphones_rounded,
    'music': Icons.music_note_rounded,
    'sports': Icons.sports_soccer_rounded,
    'tech': Icons.memory_rounded,
    'explore': Icons.explore_rounded,
    'mic': Icons.mic_rounded,
    'event': Icons.event_rounded,
    'grid': Icons.grid_view_rounded,
    'star': Icons.star_rounded,
    'fire': Icons.local_fire_department_rounded,
    'brush': Icons.brush_rounded,
    'book': Icons.menu_book_rounded,
  };

  static const defaultIcon = Icons.category_rounded;

  static IconData fromName(String? name) => map[name] ?? defaultIcon;

  static String nameOf(IconData icon) {
    for (final e in map.entries) {
      if (e.value == icon) return e.key;
    }
    return 'grid';
  }

  static const colors = <String, Color>{
    'rose': Color(0xFFE11D48),
    'green': Color(0xFF10B981),
    'blue': Color(0xFF3B82F6),
    'amber': Color(0xFFF59E0B),
    'purple': Color(0xFFA855F7),
    'gray': Color(0xFF9CA3AF),
    'red': Color(0xFFE50914),
    'cyan': Color(0xFF06B6D4),
    'pink': Color(0xFFEC4899),
    'indigo': Color(0xFF6366F1),
    'teal': Color(0xFF14B8A6),
    'orange': Color(0xFFF97316),
  };

  static Color colorFromName(String? name) =>
      colors[name] ?? const Color(0xFFE11D48);

  static String colorNameOf(Color color) {
    for (final e in colors.entries) {
      if (e.value.toARGB32() == color.toARGB32()) return e.key;
    }
    return 'rose';
  }
}

class FandomCategoryDoc {
  const FandomCategoryDoc({
    required this.id,
    required this.name,
    this.iconName = 'grid',
    this.colorName = 'rose',
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String iconName;
  final String colorName;
  final int sortOrder;

  IconData get icon => CatalogIcons.fromName(iconName);
  Color get color => CatalogIcons.colorFromName(colorName);

  factory FandomCategoryDoc.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return FandomCategoryDoc(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      iconName: (data['iconName'] as String?) ?? 'grid',
      colorName: (data['colorName'] as String?) ?? 'rose',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'iconName': iconName,
    'colorName': colorName,
    'sortOrder': sortOrder,
  };
}

class FandomEventDoc {
  const FandomEventDoc({
    required this.id,
    required this.title,
    required this.city,
    required this.dateLabel,
    this.iconName = 'event',
    this.colorName = 'red',
    this.coverImageUrl,
    this.startAt,
  });

  final String id;
  final String title;
  final String city;
  final String dateLabel;
  final String iconName;
  final String colorName;
  final String? coverImageUrl;
  final DateTime? startAt;

  IconData get icon => CatalogIcons.fromName(iconName);
  Color get color => CatalogIcons.colorFromName(colorName);

  factory FandomEventDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final start = data['startAt'];
    return FandomEventDoc(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      dateLabel: (data['dateLabel'] as String?) ?? '',
      iconName: (data['iconName'] as String?) ?? 'event',
      colorName: (data['colorName'] as String?) ?? 'red',
      coverImageUrl: data['coverImageUrl'] as String?,
      startAt: start is Timestamp ? start.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'city': city,
    'dateLabel': dateLabel,
    'iconName': iconName,
    'colorName': colorName,
    'coverImageUrl': coverImageUrl,
    'startAt': startAt != null ? Timestamp.fromDate(startAt!) : null,
  };
}

class MerchProductDoc {
  const MerchProductDoc({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.sellerUid,
    this.sellerName = '',
    this.emoji = '✨',
    this.colorName = 'red',
    this.description = '',
    this.imageUrl,
    this.active = true,
    this.stock,
    this.soldCount = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String priceLabel;
  final String sellerUid;
  final String sellerName;
  final String emoji;
  final String colorName;
  final String description;
  final String? imageUrl;
  final bool active;

  /// Units the seller listed. `null` means stock is not tracked.
  final int? stock;

  /// Units sold (bumped by checkout).
  final int soldCount;

  /// Average rating, 0 when there are no reviews.
  final double rating;

  final int reviewCount;

  final DateTime? createdAt;

  Color get color => CatalogIcons.colorFromName(colorName);

  factory MerchProductDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MerchProductDoc.fromMap(doc.id, doc.data() ?? const {});

  factory MerchProductDoc.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return MerchProductDoc(
      id: id,
      name: (data['name'] as String?) ?? '',
      priceLabel: (data['priceLabel'] as String?) ?? r'$0',
      sellerUid: (data['sellerUid'] as String?) ?? '',
      sellerName: (data['sellerName'] as String?) ?? '',
      emoji: (data['emoji'] as String?) ?? '✨',
      colorName: (data['colorName'] as String?) ?? 'red',
      description: (data['description'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      active: (data['active'] as bool?) ?? true,
      stock: (data['stock'] as num?)?.toInt(),
      soldCount: (data['soldCount'] as num?)?.toInt() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'priceLabel': priceLabel,
    'sellerUid': sellerUid,
    'sellerName': sellerName,
    'emoji': emoji,
    'colorName': colorName,
    'description': description,
    'imageUrl': imageUrl,
    'active': active,
    'stock': stock,
    'soldCount': soldCount,
    'rating': rating,
    'reviewCount': reviewCount,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };
}

/// A buyer's review of a merch product — lives in
/// `merch/{productId}/reviews/{authorUid}` (one review per user).
class ProductReviewDoc {
  const ProductReviewDoc({
    required this.id,
    required this.productId,
    required this.authorUid,
    required this.authorName,
    required this.rating,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String productId;
  final String authorUid;
  final String authorName;

  /// 1–5 stars.
  final int rating;

  final String text;
  final DateTime? createdAt;

  factory ProductReviewDoc.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => ProductReviewDoc.fromMap(doc.id, doc.data() ?? const {});

  factory ProductReviewDoc.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return ProductReviewDoc(
      id: id,
      productId: (data['productId'] as String?) ?? '',
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? 'Fan',
      rating: (data['rating'] as num?)?.toInt() ?? 5,
      text: (data['text'] as String?) ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'authorUid': authorUid,
    'authorName': authorName,
    'rating': rating,
    'text': text,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };
}
