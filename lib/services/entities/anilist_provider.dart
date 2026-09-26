import 'dart:convert';

import 'package:http/http.dart' as http;

/// A media entry (anime) in the Deep Dive graph.
class AniMedia {
  const AniMedia({
    required this.id,
    required this.title,
    this.romaji,
    this.english,
    this.imageUrl,
    this.year,
    this.format,
    this.score,
    this.cast = const [],
  });

  final int id;

  /// Display title: english when present, otherwise romaji.
  final String title;
  final String? romaji;
  final String? english;
  final String? imageUrl;
  final int? year;
  final String? format;
  final double? score;

  /// Cast list with voice actors (only filled by full-media queries).
  final List<AniCastMember> cast;

  factory AniMedia.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title'];
    final romaji = rawTitle is Map
        ? rawTitle['romaji']?.toString().trim()
        : null;
    final english = rawTitle is Map
        ? rawTitle['english']?.toString().trim()
        : null;
    final display = english != null && english.isNotEmpty
        ? english
        : (romaji ?? '');
    final images = json['coverImage'];
    final start = json['startDate'];
    final rawCast = json['characters'];
    final edges = rawCast is Map && rawCast['edges'] is List
        ? rawCast['edges'] as List
        : const [];
    return AniMedia(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: display.isEmpty ? 'Untitled' : display,
      romaji: (romaji == null || romaji.isEmpty) ? null : romaji,
      english: (english == null || english.isEmpty) ? null : english,
      imageUrl: images is Map ? images['large']?.toString() : null,
      year: start is Map ? (start['year'] as num?)?.toInt() : null,
      format: json['format']?.toString(),
      score: (json['averageScore'] as num?)?.toDouble(),
      cast: [
        for (final e in edges)
          if (e is Map<String, dynamic>) AniCastMember.fromJson(e),
      ],
    );
  }
}

/// One slot in a media's cast: a character plus their voice actors.
class AniCastMember {
  const AniCastMember({
    required this.role,
    required this.character,
    this.voiceActors = const [],
  });

  final String role;
  final AniCharacter character;
  final List<AniPerson> voiceActors;

  factory AniCastMember.fromJson(Map<String, dynamic> json) {
    final node = json['node'];
    final actors = json['voiceActors'];
    return AniCastMember(
      role: json['role']?.toString() ?? '',
      character: node is Map<String, dynamic>
          ? AniCharacter.fromJson(node)
          : const AniCharacter(id: 0, name: 'Unknown'),
      voiceActors: actors is List
          ? [
              for (final a in actors)
                if (a is Map<String, dynamic>) AniPerson.fromJson(a),
            ]
          : const [],
    );
  }
}

class AniCharacter {
  const AniCharacter({required this.id, required this.name, this.imageUrl});

  final int id;
  final String name;
  final String? imageUrl;

  factory AniCharacter.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final images = json['image'];
    return AniCharacter(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: rawName is Map
          ? (rawName['full']?.toString() ?? 'Unknown')
          : 'Unknown',
      imageUrl: images is Map ? images['large']?.toString() : null,
    );
  }
}

/// A person in the graph: voice actor / staff member, with their works
/// when resolved through a Staff query.
class AniPerson {
  const AniPerson({
    required this.id,
    required this.name,
    this.imageUrl,
    this.works = const [],
  });

  final int id;
  final String name;
  final String? imageUrl;

  /// Other anime this person is credited on (Staff queries only).
  final List<AniMedia> works;

  factory AniPerson.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final images = json['image'];
    final rawWorks = json['staffMedia'];
    final nodes = rawWorks is Map && rawWorks['nodes'] is List
        ? rawWorks['nodes'] as List
        : const [];
    return AniPerson(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: rawName is Map ? (rawName['full']?.toString() ?? 'Unknown') : 'Unknown',
      imageUrl: images is Map ? images['large']?.toString() : null,
      works: [
        for (final n in nodes)
          if (n is Map<String, dynamic>) AniMedia.fromJson(n),
      ],
    );
  }
}

/// Anime / character / staff lookups via the public AniList GraphQL API
/// (https://graphql.anilist.co — no API key, CORS-open).
///
/// Every hop of the Deep Dive chain maps to one call:
/// content → [searchMedia] → cast+voice actors are bundled on the media
/// node → [personWorks] for a voice actor's other works.
class AniListProvider {
  AniListProvider({http.Client? client}) : _client = client ?? http.Client();

  static final AniListProvider instance = AniListProvider();

  final http.Client _client;
  static const String _endpoint = 'https://graphql.anilist.co';

  static const String _mediaFields = r'''
  id
  title { romaji english }
  coverImage { large }
  startDate { year }
  format
  averageScore
  characters(perPage: 10, sort: [ROLE, RELEVANCE]) {
    edges {
      role
      node { id name { full } image { large } }
      voiceActors(language: JAPANESE, sort: RELEVANCE) {
        id
        name { full }
        image { large }
      }
    }
  }''';

  static const String _searchQuery = r'''
  query ($search: String!) {
    Page(page: 1, perPage: 5) {
      media(search: $search, type: ANIME, sort: POPULARITY_DESC) {
        __MEDIA__
      }
    }
  }''';

  static const String _byIdQuery = r'''
  query ($id: Int!) {
    Media(id: $id, type: ANIME) {
      __MEDIA__
    }
  }''';

  static const String _worksQuery = r'''
  query ($id: Int!) {
    Staff(id: $id) {
      id
      name { full }
      image { large }
      staffMedia(perPage: 8, sort: POPULARITY_DESC, type: ANIME) {
        nodes {
          id
          title { romaji english }
          coverImage { large }
          startDate { year }
          format
        }
      }
    }
  }''';

  /// Up to five anime matching [query] (with cast + voice actors).
  Future<List<AniMedia>> searchMedia(String query) async {
    final data = await _post(
      _searchQuery.replaceFirst('__MEDIA__', _mediaFields),
      {'search': query},
    );
    final page = data?['Page'];
    final media = page is Map && page['media'] is List
        ? page['media'] as List
        : const [];
    return [
      for (final m in media)
        if (m is Map<String, dynamic>) AniMedia.fromJson(m),
    ];
  }

  /// A single anime by id (with cast + voice actors).
  Future<AniMedia?> mediaById(int id) async {
    final data = await _post(
      _byIdQuery.replaceFirst('__MEDIA__', _mediaFields),
      {'id': id},
    );
    final media = data?['Media'];
    return media is Map<String, dynamic> ? AniMedia.fromJson(media) : null;
  }

  /// A person (voice actor / staff) with their other credited works.
  Future<AniPerson?> personWorks(int id) async {
    final data = await _post(_worksQuery, {'id': id});
    final staff = data?['Staff'];
    return staff is Map<String, dynamic> ? AniPerson.fromJson(staff) : null;
  }

  Future<Map<String, dynamic>?> _post(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final res = await _client
        .post(
          Uri.parse(_endpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'query': query, 'variables': variables}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw StateError('AniList returned ${res.statusCode}.');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('AniList returned an unexpected payload.');
    }
    if (decoded['errors'] != null) {
      throw StateError('AniList query failed.');
    }
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : null;
  }
}
