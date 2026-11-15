import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/courier/location_sharing.dart';
import 'courier_trips_test.dart' show TripSession;

class SharingSession extends TripSession {
  final sent = <Map<String, dynamic>>[];
  ApiException? failure;
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    sent.add({'method': method, 'body': body});
    if (failure != null) throw failure!;
    return {'accepted': true};
  }
}

Position fix(DateTime now, {double accuracy = 5}) => Position(
  latitude: -7.25,
  longitude: 112.75,
  timestamp: now,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 90,
  headingAccuracy: 5,
  speed: 3,
  speedAccuracy: 1,
);

void main() {
  test(
    'sharing throttles fixes, skips inaccurate GPS and stops the same session',
    () async {
      final session = SharingSession();
      var now = DateTime.utc(2026, 11, 14, 2);
      final sharing = TripLocationSharing(
        session: session,
        tripId: '9',
        routeVersion: '7',
        onStatus: (_) {},
        onRevoked: (_) {},
        clock: () => now,
      );
      await sharing.publish(fix(now, accuracy: 99));
      expect(session.sent, isEmpty);
      await sharing.publish(fix(now));
      await sharing.publish(fix(now));
      expect(session.sent.length, 1);
      now = now.add(const Duration(seconds: 6));
      await sharing.publish(fix(now));
      expect(session.sent.length, 2);
      await sharing.stop();
      expect(session.sent.last['method'], 'DELETE');
      expect(
        session.sent.last['body']['session_id'],
        session.sent.first['body']['session_id'],
      );
      now = now.add(const Duration(seconds: 6));
      await sharing.publish(fix(now));
      expect(session.sent.length, 3);
      session.dispose();
    },
  );

  test('revoked tracking reports terminal state', () async {
    final session = SharingSession()
      ..failure = const ApiException(
        'Trip selesai',
        409,
        code: 'TRACKING_STOPPED',
      );
    String? message;
    final sharing = TripLocationSharing(
      session: session,
      tripId: '9',
      routeVersion: '7',
      onStatus: (_) {},
      onRevoked: (value) => message = value,
    );
    await sharing.publish(fix(DateTime.now()));
    expect(message, 'Trip selesai');
    await sharing.stop();
    session.dispose();
  });
}
