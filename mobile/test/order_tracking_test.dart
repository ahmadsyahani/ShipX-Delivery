import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/commerce/tracking_page.dart';
import 'local_navigation_page_test.dart' show MemoryTiles;
import 'local_navigation_page_test.dart' show RouteSession, RouteLocation;
import 'package:shipx/courier/trip_navigation_page.dart';
import 'navigation_route_test.dart' show routeJson;

class TrackingSession extends AuthSession {
  String status = 'live';
  ApiException? failure;
  int reads = 0;
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    reads++;
    if (failure != null) throw failure!;
    return {
      'status': status,
      'is_next_stop': true,
      'location': ['waiting', 'unavailable'].contains(status)
          ? null
          : {
              'latitude': 0,
              'longitude': 0,
              'recorded_at': '2026-11-14T02:00:00Z',
            },
      'destination': {
        'latitude': .001,
        'longitude': .001,
        'address_text': 'Alamat pesanan saya',
      },
      'route': status == 'live'
          ? {
              'shape': routeJson()['shape'],
              'duration_seconds': 120,
              'distance_m': 1000,
            }
          : null,
    };
  }
}

void main() {
  testWidgets('map panels remain usable in landscape with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget app(Widget page) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: page,
    );
    final tracking = TrackingSession();
    await tester.pumpWidget(
      app(
        OrderTrackingPage(
          session: tracking,
          orderId: '9',
          tileProvider: MemoryTiles(),
          clock: () => DateTime.utc(2026, 11, 14, 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    final courier = RouteSession();
    final location = RouteLocation();
    await tester.pumpWidget(
      app(
        TripNavigationPage(
          session: courier,
          tripId: '9',
          location: location,
          tileProvider: MemoryTiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    location.updates.close();
    tracking.dispose();
    courier.dispose();
  });
  testWidgets(
    'tracking shows road and own destination, labels stale and clears revoked access',
    (tester) async {
      final session = TrackingSession();
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingPage(
            session: session,
            orderId: '9',
            tileProvider: MemoryTiles(),
            clock: () => DateTime.utc(2026, 11, 14, 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sekitar 2 menit lagi'), findsOneWidget);
      expect(find.text('Alamat pesanan saya'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      session.status = 'stale';
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Lokasi terakhir · menunggu pembaruan'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);
      session.failure = const ApiException('Pesanan tidak tersedia', 404);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Alamat pesanan saya'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'waiting and finished delivery show status without courier coordinates',
    (tester) async {
      final session = TrackingSession()..status = 'waiting';
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingPage(
            session: session,
            orderId: '9',
            tileProvider: MemoryTiles(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Menunggu lokasi kurir'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      session.status = 'unavailable';
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pelacakan sudah berakhir'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
