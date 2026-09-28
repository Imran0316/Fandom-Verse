import 'package:geolocator/geolocator.dart';

class EventLocationException implements Exception {
  const EventLocationException(
    this.message, {
    this.permanentlyDenied = false,
    this.locationServiceDisabled = false,
  });

  final String message;
  final bool permanentlyDenied;
  final bool locationServiceDisabled;

  @override
  String toString() => message;
}

class EventLocationService {
  EventLocationService._();

  static final EventLocationService instance = EventLocationService._();

  Future<Position> currentPosition({bool requestPermission = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const EventLocationException(
          'Location services are turned off. You can still browse by city.',
          locationServiceDisabled: true,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const EventLocationException(
          'Location access is blocked. Enable it in your device settings or browse by city.',
          permanentlyDenied: true,
        );
      }
      if (permission == LocationPermission.denied) {
        throw const EventLocationException(
          'Location permission was denied. You can still browse by city.',
        );
      }
    } on EventLocationException {
      rethrow;
    } catch (_) {
      // Missing plugin, unsupported web API, etc.
      throw const EventLocationException(
        'Your current location is unavailable. You can still browse by city.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      throw const EventLocationException(
        'Your current location is unavailable. You can still browse by city.',
      );
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  double distanceInKilometres({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    return Geolocator.distanceBetween(
          fromLatitude,
          fromLongitude,
          toLatitude,
          toLongitude,
        ) /
        1000;
  }
}
