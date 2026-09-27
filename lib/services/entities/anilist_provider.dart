import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deep_dive_models.dart';

/// Anime / manga / character / staff lookups via the public AniList GraphQL
/// API (https://graphql.anilist.co — no API key, CORS-open).
///
/// Every hop of the Deep Dive chain maps to one call:
/// content → [search] → cast + voice actors are bundled on the media node
/// → [loadPerson] for a voice actor's other works.
class AniListProvider implements DeepDiveProvider {
  AniListProvider({http.Client? client}) : _client = client ?? http.Client();

  static final AniListProvider instance = AniListProvider();

  final http.Client _client;
  static const String _endpoint = 'https://graphql.anilist.co';

  @override
  String get id => 'anime';

  @override
  bool get isAvailable => true;

  @override
  String get subtitle => 'Story → anime → cast → voice actors → posts';

  @override
  String get castLabel => 'RELATED CHARACTERS';

  @override
  String get personLabel => 'VOICE ACTOR';

  @override
  String mediaLabel(DiveMedia? media) =>
      media?.format == 'MANGA' ? 'THE MANGA' : 'THE ANIME';

  @override
  String? personCaption(DiveCastMember member) =>
      'Voice of ${member.character.name}';

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
      media(search: $search, sort: POPULARITY_DESC) {
        __MEDIA__
      }
    }
  }''';

  static const String _byIdQuery = r'''
  query ($id: Int!) {
    Media(id: $id) {
      __MEDIA__
    }
  }''';

  static const String _worksQuery = r'''
  query ($id: Int!) {
    Staff(id: $id) {
      id
      name { full }
      image { large }
      staffMedia(perPage: 8, sort: POPULARITY_DESC) {
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

  @override
  Future<List<DiveMedia>> search(String query) async {
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
        if (m is Map<String, dynamic>) _mediaFromJson(m),
    ];
  }

  @override
  Future<List<DiveCastMember>> loadCast(DiveMedia media) async {
    final data = await _post(
      _byIdQuery.replaceFirst('__MEDIA__', _mediaFields),
      {'id': media.id},
    );
    final node = data?['Media'];
    if (node is! Map<String, dynamic>) return const [];
    return _mediaFromJson(node).cast;
  }

  @override
  Future<DivePerson?> loadPerson(DivePerson person) async {
    final data = await _post(_worksQuery, {'id': person.id});
    final staff = data?['Staff'];
    if (staff is! Map<String, dynamic>) return null;
    final works = staff['staffMedia'];
    final nodes = works is Map && works['nodes'] is List
        ? works['nodes'] as List
        : const [];
    return DivePerson(
      id: person.id,
      name: _personName(staff) ?? person.name,
      imageUrl: _personImage(staff) ?? person.imageUrl,
      kind: person.kind,
      works: [
        for (final n in nodes)
          if (n is Map<String, dynamic>) _mediaFromJson(n),
      ],
    );
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

  // ------------------------------- Parsing --------------------------------

  static DiveMedia _mediaFromJson(Map<String, dynamic> json) {
    final rawTitle = json['title'];
    final romaji =
        rawTitle is Map ? rawTitle['romaji']?.toString().trim() : null;
    final english =
        rawTitle is Map ? rawTitle['english']?.toString().trim() : null;
    final display =
        english != null && english.isNotEmpty ? english : (romaji ?? '');
    final images = json['coverImage'];
    final start = json['startDate'];
    final format = json['format']?.toString();
    final rawCast = json['characters'];
    final edges = rawCast is Map && rawCast['edges'] is List
        ? rawCast['edges'] as List
        : const [];
    return DiveMedia(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: display.isEmpty ? 'Untitled' : display,
      romaji: (romaji == null || romaji.isEmpty) ? null : romaji,
      english: (english == null || english.isEmpty) ? null : english,
      imageUrl: images is Map ? images['large']?.toString() : null,
      year: start is Map ? (start['year'] as num?)?.toInt() : null,
      format: format,
      score: (json['averageScore'] as num?)?.toDouble(),
      kind: format == 'MANGA' ? 'manga' : 'anime',
      cast: [
        for (final e in edges)
          if (e is Map<String, dynamic>) _castMemberFromJson(e),
      ],
    );
  }

  static DiveCastMember _castMemberFromJson(Map<String, dynamic> json) {
    final node = json['node'];
    final actors = json['voiceActors'];
    return DiveCastMember(
      role: json['role']?.toString() ?? '',
      character: node is Map<String, dynamic>
          ? _characterFromJson(node)
          : const DiveCharacter(id: 0, name: 'Unknown'),
      voiceActors: actors is List
          ? [
              for (final a in actors)
                if (a is Map<String, dynamic>)
                  DivePerson(
                    id: (a['id'] as num?)?.toInt() ?? 0,
                    name: _personName(a) ?? 'Unknown',
                    imageUrl: _personImage(a),
                  ),
            ]
          : const [],
    );
  }

  static DiveCharacter _characterFromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final images = json['image'];
    return DiveCharacter(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: rawName is Map
          ? (rawName['full']?.toString() ?? 'Unknown')
          : 'Unknown',
      imageUrl: images is Map ? images['large']?.toString() : null,
    );
  }

  static String? _personName(Map<String, dynamic> json) {
    final rawName = json['name'];
    if (rawName is Map) return rawName['full']?.toString();
    return null;
  }

  static String? _personImage(Map<String, dynamic> json) {
    final images = json['image'];
    return images is Map ? images['large']?.toString() : null;
  }
}
