import 'package:flutter/material.dart';

class TrendingFandom {
  const TrendingFandom({
    required this.title,
    required this.category,
    required this.colors,
    required this.emoji,
  });

  final String title;
  final String category;
  final List<Color> colors;
  final String emoji;
}

class FandomCategory {
  const FandomCategory({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class MediaTitle {
  const MediaTitle({
    required this.title,
    required this.tag,
    required this.colors,
    required this.emoji,
  });

  final String title;
  final String tag;
  final List<Color> colors;
  final String emoji;
}

class FandomEvent {
  const FandomEvent({
    required this.title,
    required this.city,
    required this.date,
    required this.colors,
    required this.icon,
  });

  final String title;
  final String city;
  final String date;
  final List<Color> colors;
  final IconData icon;
}

class MerchItem {
  const MerchItem({
    required this.name,
    required this.price,
    required this.colors,
    required this.emoji,
  });

  final String name;
  final String price;
  final List<Color> colors;
  final String emoji;
}

abstract final class MockCatalog {
  static const trending = <TrendingFandom>[
    TrendingFandom(
      title: 'Jujutsu Kaisen',
      category: 'Anime & Manga',
      colors: [Color(0xFF7F1D1D), Color(0xFF1A0505)],
      emoji: '⚔️',
    ),
    TrendingFandom(
      title: 'Galactic Saga',
      category: 'Movies & TV',
      colors: [Color(0xFF1E3A5F), Color(0xFF050B14)],
      emoji: '🌌',
    ),
    TrendingFandom(
      title: 'Esports Arena',
      category: 'Gaming',
      colors: [Color(0xFF064E3B), Color(0xFF031510)],
      emoji: '🎮',
    ),
    TrendingFandom(
      title: 'K-Pop World Tour',
      category: 'Music & Idols',
      colors: [Color(0xFF4C1D95), Color(0xFF12081F)],
      emoji: '🎤',
    ),
    TrendingFandom(
      title: 'Heroes Unbound',
      category: 'Comics',
      colors: [Color(0xFF7C2D12), Color(0xFF170804)],
      emoji: '💥',
    ),
  ];

  static const categories = <FandomCategory>[
    FandomCategory(
      label: 'Anime & Manga',
      icon: Icons.theaters_rounded,
      color: Color(0xFFE11D48),
    ),
    FandomCategory(
      label: 'Gaming',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF10B981),
    ),
    FandomCategory(
      label: 'Movies & TV',
      icon: Icons.movie_rounded,
      color: Color(0xFF3B82F6),
    ),
    FandomCategory(
      label: 'Comics',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFFF59E0B),
    ),
    FandomCategory(
      label: 'K-Pop',
      icon: Icons.headphones_rounded,
      color: Color(0xFFA855F7),
    ),
    FandomCategory(
      label: 'See all',
      icon: Icons.grid_view_rounded,
      color: Color(0xFF9CA3AF),
    ),
  ];

  static const recommended = <MediaTitle>[
    MediaTitle(
      title: 'Chainsaw Man',
      tag: 'Anime',
      colors: [Color(0xFF9F1239), Color(0xFF1F050A)],
      emoji: '😈',
    ),
    MediaTitle(
      title: 'WALL-E Legacy',
      tag: 'Movies',
      colors: [Color(0xFF0E7490), Color(0xFF021018)],
      emoji: '🤖',
    ),
    MediaTitle(
      title: 'Spirited Away',
      tag: 'Anime',
      colors: [Color(0xFFB45309), Color(0xFF1A0E03)],
      emoji: '🏮',
    ),
    MediaTitle(
      title: 'The Mandalorian',
      tag: 'Series',
      colors: [Color(0xFF78350F), Color(0xFF140A02)],
      emoji: '🚀',
    ),
    MediaTitle(
      title: 'One Piece',
      tag: 'Anime',
      colors: [Color(0xFF1D4ED8), Color(0xFF030B1F)],
      emoji: '🏴‍☠️',
    ),
    MediaTitle(
      title: 'Valorant',
      tag: 'Gaming',
      colors: [Color(0xFFBE123C), Color(0xFF18040A)],
      emoji: '🎯',
    ),
  ];

  static const events = <FandomEvent>[
    FandomEvent(
      title: 'Anime Expo',
      city: 'Los Angeles',
      date: 'Jul 12',
      colors: [Color(0xFFBE123C), Color(0xFF1A0508)],
      icon: Icons.explore_rounded,
    ),
    FandomEvent(
      title: 'Comic-Con',
      city: 'San Diego',
      date: 'Jul 25',
      colors: [Color(0xFF7C3AED), Color(0xFF0F061C)],
      icon: Icons.auto_stories_rounded,
    ),
    FandomEvent(
      title: 'K-Pop Fest',
      city: 'Seoul',
      date: 'Aug 03',
      colors: [Color(0xFFDB2777), Color(0xFF1A0610)],
      icon: Icons.mic_rounded,
    ),
  ];

  static const merch = <MerchItem>[
    MerchItem(
      name: 'Akatsuki Cloak',
      price: r'$59',
      colors: [Color(0xFF9F1239), Color(0xFF140406)],
      emoji: '🧥',
    ),
    MerchItem(
      name: 'Pixel Controller',
      price: r'$49',
      colors: [Color(0xFF047857), Color(0xFF03150F)],
      emoji: '🎮',
    ),
    MerchItem(
      name: 'Light Saber Pin',
      price: r'$19',
      colors: [Color(0xFF1D4ED8), Color(0xFF040A1A)],
      emoji: '⚔️',
    ),
    MerchItem(
      name: 'Idol Lightstick',
      price: r'$35',
      colors: [Color(0xFF9333EA), Color(0xFF0F061A)],
      emoji: '✨',
    ),
  ];
}
