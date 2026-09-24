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

  static Color colorFromName(String? name) => colors[name] ?? const Color(0xFFE11D48);

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

  factory FandomCategoryDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
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
    this.startAt,
  });

  final String id;
  final String title;
  final String city;
  final String dateLabel;
  final String iconName;
  final String colorName;
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
      startAt: start is Timestamp ? start.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'city': city,
        'dateLabel': dateLabel,
        'iconName': iconName,
        'colorName': colorName,
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
  final DateTime? createdAt;

  Color get color => CatalogIcons.colorFromName(colorName);

  factory MerchProductDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    return MerchProductDoc(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      priceLabel: (data['priceLabel'] as String?) ?? r'$0',
      sellerUid: (data['sellerUid'] as String?) ?? '',
      sellerName: (data['sellerName'] as String?) ?? '',
      emoji: (data['emoji'] as String?) ?? '✨',
      colorName: (data['colorName'] as String?) ?? 'red',
      description: (data['description'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      active: (data['active'] as bool?) ?? true,
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
        'createdAt':
            createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };
}
