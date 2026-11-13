import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/app_theme.dart';
import 'package:shipx/courier/trip_overview.dart';
import 'package:shipx/courier/trip_map_page.dart';
import 'courier_trips_test.dart' show TripSession, trip;

void main() {
  testWidgets('map refresh reports a revoked assignment and disposes polling', (
    tester,
  ) async {
    final session = TripSession();
    await tester.pumpWidget(
      MaterialApp(
        home: TripMapPage(trip: trip(), session: session),
      ),
    );
    await tester.pumpAndSettle();
    expect(session.reads, 1);
    session.removed = true;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('Gone'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  test('map accepts numeric snapshot coordinates and rejects invalid pins', () {
    expect(tripPoint({'latitude': '-7.2', 'longitude': 112.7})?.latitude, -7.2);
    expect(tripPoint({'latitude': 91, 'longitude': 112}), isNull);
    expect(tripPoint({'latitude': 0, 'longitude': 'NaN'}), isNull);
    expect(tripPoint(null), isNull);
  });

  for (final width in [320.0, 390.0, 820.0]) {
    testWidgets('progress and next destination fit ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = trip();
      data['status'] = 'in_progress';
      final stops = List<Map<String, dynamic>>.from(data['stops'] as List);
      data['stops'] = stops;
      final pending = Map<String, dynamic>.from(stops.first as Map);
      stops.first['status'] = 'failed';
      pending['status'] = 'pending';
      pending['address'] = {
        'recipient_name': 'Penerima berikutnya',
        'address_text': 'Jalan pengantaran berikutnya dengan alamat panjang',
      };
      stops.add(pending);
      final session = TripSession();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.5 : 1)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: TripOverview(trip: data, session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 dari 2 tujuan ditangani'), findsOneWidget);
      expect(find.text('Penerima berikutnya'), findsOneWidget);
      expect(find.text('Total COD'), findsOneWidget);
      expect(tester.takeException(), isNull);
      session.dispose();
    });
  }

  testWidgets('returning trip directs courier to depot', (tester) async {
    final data = trip()..['status'] = 'awaiting_reconciliation';
    (data['stops'] as List).first['status'] = 'delivered';
    final session = TripSession();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripOverview(trip: data, session: session),
        ),
      ),
    );
    expect(find.text('Kembali ke depot'), findsOneWidget);
    expect(find.text('Total COD'), findsNothing);
    expect(find.text('Depot QA'), findsOneWidget);
    session.dispose();
  });
}
