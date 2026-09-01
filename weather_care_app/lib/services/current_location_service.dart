import 'package:geolocator/geolocator.dart';

class DeviceCoordinates {
  final double latitude;
  final double longitude;

  const DeviceCoordinates({
    required this.latitude,
    required this.longitude,
  });
}

class CurrentLocationService {
  const CurrentLocationService();

  Future<DeviceCoordinates?> currentCoordinates({
    required bool gpsEnabled,
  }) async {
    try {
      if (!gpsEnabled || !await Geolocator.isLocationServiceEnabled()) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return DeviceCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}
