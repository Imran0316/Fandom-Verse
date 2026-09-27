/// Google Maps configuration driven by `--dart-define=GOOGLE_MAPS_API_KEY=...`.
///
/// Keep this key out of source control: pass it at build/run time instead of
/// hardcoding it here. The default is intentionally empty so the app still
/// builds without a key (maps views simply stay empty/placeholder).
class MapsConfig {
  MapsConfig._();

  static const String _defineName = 'GOOGLE_MAPS_API_KEY';

  static String get apiKey =>
      String.fromEnvironment(_defineName, defaultValue: '');

  static bool get hasKey => apiKey.trim().isNotEmpty;

  /// HTTPS Google Maps directions URL for the provided coordinates.
  static String directionsUrl({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final origin =
        '${startLat.toStringAsFixed(6)},${startLng.toStringAsFixed(6)}';
    final destination =
        '${endLat.toStringAsFixed(6)},${endLng.toStringAsFixed(6)}';
    final encoded = Uri.encodeComponent(
      'origin=$origin&destination=$destination&travelmode=driving',
    );
    return 'https://www.google.com/maps/dir/?api=1&$encoded';
  }

  /// Embed URL for a marker at the given coordinate (no API key required).
  static String pinUrl({
    required double lat,
    required double lng,
    String? label,
  }) {
    final params = <String, String>{
      'q': label != null && label.isNotEmpty
          ? '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}($label)'
          : '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
    };
    return Uri.https('www.google.com', '/maps', params).toString();
  }
}
