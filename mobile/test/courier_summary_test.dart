import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/auth_page.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/courier/summary_page.dart';
import 'courier_trips_test.dart' show TripSession;

class SummarySession extends TripSession {
  SummarySession() {
    user = const ShipXUser('9', 'Kurir QA', 'courier@example.test', 'courier');
  }
  int summaryReads = 0;
  Object? summaryError;
  bool empty = false;

  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    if (path != '/courier/summary') {
      return super.commerceRequest(
        method,
        path,
        body: body,
        key: key,
        envelope: envelope,
      );
    }
    summaryReads++;
    if (summaryError != null) throw summaryError!;
    return {
      'active_trips': empty ? 0 : 1,
      'total_stops': empty ? 0 : 3,
      'pending_stops': empty ? 0 : 1,
      'delivered_stops': empty ? 0 : 1,
      'failed_stops': empty ? 0 : 1,
      'cod_collected_rp': empty ? 0 : 48000,
      'cod_remaining_rp': empty ? 0 : 18000,
      'updated_at': '2026-11-14T02:00:00Z',
      'next_trip': empty
          ? null
          : {'id': '9', 'trip_number': 'TR-QA', 'status': 'in_progress'},
    };
  }
}

void main() {
  testWidgets('courier menu opens summary and shortcut opens own trip', (
    tester,
  ) async {
    final session = SummarySession();
    await tester.pumpWidget(MaterialApp(home: RoleHome(session: session)));
    await tester.pumpAndSettle();
    expect(session.summaryReads, 0);
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(session.summaryReads, 1);
    expect(find.text('2 dari 3 tujuan ditangani'), findsOneWidget);
    expect(find.text('Rp48.000'), findsOneWidget);
    final action = find.text('Lanjutkan pengantaran');
    await tester.scrollUntilVisible(action, 200);
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Detail trip'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(session.summaryReads, 2);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'summary polls active tab, retains offline totals and clears revoked data',
    (tester) async {
      final session = SummarySession();
      Widget page(bool active) => MaterialApp(
        home: Scaffold(
          body: CourierSummaryPage(
            session: session,
            active: active,
            openTrips: () {},
          ),
        ),
      );
      await tester.pumpWidget(page(false));
      await tester.pump(const Duration(seconds: 15));
      expect(session.summaryReads, 0);
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(find.text('Rp48.000'), findsOneWidget);
      session.summaryError = Exception('offline');
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Menampilkan ringkasan terakhir.'), findsOneWidget);
      expect(find.text('Rp48.000'), findsOneWidget);
      session.summaryError = const ApiException('Akses dicabut', 403);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Rp48.000'), findsNothing);
      expect(find.text('Akses dicabut'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('empty summary links to trip list', (tester) async {
    final session = SummarySession()..empty = true;
    bool opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourierSummaryPage(
            session: session,
            openTrips: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada trip aktif'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lihat daftar trip'), 200);
    await tester.ensureVisible(find.text('Lihat daftar trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat daftar trip'));
    expect(opened, isTrue);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
