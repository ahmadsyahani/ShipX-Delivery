import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/courier/trip_start_state.dart';
import 'package:shipx/courier/trip_start_panel.dart';
import 'shopping_test.dart' show MemoryPending, CommerceSession;

Map<String, dynamic> payload() => {
  'lock_version': 2,
  'route_version_id': '3',
  'departure_review_id': '4',
  'manifest': [
    {'product_id': '1', 'quantity': 4},
    {'product_id': '2', 'quantity': 2},
  ],
};
Map<String, dynamic> detail() => {
  'id': '9',
  'status': 'assigned',
  'lock_version': 2,
  'route_version_id': '3',
  'departure_review': {'id': '4'},
  'can_start': true,
  'manifest': [
    {
      'product_id': '1',
      'quantity': 4,
      'variants': [
        {'name': 'Air'},
      ],
    },
    {
      'product_id': '2',
      'quantity': 2,
      'variants': [
        {'name': 'Sabun'},
      ],
    },
  ],
};

void main() {
  test(
    'timeout survives restoration and replays the exact durable key and manifest',
    () async {
      final store = MemoryPending();
      final session = CommerceSession()
        ..persistence = store
        ..error = const SocketException('offline');
      final state = TripStartState(session: session, tripId: '9', store: store);
      await state.restore();
      final input = payload();
      expect(await state.submit(input), false);
      final first = session.requests.single;
      input['manifest'] = [];
      expect(state.pending, isNotNull);
      state.dispose();
      final restored = TripStartState(
        session: session,
        tripId: '9',
        store: store,
      );
      await restored.restore();
      session.error = null;
      expect(await restored.retry(), true);
      expect(session.requests.last, first);
      expect(store.value, isNull);
      restored.dispose();
    },
  );
  test(
    'in-progress and transient responses retain pending; definitive conflicts allow fresh review',
    () async {
      final store = MemoryPending();
      final session = CommerceSession()
        ..persistence = store
        ..error = const ApiException(
          'Running',
          409,
          code: 'REQUEST_IN_PROGRESS',
        );
      final state = TripStartState(session: session, tripId: '9', store: store);
      await state.restore();
      await state.submit(payload());
      final key = state.pending!['key'];
      for (final status in [429, 500, 401, 403]) {
        session.error = ApiException('Retry', status);
        await state.retry();
        expect(state.pending!['key'], key);
      }
      session.error = const ApiException(
        'Plan changed',
        409,
        code: 'STALE_VERSION',
      );
      await state.retry();
      expect(state.pending, isNull);
      expect(store.value, isNull);
      state.dispose();
    },
  );
  test(
    'storage failure prevents POST and observed started trip clears unresolved state without resending',
    () async {
      final store = MemoryPending()..failWrite = true;
      final session = CommerceSession()..persistence = store;
      final state = TripStartState(session: session, tripId: '9', store: store);
      await state.restore();
      expect(await state.submit(payload()), false);
      expect(session.requests, isEmpty);
      store.failWrite = false;
      await state.restore();
      session.error = const SocketException('unknown');
      await state.submit(payload());
      final count = session.requests.length;
      await state.observeStarted();
      expect(store.value, isNull);
      expect(state.pending, isNull);
      expect(session.requests.length, count);
      state.dispose();
    },
  );
  testWidgets(
    'courier checks both quantities, confirms once, and cannot start a blocked plan',
    (tester) async {
      final store = MemoryPending();
      final session = CommerceSession()..persistence = store;
      int refreshes = 0;
      Future<void> show(Map<String, dynamic> trip) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TripStartPanel(
                  session: session,
                  trip: trip,
                  store: store,
                  onRefresh: () async {
                    refreshes++;
                  },
                  onBusyChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(detail());
      await tester.tap(find.text('Konfirmasi muatan & mulai trip'));
      await tester.pumpAndSettle();
      expect(find.text('Jumlah harus sesuai manifest: 4.'), findsOneWidget);
      expect(session.requests, isEmpty);
      await tester.enterText(find.byType(TextFormField).at(0), '4');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.tap(find.text('Konfirmasi muatan & mulai trip'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi muatan dan berangkat?'), findsOneWidget);
      await tester.tap(find.text('Mulai trip sekarang'));
      await tester.pumpAndSettle();
      expect(session.requests.single['body'], payload());
      expect(refreshes, 1);
      await show({
        ...detail(),
        'can_start': false,
        'start_block_reason': 'Menunggu tinjauan admin.',
      });
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Konfirmasi muatan & mulai trip',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
