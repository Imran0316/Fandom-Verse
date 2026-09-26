import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resolves event city names to map coordinates via the Google Geocoding API.
///
/// Results (including failures) are memoized in memory so a city is only
/// requested once per app session. Every network/parse failure resolves to
/// `null` instead of throwing, so map screens degrade gracefully when the
/// key, billing or connectivity is missing.
class GeocodeService {
  GeocodeService({http.Client? client, this.apiKey = googleMapsApiKey})
      : _client = client ?? http.Client();

  static final GeocodeService instance = GeocodeService();

  /// Same browser key declared in `web/index.html` for the Maps JS API.
  /// The Google Cloud project must have **Geocoding API** enabled.
  static const String googleMapsApiKey = 'AIzaSyCjmNIAbzzGiCRVPFoKhcz1mCywaJdnIYc';

  final http.Client _client;
  final String apiKey;
  final Map<String, ({double lat, double lng})> _cache = {};
  final Set<String> _inFlight = <String>{};

  /// Returns coordinates for [city], or `null` when they cannot be resolved.
  Future<({double lat, double lng})?> geocode(String city) async {
    final key = city.trim().toLowerCase();
    if (key.isEmpty) return null;
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_inFlight.contains(key)) return null;
    _inFlight.add(key);
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': city.trim(),
        'key': apiKey,
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      final loc = parseGeocodeResponse(res.body);
      if (loc != null) _cache[key] = loc;
      return loc;
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Extracts the first result's location from a Geocoding API JSON body.
  /// Exposed for tests; returns `null` on anything unexpected.
  static ({double lat, double lng})? parseGeocodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['status'] != 'OK') return null;
      final results = decoded['results'];
      if (results is! List || results.isEmpty) return null;
      final geometry = results.first;
      if (geometry is! Map<String, dynamic>) return null;
      final loc = geometry['geometry'];
      if (loc is! Map<String, dynamic>) return null;
      final position = loc['location'];
      if (position is! Map<String, dynamic>) return null;
      final lat = position['lat'];
      final lng = position['lng'];
      if (lat is! num || lng is! num) return null;
      return (lat: lat.toDouble(), lng: lng.toDouble());
    } catch (_) {
      return null;
    }
  }
}
