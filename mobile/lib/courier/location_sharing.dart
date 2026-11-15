import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../core/auth_api.dart';
import '../core/auth_session.dart';

class TripLocationSharing {
  TripLocationSharing({
    required this.session,
    required this.tripId,
    required this.routeVersion,
    required this.onStatus,
    required this.onRevoked,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final AuthSession session;
  final String tripId, routeVersion;
  final void Function(String?) onStatus;
  final void Function(String) onRevoked;
  final DateTime Function() clock;
  final String sessionId = const Uuid().v4();
  bool _sending = false, _stopped = false;
  DateTime? _lastAttempt;

  Future<void> publish(Position fix) async {
    if (_stopped || _sending || fix.accuracy > 40 || fix.accuracy < 0) return;
    if (_lastAttempt != null &&
        clock().difference(_lastAttempt!) < const Duration(seconds: 6)) {
      return;
    }
    _lastAttempt = clock();
    _sending = true;
    try {
      await session.commerceRequest(
        'POST',
        '/courier/trips/$tripId/location',
        body: {
          'session_id': sessionId,
          'route_version_id': int.parse(routeVersion),
          'latitude': fix.latitude,
          'longitude': fix.longitude,
          'accuracy_m': fix.accuracy,
          'heading':
              fix.heading.isFinite && fix.heading >= 0 && fix.heading <= 360
              ? fix.heading
              : null,
          'recorded_at': fix.timestamp.toUtc().toIso8601String(),
        },
      );
      if (!_stopped) onStatus(null);
    } on ApiException catch (error) {
      if (!_stopped) {
        if ([401, 403, 404].contains(error.status) ||
            error.code == 'TRACKING_STOPPED') {
          onRevoked(error.message);
        } else {
          onStatus('Lokasi belum terkirim. ${error.message}');
        }
      }
    } catch (_) {
      if (!_stopped) {
        onStatus('Lokasi belum terkirim. Periksa koneksi ke server.');
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    try {
      await session.commerceRequest(
        'DELETE',
        '/courier/trips/$tripId/location',
        body: {
          'session_id': sessionId,
          'route_version_id': int.parse(routeVersion),
        },
      );
    } catch (_) {
      // The server expires the last location automatically when unreachable.
    }
  }
}
