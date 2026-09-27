import '../../models/content_docs.dart';
import 'anilist_provider.dart';
import 'deep_dive_models.dart';
import 'itunes_provider.dart';
import 'rawg_provider.dart';
import 'tvmaze_provider.dart';

/// Picks which Deep Dive providers apply to a story and in what order.
///
/// Detection reads the story's fandom / category / title / tags for
/// domain keywords (e.g. fandom "Gaming" → games first); the detected
/// domain leads the cascade and the remaining available providers follow
/// as fallbacks, so a story with weak hints can still match another
/// domain — or stay hidden when nothing fits.
class DeepDiveRegistry {
  DeepDiveRegistry._();

  /// Every provider this build can use. Keyed providers are included
  /// only when their API key is configured (RAWG ships a default);
  /// [forContent] filters on [DeepDiveProvider.isAvailable].
  static List<DeepDiveProvider> defaults() => [
        AniListProvider.instance,
        TvmazeProvider.instance,
        RawgProvider.instance,
        ItunesProvider.instance,
      ];

  static const List<String> _domainOrder = [
    'anime',
    'screen',
    'games',
    'music',
  ];

  static const Map<String, List<String>> _keywords = {
    'anime': [
      'anime',
      'manga',
      'otaku',
      'cosplay',
      'shounen',
      'isekai',
      'weeb',
    ],
    'screen': [
      'movie',
      'film',
      'cinema',
      'hollywood',
      'tv',
      'series',
      'netflix',
      'episode',
      'drama',
      'documentary',
      'box office',
      'streaming',
      'trailer',
    ],
    'games': [
      'game',
      'gaming',
      'gamer',
      'esports',
      'e-sports',
      'videogame',
      'playstation',
      'xbox',
      'nintendo',
      'steam',
      'minecraft',
      'roblox',
      'fortnite',
      'valorant',
      'zelda',
      'mario',
      'pokemon',
    ],
    'music': [
      'music',
      'song',
      'album',
      'artist',
      'band',
      'singer',
      'kpop',
      'rapper',
      'hip hop',
      'rap',
      'grammy',
      'billboard',
      'spotify',
      'concert',
      'idol',
      'debut',
    ],
  };

  /// Detected domains for [content], strongest signal first. Ties fall
  /// back to [_domainOrder] (anime first — the app's core fandom).
  static List<String> detectDomains(ContentDoc content) {
    final blob = [
      content.fandomName,
      content.categoryName,
      content.title,
      ...content.tags,
    ].join(' ').toLowerCase();

    final scored = <String, int>{};
    for (final entry in _keywords.entries) {
      var score = 0;
      for (final keyword in entry.value) {
        if (_hit(blob, keyword)) score++;
      }
      if (score > 0) scored[entry.key] = score;
    }

    final ranked = scored.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        if (byScore != 0) return byScore;
        return _domainOrder
            .indexOf(a.key)
            .compareTo(_domainOrder.indexOf(b.key));
      });
    return [for (final e in ranked) e.key];
  }

  /// Available providers ordered for [content]: detected domains first,
  /// then the rest as fallbacks.
  static List<DeepDiveProvider> forContent(
    ContentDoc content, {
    List<DeepDiveProvider>? pool,
  }) {
    final available =
        (pool ?? defaults()).where((p) => p.isAvailable).toList();
    final detected = detectDomains(content);
    return [
      for (final domain in detected)
        ...available.where((p) => p.id == domain),
      ...available.where((p) => !detected.contains(p.id)),
    ];
  }

  /// Word-boundary prefix match: 'game' hits game/games/gaming but not
  /// 'mega'; multi-word keywords use plain containment.
  static bool _hit(String blob, String keyword) {
    if (keyword.contains(' ')) return blob.contains(keyword);
    var from = 0;
    while (true) {
      final i = blob.indexOf(keyword, from);
      if (i < 0) return false;
      if (i == 0 || !_isLetter(blob.codeUnitAt(i - 1))) return true;
      from = i + 1;
    }
  }

  static bool _isLetter(int code) =>
      (code >= 0x61 && code <= 0x7A) || (code >= 0x41 && code <= 0x5A);
}
