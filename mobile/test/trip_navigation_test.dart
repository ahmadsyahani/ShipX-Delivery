import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shipx/courier/trip_navigation_page.dart';
import 'package:shipx/courier/trip_navigation_target.dart';
import 'courier_trips_test.dart' show trip, TripSession;

Map<String, dynamic> navigableTrip() {
  final data = trip();
  data['status'] = 'assigned';
  data['vehicle'] = {'travel_mode': 'motorcycle'};
  data['depot'] = {'name': 'Depot', 'latitude': -7.2, 'longitude': 112.7};
  data['stops'] = <Map<String, dynamic>>[
    {'order_id': '1', 'status': 'delivered', 'sequence_no': 1},
    {
      'order_id': '2',
      'status': 'pending',
      'sequence_no': 2,
      'address': {
        'recipient_name': 'Tujuan berikutnya',
        'latitude': '-7.25',
        'longitude': '112.75',
      },
    },
    {
      'order_id': '3',
      'status': 'pending',
      'sequence_no': 3,
      'address': {
        'recipient_name': 'Tujuan sesudahnya',
        'latitude': -7.3,
        'longitude': 112.8,
      },
    },
  ];
  return data;
}

void main() {
  testWidgets('revoked assignment is rejected before opening GPS or routing', (
    tester,
  ) async {
    final session = TripSession()..removed = true;
    await tester.pumpWidget(
      MaterialApp(
        home: TripNavigationPage(session: session, tripId: '9'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gone'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('missing mode stops before asking for GPS and permits retry', (
    tester,
  ) async {
    final session = TripSession();
    await tester.pumpWidget(
      MaterialApp(
        home: TripNavigationPage(session: session, tripId: '9'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('jenis kendaraan belum tersedia'),
      findsOneWidget,
    );
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(session.reads, 2);
    expect(
      find.textContaining('jenis kendaraan belum tersedia'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  test('preview follows first unfinished stop and snapshot vehicle mode', () {
    final data = navigableTrip();
    final target = TripNavigationTarget.fromTrip(data)!;
    expect(target.id, '2');
    expect(target.name, 'Tujuan berikutnya');
    expect(target.mode, 'motorcycle');
    expect(target.guidance, isFalse);
    data['status'] = 'in_progress';
    expect(TripNavigationTarget.fromTrip(data)!.guidance, isTrue);
  });

  test('missing first pending pin never skips to a later stop', () {
    final data = navigableTrip();
    (data['stops'] as List)[1]['address'] = {'latitude': 99, 'longitude': 112};
    expect(TripNavigationTarget.fromTrip(data), isNull);
  });

  test(
    'reconciliation routes to depot; closed and unknown mode disable navigation',
    () {
      final data = navigableTrip()..['status'] = 'awaiting_reconciliation';
      expect(TripNavigationTarget.fromTrip(data)!.id, 'depot');
      data['status'] = 'completed';
      expect(TripNavigationTarget.fromTrip(data), isNull);
      data['status'] = 'in_progress';
      data['vehicle'] = {'travel_mode': 'unsupported'};
      expect(TripNavigationTarget.fromTrip(data), isNull);
    },
  );
}
