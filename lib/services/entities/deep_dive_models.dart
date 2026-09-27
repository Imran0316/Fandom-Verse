/// Domain-neutral entities for the in-content Deep Dive graph.
///
/// One chain shape is shared by every domain:
///
/// media (title) → cast member (character + person) → person →
/// their other works → FanVerse posts.
///
/// Providers map their API payloads onto these models; anime uses
/// characters + voice actors, movies/TV actors + roles, games studios,
/// music artists.
class DiveMedia {
  const DiveMedia({
    required this.id,
    required this.title,
    this.romaji,
    this.english,
    this.imageUrl,
    this.year,
    this.format,
    this.score,
    this.kind = 'anime',
    this.cast = const [],
  });

  final int id;

  /// Display title.
  final String title;

  /// Alternate titles used for relevance matching (AniList romaji/english).
  final String? romaji;
  final String? english;

  final String? imageUrl;
  final int? year;

  /// Short format label for the card meta line (TV, Movie, Game, Song…).
  final String? format;

  /// Popularity score normalized to 0–100 across providers.
  final double? score;

  /// Provider-scoped discriminator: 'anime' | 'manga' | 'movie' | 'tv' |
  /// 'game' | 'song' | 'album'. Drives per-domain rail labels.
  final String kind;

  /// Cast list; may be empty until the provider lazily loads it.
  final List<DiveCastMember> cast;

  DiveMedia copyWith({List<DiveCastMember>? cast}) => DiveMedia(
        id: id,
        title: title,
        romaji: romaji,
        english: english,
        imageUrl: imageUrl,
        year: year,
        format: format,
        score: score,
        kind: kind,
        cast: cast ?? this.cast,
      );
}

/// The entity a cast slot is "about": an anime character, a played role,
/// or (for games/music) the studio/artist itself.
class DiveCharacter {
  const DiveCharacter({required this.id, required this.name, this.imageUrl});

  final int id;
  final String name;
  final String? imageUrl;
}

/// The person-hop: voice actor, actor, studio, or musician — with their
/// other works once resolved through the provider's person query.
class DivePerson {
  const DivePerson({
    required this.id,
    required this.name,
    this.imageUrl,
    this.kind,
    this.works = const [],
  });

  final int id;
  final String name;
  final String? imageUrl;

  /// Provider-scoped role of this person-hop (games: 'developer' |
  /// 'publisher'); tells the provider how to fetch their other works.
  final String? kind;

  /// Other works this person is credited on (filled by loadPerson).
  final List<DiveMedia> works;
}

/// One slot in a media's cast: a character plus the person(s) behind it.
class DiveCastMember {
  const DiveCastMember({
    required this.role,
    required this.character,
    this.voiceActors = const [],
  });

  /// Role chip on the card: 'MAIN' / 'SUPPORTING' (anime), 'Developer' /
  /// 'Publisher' (games); empty when the provider has no role concept.
  final String role;

  final DiveCharacter character;

  /// Voice actors (anime), actors (movies/TV), studios (games), or
  /// artists (music).
  final List<DivePerson> voiceActors;
}

/// A Deep Dive data source for one domain (anime, screen, games, music).
///
/// Implementations must be stateless with respect to any single story:
/// the widget drives every hop through these five calls.
abstract class DeepDiveProvider {
  /// Stable domain id: 'anime' | 'screen' | 'games' | 'music'.
  String get id;

  /// False when a required API key is missing — the registry skips it.
  bool get isAvailable;

  /// Header subtitle describing this domain's chain shape.
  String get subtitle;

  /// Rail label above the cast cards.
  String get castLabel;

  /// Rail label above the person cards.
  String get personLabel;

  /// Rail label above the media cards (kind-aware: 'THE MOVIE' vs
  /// 'THE SHOW'). Null media = while still loading.
  String mediaLabel(DiveMedia? media);

  /// Caption under the focused person card ('Voice of X', 'as Cobb',
  /// 'Developer'); null for no caption.
  String? personCaption(DiveCastMember member);

  /// Anchor candidates for [query] (relevance-filtered by the widget).
  Future<List<DiveMedia>> search(String query);

  /// Cast for a media that was found without one embedded.
  Future<List<DiveCastMember>> loadCast(DiveMedia media);

  /// The person with their other works resolved.
  Future<DivePerson?> loadPerson(DivePerson person);
}
