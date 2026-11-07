import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/courier/trips_page.dart';
import 'auth_session_test.dart' show MemoryStore;

Map<String, dynamic> trip() => {
  'id': '9',
  'trip_number': 'TR-QA',
  'timezone': 'Asia/Jakarta',
  'planned_departure_at': '2026-11-05T02:00:00Z',
  'vehicle': {'name': 'Motor QA', 'plate_number': 'B123QA'},
  'total_stops': 1,
  'planned_weight_g': 1000,
  'planned_volume_cm3': 1000,
  'depot': {'name': 'Depot QA', 'address_text': 'Alamat depot'},
  'stops': [
    {
      'sequence_no': 1,
      'order_number': 'SX-QA',
      'window_start_at': '2026-11-05T03:00:00Z',
      'window_end_at': '2026-11-05T05:00:00Z',
      'total_rp': 18000,
      'address': {
        'recipient_name': 'Penerima QA',
        'phone': '080000',
        'address_text': 'Alamat QA',
        'directions': 'Pagar hijau',
      },
      'items': [
        {
          'name': 'Barang snapshot',
          'quantity': 1,
          'unit_label': 'pak',
          'length_mm': 100,
          'width_mm': 100,
          'height_mm': 100,
          'handling_notes': 'Jangan dibalik',
        },
      ],
    },
  ],
};

class TripSession extends AuthSession {
  int reads = 0;
  bool removed = false, offline = false;
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    reads++;
    if (offline) throw Exception('Offline');
    if (path.endsWith('/9') && removed) throw const ApiException('Gone', 404);
    return {
      'data': path.endsWith('/9')
          ? trip()
          : removed
          ? []
          : [trip()],
    };
  }
}

class DeniedApi extends AuthApi {
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    bool envelope = false,
    Map<String, String>? headers,
  }) async => throw const ApiException('Inactive', 403);
}

void main() {
  testWidgets(
    'courier sees assigned stops and removed assignment clears recipient data',
    (tester) async {
      final session = TripSession();
      await tester.pumpWidget(
        MaterialApp(
          home: CourierTripsPage(session: session, id: '9'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TR-QA'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Penerima QA · 080000'), 200);
      expect(find.text('Penerima QA · 080000'), findsOneWidget);
      expect(find.textContaining('Barang snapshot'), findsOneWidget);
      session.removed = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.textContaining('tidak lagi tersedia'), findsOneWidget);
      expect(find.text('Penerima QA · 080000'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'inactive tab pauses polling; foreground refresh updates and offline retains known tasks',
    (tester) async {
      final session = TripSession();
      Widget page(bool active) => MaterialApp(
        home: CourierTripsPage(session: session, active: active),
      );
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      expect(session.reads, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(session.reads, 1);
      session.offline = true;
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(session.reads, 2);
      expect(find.text('TR-QA'), findsOneWidget);
      expect(find.textContaining('Periksa koneksi'), findsOneWidget);
      session.offline = false;
      session.removed = true;
      await tester.tap(find.byTooltip('Perbarui tugas'));
      await tester.pumpAndSettle();
      expect(find.text('TR-QA'), findsNothing);
      expect(find.text('Belum ada trip yang ditugaskan.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  test('inactive courier response clears stored authentication', () async {
    final store = MemoryStore();
    final session = AuthSession(api: DeniedApi(), store: store)
      ..user = const ShipXUser('1', 'QA', 'qa@example.test', 'courier');
    await expectLater(
      session.commerceRequest('GET', '/courier/trips'),
      throwsA(isA<ApiException>()),
    );
    expect(session.user, isNull);
    expect(store.value, isNull);
    session.dispose();
  });
}
