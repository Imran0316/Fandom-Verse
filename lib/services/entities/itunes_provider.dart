import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deep_dive_models.dart';

/// Music via the public iTunes Search API
/// (https://performance-partners.apple.com/search-api — no key,
/// CORS-open).
///
/// Chain: content → [search] (songs + albums, artist embedded as the
/// cast slot) → [loadPerson] for the artist's other albums.
class ItunesProvider implements DeepDiveProvider {
  ItunesProvider({http.Client? client}) : _client = client ?? http.Client();

  static final ItunesProvider instance = ItunesProvider();

  final http.Client _client;
  static const String _searchBase = 'https://itunes.apple.com/search';
  static const String _lookupBase = 'https://itunes.apple.com/lookup';

  @override
  String get id => 'music';

  @override
  bool get isAvailable => true;

  @override
  String get subtitle => 'Story → song → artists → albums → posts';

  @override
  String get castLabel => 'ARTISTS';

  @override
  String get personLabel => 'ARTIST';

  @override
  String mediaLabel(DiveMedia? media) =>
      media?.kind == 'album' ? 'THE ALBUM' : 'THE SONG';

  @override
  String? personCaption(DiveCastMember member) => null;

  @override
  Future<List<DiveMedia>> search(String query) async {
    final data = await _get(_searchBase, {
      'term': query,
      'media': 'music',
      'entity': 'song,album',
      'limit': '8',
    });
    final results = data?['results'];
    if (results is! List) return const [];
    final out = <DiveMedia>[];
    final seen = <int>{};
    for (final r in results) {
      if (r is! Map<String, dynamic>) continue;
      final media = _mediaFrom(r);
      if (media == null || !seen.add(media.id)) continue;
      out.add(media);
      if (out.length >= 5) break;
    }
    return out;
  }

  @override
  Future<List<DiveCastMember>> loadCast(DiveMedia media) async {
    final data = await _get(_lookupBase, {'id': '${media.id}'});
    final results = data?['results'];
    if (results is! List) return const [];
    for (final r in results) {
      if (r is! Map<String, dynamic>) continue;
      final cast = _castFrom(r);
      if (cast != null) return [cast];
    }
    return const [];
  }

  @override
  Future<DivePerson?> loadPerson(DivePerson person) async {
    final data = await _get(_lookupBase, {
      'id': '${person.id}',
      'entity': 'album',
      'limit': '8',
    });
    final results = data?['results'];
    if (results is! List) return null;
    final works = <DiveMedia>[];
    for (final r in results) {
      if (r is! Map<String, dynamic>) continue;
      if (r['wrapperType']?.toString() == 'artist') continue;
      final media = _mediaFrom(r);
      if (media != null) works.add(media);
      if (works.length >= 8) break;
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
    final isTrack = json['wrapperType']?.toString() == 'track';
    final isCollection = json['wrapperType']?.toString() == 'collection';
    if (!isTrack && !isCollection) return null;
    final id = (isTrack
            ? (json['trackId'] as num?)?.toInt()
            : (json['collectionId'] as num?)?.toInt()) ??
        0;
    final title = (isTrack ? json['trackName'] : json['collectionName'])
        ?.toString()
        .trim();
    if (id == 0 || title == null || title.isEmpty) return null;
    final date = json['releaseDate']?.toString() ?? '';
    final cast = _castFrom(json);
    return DiveMedia(
      id: id,
      title: title,
      imageUrl: _artwork(json['artworkUrl100']?.toString()),
      year: date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null,
      format: isTrack ? 'Song' : 'Album',
      kind: isTrack ? 'song' : 'album',
      cast: [?cast],
    );
  }

  DiveCastMember? _castFrom(Map<String, dynamic> json) {
    final artistId = (json['artistId'] as num?)?.toInt();
    final artistName = json['artistName']?.toString().trim();
    if (artistId == null || artistId == 0 || artistName == null ||
        artistName.isEmpty) {
      return null;
    }
    final image = _artwork(json['artworkUrl100']?.toString());
    return DiveCastMember(
      role: '',
      character: DiveCharacter(id: artistId, name: artistName, imageUrl: image),
      voiceActors: [
        DivePerson(id: artistId, name: artistName, imageUrl: image),
      ],
    );
  }

  static String? _artwork(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.replaceAll(RegExp(r'\d+x\d+bb'), '400x400bb');
  }

  Future<Map<String, dynamic>?> _get(
    String base,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(base).replace(queryParameters: params);
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw StateError('iTunes returned ${res.statusCode}.');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('iTunes returned an unexpected payload.');
    }
    return decoded;
  }
}
