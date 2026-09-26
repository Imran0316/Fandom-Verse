import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deep_dive_models.dart';

/// Games via RAWG (https://rawg.io/apidocs — free API key, browser CORS
/// verified). RAWG has no character credits, so the games chain walks
/// game → studio (developer / publisher) → their other games.
class RawgProvider implements DeepDiveProvider {
  RawgProvider({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ??
            const String.fromEnvironment(
              'RAWG_API_KEY',
              defaultValue: 'be9d079aac274d93b51cf53d4a16f11d',
            );

  static final RawgProvider instance = RawgProvider();

  final http.Client _client;
  final String _apiKey;

  static const String _base = 'https://api.rawg.io/api';

  @override
  String get id => 'games';

  @override
  bool get isAvailable => _apiKey.isNotEmpty;

  @override
  String get subtitle => 'Story → game → studios → other games → posts';

  @override
  String get castLabel => 'DEVELOPERS';

  @override
  String get personLabel => 'STUDIO';

  @override
  String mediaLabel(DiveMedia? media) => 'THE GAME';

  @override
  String? personCaption(DiveCastMember member) =>
      member.role.isEmpty ? null : member.role;

  @override
  Future<List<DiveMedia>> search(String query) async {
    final data = await _get('/games', {
      'search': query,
      'page_size': '5',
      'ordering': '-rating',
    });
    final results = data?['results'];
    if (results is! List) return const [];
    final out = <DiveMedia>[];
    for (final r in results) {
      if (r is! Map<String, dynamic>) continue;
      final media = _mediaFrom(r);
      if (media != null) out.add(media);
      if (out.length >= 5) break;
    }
    return out;
  }

  @override
  Future<List<DiveCastMember>> loadCast(DiveMedia media) async {
    final data = await _get('/games/${media.id}', const {});
    if (data is! Map<String, dynamic>) return const [];
    final out = <DiveCastMember>[];
    final seen = <String>{};

    void addCompanies(dynamic list, String kind) {
      if (list is! List) return;
      for (final c in list) {
        if (c is! Map<String, dynamic>) continue;
        final id = (c['id'] as num?)?.toInt();
        final name = c['name']?.toString().trim();
        if (id == null || name == null || name.isEmpty) continue;
        if (!seen.add('$kind:$id')) continue;
        final image = c['image_background']?.toString();
        final person = DivePerson(
          id: id,
          name: name,
          imageUrl: image,
          kind: kind,
        );
        out.add(
          DiveCastMember(
            role: kind == 'publisher' ? 'Publisher' : 'Developer',
            character: DiveCharacter(
              id: kind == 'publisher' ? id * 2 + 1 : id * 2,
              name: name,
              imageUrl: image,
            ),
            voiceActors: [person],
          ),
        );
        if (out.length >= 6) return;
      }
    }

    addCompanies(data['developers'], 'developer');
    addCompanies(data['publishers'], 'publisher');
    return out;
  }

  @override
  Future<DivePerson?> loadPerson(DivePerson person) async {
    final filter = person.kind == 'publisher' ? 'publishers' : 'developers';
    final data = await _get('/games', {
      filter: '${person.id}',
      'page_size': '8',
      'ordering': '-rating',
    });
    final results = data?['results'];
    final works = <DiveMedia>[];
    if (results is List) {
      for (final r in results) {
        if (r is! Map<String, dynamic>) continue;
        final media = _mediaFrom(r);
        if (media != null) works.add(media);
        if (works.length >= 8) break;
      }
    }
    return DivePerson(
      id: person.id,
      name: person.name,
      imageUrl: person.imageUrl,
      kind: person.kind,
      works: works,
    );
  }

  DiveMedia? _mediaFrom(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final title = json['name']?.toString().trim();
    if (id == null || title == null || title.isEmpty) return null;
    final released = json['released']?.toString() ?? '';
    final metacritic = (json['metacritic'] as num?)?.toDouble();
    final rating = (json['rating'] as num?)?.toDouble();
    double? score;
    if (metacritic != null && metacritic > 0) {
      score = metacritic;
    } else if (rating != null && rating > 0) {
      score = (rating * 20).clamp(0, 100).toDouble();
    }
    return DiveMedia(
      id: id,
      title: title,
      imageUrl: json['background_image']?.toString(),
      year: released.length >= 4 ? int.tryParse(released.substring(0, 4)) : null,
      format: 'Game',
      score: score,
      kind: 'game',
    );
  }

  Future<Map<String, dynamic>?> _get(
    String path,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse('$_base$path').replace(
      queryParameters: {
        ...params,
        'key': _apiKey,
      },
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw StateError('RAWG returned ${res.statusCode}.');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('RAWG returned an unexpected payload.');
    }
    return decoded;
  }
}
