import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/device_location.dart';
import 'package:shipx/courier/trip_navigation_page.dart';
import 'navigation_route_test.dart' show routeJson;
import 'trip_navigation_test.dart' show navigableTrip;
import 'courier_trips_test.dart' show TripSession;

class RouteSession extends TripSession {
  int routes = 0;
  bool live = false;
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    if (removed) throw const ApiException('Penugasan dicabut', 404);
    if (method == 'POST') {
      routes++;
      return routeJson();
    }
    final data = navigableTrip();
    data['route_version_id'] = '7';
    data['depot'] = {'name': 'Depot', 'latitude': 0, 'longitude': 0};
    data['status'] = live ? 'in_progress' : 'assigned';
    (data['stops'] as List)[1]['address'] = {
      'recipient_name': 'Penerima berikutnya',
      'address_text': 'Alamat tujuan',
      'latitude': .001,
      'longitude': .001,
    };
    return {'data': data};
  }
}

class RouteLocation extends DeviceLocation {
  int located = 0;
  int watched = 0, cancelled = 0;
  late final updates = StreamController<Position>(
    onListen: () => watched++,
    onCancel: () => cancelled++,
  );
  @override
  Future<LatLng> locate() async {
    located++;
    return const LatLng(0, 0);
  }

  @override
  Stream<Position> watch() => updates.stream;
  void emit(double latitude, double longitude) => updates.add(
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 90,
      headingAccuracy: 5,
      speed: 5,
      speedAccuracy: 1,
    ),
  );
}

class MemoryTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==',
        ),
      );
}

void main() {
  testWidgets('assigned preview draws route without starting GPS stream', (
    tester,
  ) async {
    final session = RouteSession();
    final location = RouteLocation();
    await tester.pumpWidget(
      MaterialApp(
        home: TripNavigationPage(
          session: session,
          tripId: '9',
          location: location,
          tileProvider: MemoryTiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.text('Belok kiri'), findsOneWidget);
    expect(find.text('Pratinjau dari depot'), findsOneWidget);
    expect(location.watched, 0);
    expect(location.located, 0);
    expect(session.routes, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(location.updates.close());
    session.dispose();
  });

  testWidgets(
    'live fixes advance turns, reroute after three deviations, and stop on revoked access',
    (tester) async {
      final session = RouteSession()..live = true;
      final location = RouteLocation();
      var now = DateTime(2026, 11, 13, 10);
      await tester.pumpWidget(
        MaterialApp(
          home: TripNavigationPage(
            session: session,
            tripId: '9',
            location: location,
            tileProvider: MemoryTiles(),
            clock: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(location.watched, 1);
      expect(find.byIcon(Icons.navigation_rounded), findsNothing);
      location.emit(.0005, .001);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
      expect(find.text('Tiba di tujuan'), findsOneWidget);
      now = now.add(const Duration(seconds: 21));
      for (var i = 0; i < 3; i++) {
        location.emit(.001, 0);
        await tester.pumpAndSettle();
      }
      expect(session.routes, 2);
      session.removed = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Penugasan dicabut'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      expect(location.cancelled, 1);
      await tester.pumpWidget(const SizedBox());
      unawaited(location.updates.close());
      session.dispose();
    },
  );
}
