import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deep_dive_models.dart';

/// TV shows via the public TVmaze API (https://www.tvmaze.com/api —
/// no key, CORS-open). TVmaze covers TV series only, so the screen
/// domain walks show → cast → actor → their other shows.
///
/// Every hop verified live:
/// [search] `/search/shows` → [loadCast] `/shows/{id}/cast` →
/// [loadPerson] `/people/{id}/castcredits` + per-show detail lookups.
class TvmazeProvider implements DeepDiveProvider {
  TvmazeProvider({http.Client? client}) : _client = client ?? http.Client();

  static final TvmazeProvider instance = TvmazeProvider();

  final http.Client _client;
  static const String _base = 'https://api.tvmaze.com';

  @override
  String get id => 'screen';

  @override
  bool get isAvailable => true;

  @override
  String get subtitle => 'Story → show → cast → stars → posts';

  @override
  String get castLabel => 'CAST';

  @override
  String get personLabel => 'ACTOR';

  @override
  String mediaLabel(DiveMedia? media) => 'THE SHOW';

  @override
  String? personCaption(DiveCastMember member) {
    final character = member.character.name.trim();
    if (character.isEmpty) return null;
    final person = member.voiceActors.isEmpty
        ? ''
        : member.voiceActors.first.name.trim();
    if (character.toLowerCase() == person.toLowerCase()) return null;
    return 'as $character';
  }

  @override
  Future<List<DiveMedia>> search(String query) async {
    final data = await _get('/search/shows', {'q': query});
    if (data is! List) return const [];
    final out = <DiveMedia>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final show = item['show'];
      if (show is! Map<String, dynamic>) continue;
      final media = _mediaFromShow(show);
      if (media != null) out.add(media);
      if (out.length >= 5) break;
    }
    return out;
  }

  @override
  Future<List<DiveCastMember>> loadCast(DiveMedia media) async {
    final data = await _get('/shows/${media.id}/cast', const {});
    if (data is! List) return const [];
    final out = <DiveCastMember>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final person = item['person'];
      final character = item['character'];
      if (person is! Map<String, dynamic>) continue;
      final personId = (person['id'] as num?)?.toInt();
      final personName = person['name']?.toString().trim();
      if (personId == null || personName == null || personName.isEmpty) {
        continue;
      }
      final characterName =
          character is Map<String, dynamic>
              ? character['name']?.toString().trim() ?? ''
              : '';
      final personImage = _image(person);
      final characterImage =
          character is Map<String, dynamic> ? _image(character) : null;
      final characterId = character is Map<String, dynamic>
          ? (character['id'] as num?)?.toInt()
          : null;
      out.add(
        DiveCastMember(
          role: '',
          character: DiveCharacter(
            id: characterId ?? personId,
            name: characterName.isEmpty ? personName : characterName,
            imageUrl: characterImage,
          ),
          voiceActors: [
            DivePerson(id: personId, name: personName, imageUrl: personImage),
          ],
        ),
      );
      if (out.length >= 10) break;
    }
    return out;
  }

  @override
  Future<DivePerson?> loadPerson(DivePerson person) async {
    final data = await _get('/people/${person.id}/castcredits', const {});
    final stubs = <_ShowStub>[];
    final seen = <int>{};
    if (data is List) {
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final links = item['_links'];
        final showLink = links is Map ? links['show'] : null;
        final href = showLink is Map ? showLink['href']?.toString() : null;
        final name = showLink is Map ? showLink['name']?.toString() : null;
        final id = href == null
            ? null
            : int.tryParse(href.replaceAll(RegExp(r'.*/shows/'), ''));
        if (id == null || !seen.add(id)) continue;
        if (name == null || name.isEmpty) continue;
        stubs.add(_ShowStub(id, name));
        if (stubs.length >= 8) break;
      }
    }
    final works = await Future.wait([
      for (final stub in stubs) _showDetail(stub),
    ]);
    return DivePerson(
      id: person.id,
      name: person.name,
      imageUrl: person.imageUrl,
      kind: person.kind,
      works: [for (final w in works) ?w],
    );
  }

  /// Richer show (image, year, rating) for a credit stub; falls back to
  /// a title-only card when the detail call fails.
  Future<DiveMedia?> _showDetail(_ShowStub stub) async {
    try {
      final data = await _get('/shows/${stub.id}', const {});
      if (data is Map<String, dynamic>) {
        final media = _mediaFromShow(data);
        if (media != null) return media;
      }
    } catch (_) {
      // Fall through to the stub below.
    }
    return DiveMedia(
      id: stub.id,
      title: stub.title,
      format: 'TV',
      kind: 'tv',
    );
  }

  DiveMedia? _mediaFromShow(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final title = json['name']?.toString().trim();
    if (id == null || title == null || title.isEmpty) return null;
    final premiered = json['premiered']?.toString() ?? '';
    final rating = json['rating'];
    final average = rating is Map ? (rating['average'] as num?) : null;
    return DiveMedia(
      id: id,
      title: title,
      imageUrl: _image(json),
      year: premiered.length >= 4
          ? int.tryParse(premiered.substring(0, 4))
          : null,
      format: 'TV',
      score: average == null ? null : (average * 10).clamp(0, 100).toDouble(),
      kind: 'tv',
    );
  }

  static String? _image(Map<String, dynamic> json) {
    final image = json['image'];
    if (image is! Map) return null;
    final original = image['original']?.toString();
    if (original != null && original.isNotEmpty) return original;
    final medium = image['medium']?.toString();
    if (medium != null && medium.isNotEmpty) return medium;
    return null;
  }

  Future<dynamic> _get(String path, Map<String, String> params) async {
    final uri = Uri.parse('$_base$path').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw StateError('TVmaze returned ${res.statusCode}.');
    }
    return jsonDecode(res.body);
  }
}

class _ShowStub {
  const _ShowStub(this.id, this.title);

  final int id;
  final String title;
}
