import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/courier/delivery_result_state.dart';
import 'package:shipx/courier/delivery_result_panel.dart';
import 'shopping_test.dart' show MemoryPending;

class ResultSession extends AuthSession {
  final uploads = <String>[];
  final results = <Map<String, dynamic>>[];
  Object? uploadError, resultError;
  @override
  Future<Map<String, dynamic>> uploadProof(
    String path,
    Uint8List bytes,
    String key,
  ) async {
    uploads.add(key);
    if (uploadError != null) throw uploadError!;
    return {'id': 'ed2a7db7-400d-4302-9999-e182a8c37ff4'};
  }

  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    results.add({'key': key, 'body': body});
    if (resultError != null) throw resultError!;
    return {'id': '1', 'outcome': body!['outcome']};
  }
}

Map<String, dynamic> resultPayload() => {
  'trip_version': 3,
  'order_version': 3,
  'outcome': 'delivered',
  'cash_received_rp': 48000,
  'failure_reason': null,
  'notes': null,
  'proof_upload_id': null,
};

void main() {
  testWidgets(
    'courier records failure through the form and confirmation dialog',
    (tester) async {
      final session = ResultSession();
      final store = MemoryPending();
      int refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeliveryResultPanel(
                session: session,
                trip: const {'id': '1', 'lock_version': 3},
                stop: const {
                  'id': '2',
                  'order_version': 3,
                  'total_rp': 48000,
                  'can_record_result': true,
                },
                store: store,
                onRefresh: () async {
                  refreshed++;
                },
                onBusyChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Berhasil diserahkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gagal diantar').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Penerima tidak berada di lokasi',
      );
      await tester.ensureVisible(find.text('Tinjau hasil pengiriman'));
      await tester.tap(find.text('Tinjau hasil pengiriman'));
      await tester.pumpAndSettle();
      expect(find.text('Simpan kiriman gagal?'), findsOneWidget);
      await tester.tap(find.text('Simpan hasil'));
      await tester.pumpAndSettle();
      expect(session.results.single['body']['outcome'], 'failed');
      expect(session.results.single['body']['cash_received_rp'], 0);
      expect(session.uploads, isEmpty);
      expect(refreshed, 1);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  test(
    'upload and result survive restoration with identical keys after unknown result',
    () async {
      final directory = await Directory.systemTemp.createTemp('shipx-result-');
      final photo = File('${directory.path}/proof.jpg');
      await photo.writeAsBytes([1, 2, 3]);
      final store = MemoryPending();
      final session = ResultSession()
        ..resultError = const SocketException('lost reply');
      final state = DeliveryResultState(
        session: session,
        tripId: '1',
        stopId: '2',
        store: store,
      );
      await state.restore();
      expect(await state.submit(resultPayload(), photo.path), false);
      expect(session.uploads.length, 1);
      final sent = session.results.single;
      state.dispose();
      final restored = DeliveryResultState(
        session: session,
        tripId: '1',
        stopId: '2',
        store: store,
      );
      await restored.restore();
      session.resultError = null;
      expect(await restored.retry(), true);
      expect(session.uploads.length, 1);
      expect(session.results.last, sent);
      expect(store.value, isNull);
      expect(await photo.exists(), false);
      restored.dispose();
      session.dispose();
      await directory.delete();
    },
  );
  test(
    'upload retry preserves key and a definitive conflict requires fresh review',
    () async {
      final directory = await Directory.systemTemp.createTemp('shipx-result-');
      final photo = File('${directory.path}/proof.jpg');
      await photo.writeAsBytes([1]);
      final session = ResultSession()
        ..uploadError = const SocketException('offline');
      final store = MemoryPending();
      final state = DeliveryResultState(
        session: session,
        tripId: '1',
        stopId: '2',
        store: store,
      );
      await state.restore();
      await state.submit(resultPayload(), photo.path);
      final uploadKey = session.uploads.single;
      session.uploadError = null;
      session.resultError = const ApiException(
        'Changed',
        409,
        code: 'STALE_VERSION',
      );
      await state.retry();
      expect(session.uploads.last, uploadKey);
      expect(state.needsReview, true);
      final count = session.results.length;
      await state.retry();
      expect(session.results.length, count);
      await state.reviewAgain();
      expect(state.pending, isNull);
      expect(await photo.exists(), true);
      state.dispose();
      session.dispose();
      await photo.delete();
      await directory.delete();
    },
  );
  test(
    'local persistence failure prevents network mutations and failed delivery needs no photo',
    () async {
      final session = ResultSession();
      final store = MemoryPending()..failWrite = true;
      final state = DeliveryResultState(
        session: session,
        tripId: '1',
        stopId: '2',
        store: store,
      );
      await state.restore();
      final payload = {
        ...resultPayload(),
        'outcome': 'failed',
        'cash_received_rp': 0,
        'failure_reason': 'Penerima tidak ada',
      };
      expect(await state.submit(payload, null), false);
      expect(session.results, isEmpty);
      expect(session.uploads, isEmpty);
      store.failWrite = false;
      await state.restore();
      expect(await state.submit(payload, null), true);
      expect(session.uploads, isEmpty);
      expect(session.results.single['body'], payload);
      state.dispose();
      session.dispose();
    },
  );
}
