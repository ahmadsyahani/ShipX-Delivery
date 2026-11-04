import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/commerce/shopping_state.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';

class MemoryPending implements PendingStore {
  String? value;
  bool failWrite = false, failClear = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String input) async {
    if (failWrite) throw const FileSystemException('write');
    value = input;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw const FileSystemException('clear');
    value = null;
  }
}

class CommerceSession extends AuthSession {
  final List<Map<String, dynamic>> requests = [];
  Object? error;
  Completer<Map<String, dynamic>>? waiting;
  MemoryPending? persistence;
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    expect(
      persistence?.value,
      isNotNull,
      reason: 'Request must be durable before sending.',
    );
    requests.add({'path': path, 'key': key, 'body': body});
    if (error != null) throw error!;
    if (waiting != null) return waiting!.future;
    return {
      'id': '1',
      'order_number': 'SX-TEST',
      'status': path.endsWith('/cancel') ? 'cancelled' : 'pending',
    };
  }
}

Map<String, dynamic> product(String id) => {
  'id': id,
  'name': 'Barang $id',
  'unit_price_rp': 15000,
  'unit_label': 'pak',
  'available_quantity': 10,
};

void main() {
  Future<ShoppingState> cart(
    CommerceSession session,
    MemoryPending store,
  ) async {
    session.persistence = store;
    final state = ShoppingState(session: session, store: store);
    await state.restore();
    if (state.pending == null && !state.locked) {
      state.add(product('1'));
      state.chooseAddress({'id': '1'});
      state.chooseSlot({'id': '2'});
    }
    return state;
  }

  test(
    'successful checkout stores before sending, then clears cart and pending',
    () async {
      final session = CommerceSession();
      final store = MemoryPending();
      final state = await cart(session, store);
      final result = await state.create({'total_rp': 18000});
      expect(result?['id'], '1');
      expect(store.value, isNull);
      expect(state.lines, isEmpty);
      expect(state.pending, isNull);
      expect(state.locked, isFalse);
      expect(session.requests.single['body']['expected_total_rp'], 18000);
    },
  );
  test(
    'network uncertainty survives restart and reuses identical key and payload',
    () async {
      final session = CommerceSession()
        ..error = const SocketException('response lost');
      final store = MemoryPending();
      final state = await cart(session, store);
      await state.create({'total_rp': 18000});
      expect(state.pending, isNotNull);
      expect(state.locked, isTrue);
      final first = jsonEncode(session.requests.single);
      state.quantity('1', 2);
      expect(state.lines['1']!['quantity'], 1);
      final restored = ShoppingState(session: session, store: store);
      await restored.restore();
      session.error = null;
      await restored.retry();
      expect(jsonEncode(session.requests.last), first);
      expect(store.value, isNull);
      expect(restored.lastOrder?['id'], '1');
    },
  );
  test(
    'definitive stock error allows editing and next attempt receives new key',
    () async {
      final session = CommerceSession()
        ..error = const ApiException('Stok kurang', 409, code: 'OUT_OF_STOCK');
      final store = MemoryPending();
      final state = await cart(session, store);
      await state.create({'total_rp': 18000});
      final first = session.requests.single['key'];
      expect(state.pending, isNull);
      expect(state.lines, isNotEmpty);
      expect(state.locked, isFalse);
      state.quantity('1', 2);
      session.error = null;
      await state.create({'total_rp': 33000});
      expect(session.requests.last['key'], isNot(first));
    },
  );
  test(
    'in-progress and server failures keep the request for safe retry',
    () async {
      for (final error in [
        const ApiException('Processing', 409, code: 'REQUEST_IN_PROGRESS'),
        const ApiException('Server', 500),
      ]) {
        final session = CommerceSession()..error = error;
        final store = MemoryPending();
        final state = await cart(session, store);
        await state.create({'total_rp': 18000});
        expect(store.value, isNotNull);
        expect(state.locked, isTrue);
      }
    },
  );
  test('write failure prevents any API call', () async {
    final session = CommerceSession();
    final store = MemoryPending()..failWrite = true;
    final state = await cart(session, store);
    await state.create({'total_rp': 18000});
    expect(session.requests, isEmpty);
    expect(state.pending, isNull);
    expect(state.busy, isFalse);
  });
  test(
    'success with failed local cleanup keeps same request until cleanup succeeds',
    () async {
      final session = CommerceSession();
      final store = MemoryPending()..failClear = true;
      final state = await cart(session, store);
      await state.create({'total_rp': 18000});
      final first = session.requests.single['key'];
      expect(state.pending, isNotNull);
      expect(state.lastOrder?['id'], '1');
      store.failClear = false;
      await state.retry();
      expect(session.requests.last['key'], first);
      expect(state.pending, isNull);
    },
  );
  test('double taps cannot send concurrent requests', () async {
    final session = CommerceSession()
      ..waiting = Completer<Map<String, dynamic>>();
    final store = MemoryPending();
    final state = await cart(session, store);
    final pending = state.create({'total_rp': 18000});
    await Future<void>.delayed(Duration.zero);
    await state.retry();
    expect(session.requests.length, 1);
    session.waiting!.complete({'id': '1'});
    await pending;
  });
  test(
    'old pending requests require history review rather than automatic replay',
    () async {
      final store = MemoryPending()
        ..value = jsonEncode({
          'kind': 'create',
          'path': '/orders',
          'key': 'old',
          'created_at': DateTime.now()
              .subtract(const Duration(days: 31))
              .toIso8601String(),
          'payload': {},
        });
      final session = CommerceSession()..persistence = store;
      final state = ShoppingState(session: session, store: store);
      await state.restore();
      await state.retry();
      expect(session.requests, isEmpty);
      expect(state.needsReview, isTrue);
      expect(state.locked, isTrue);
      await state.acknowledgeReviewed();
      expect(state.locked, isFalse);
    },
  );
  test('unreadable pending request blocks new orders', () async {
    final store = MemoryPending()..value = 'not-json';
    final state = ShoppingState(session: CommerceSession(), store: store);
    await state.restore();
    expect(state.storageError, isTrue);
    expect(state.locked, isTrue);
  });
  test(
    'cancellation is persisted and does not remove unrelated cart items',
    () async {
      final session = CommerceSession();
      final store = MemoryPending();
      final state = await cart(session, store);
      await state.cancel({'id': '9', 'lock_version': 2}, 'Tidak jadi');
      expect(session.requests.single['path'], '/orders/9/cancel');
      expect(session.requests.single['body'], {
        'lock_version': 2,
        'reason': 'Tidak jadi',
      });
      expect(state.lines, isNotEmpty);
    },
  );
  test('cart bounds enforce 20 units and 20 unique products', () async {
    final state = ShoppingState(
      session: CommerceSession(),
      store: MemoryPending(),
    );
    await state.restore();
    for (var i = 0; i < 20; i++) {
      expect(state.add(product('1')), isNull);
    }
    expect(state.add(product('1')), isNotNull);
    for (var i = 2; i <= 20; i++) {
      expect(state.add(product('$i')), isNull);
    }
    expect(state.add(product('21')), isNotNull);
    expect(state.lines.length, 20);
  });
}
