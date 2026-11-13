import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
}

/// Foreground location, requested only after an explicit location/navigation action.
class DeviceLocation {
  const DeviceLocation();

  Stream<Position> watch() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );

  Future<LatLng> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        'Lokasi perangkat belum aktif. Aktifkan GPS atau pilih pin di peta.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Izin lokasi belum diberikan. Izinkan melalui pengaturan perangkat atau pilih pin di peta.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      throw const LocationFailure(
        'Lokasi belum dapat dibaca. Coba lagi atau pilih pin di peta.',
      );
    }
    return LatLng(position.latitude, position.longitude);
  }
}
