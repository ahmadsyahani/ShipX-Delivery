import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/commerce/orders_page.dart';
import 'package:shipx/commerce/shopping_state.dart';
import 'package:shipx/core/auth_session.dart';
import 'shopping_test.dart' show MemoryPending;

class StatusSession extends AuthSession {
  String status = 'pending';
  bool offline = false;
  int reads = 0;
  int lastPage = 1;
  Map<String, dynamic> snapshot() => {
    'id': '1',
    'order_number': 'SX-STATUS-QA',
    'status': status,
    'lock_version': status == 'pending' ? 0 : 1,
    'address': {
      'recipient_name': 'Penerima',
      'phone': '080000',
      'address_text': 'Alamat QA',
    },
    'timezone': 'Asia/Jakarta',
    'window_start_at': '2026-11-05T03:00:00Z',
    'window_end_at': '2026-11-05T05:00:00Z',
    'pending_expires_at': '2026-11-04T02:00:00Z',
    'confirmed_at': status == 'confirmed' ? '2026-11-04T01:00:00Z' : null,
    'status_reason': status == 'rejected'
        ? 'Jadwal tidak dapat dilayani'
        : null,
    'items': [],
    'delivery_fee_rp': 3000,
    'total_rp': 18000,
  };
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    reads++;
    if (offline) throw Exception('offline');
    return path.startsWith('/orders?')
        ? {
            'data': [
              {
                ...snapshot(),
                if (path.contains('page=2')) 'order_number': 'SX-SECOND-QA',
              },
            ],
            'meta': {
              'current_page': path.contains('page=2') ? 2 : 1,
              'last_page': lastPage,
            },
          }
        : snapshot();
  }
}

void main() {
  Future<ShoppingState> show(
    WidgetTester tester,
    StatusSession session, {
    bool list = false,
  }) async {
    final shopping = ShoppingState(session: session, store: MemoryPending());
    await shopping.restore();
    await tester.pumpWidget(
      MaterialApp(
        home: list
            ? OrdersPage(session: session, shopping: shopping)
            : OrderDetailPage(session: session, shopping: shopping, id: '1'),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      shopping.dispose();
    });
    return shopping;
  }

  testWidgets('automatic refresh does not discard pages the customer loaded', (
    tester,
  ) async {
    final session = StatusSession()..lastPage = 2;
    await show(tester, session, list: true);
    await tester.tap(find.text('Muat pesanan lainnya'));
    await tester.pumpAndSettle();
    expect(find.text('SX-SECOND-QA'), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('SX-STATUS-QA'), findsOneWidget);
    expect(find.text('SX-SECOND-QA'), findsOneWidget);
    expect(session.reads, 2);
  });

  testWidgets(
    'open detail refreshes pending to confirmed and preserves cancellation',
    (tester) async {
      final session = StatusSession();
      await show(tester, session);
      expect(find.text('Menunggu konfirmasi'), findsOneWidget);
      session.status = 'confirmed';
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Dikonfirmasi'), findsOneWidget);
      expect(find.textContaining('Dikonfirmasi 04/11/2026'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Batalkan pesanan'), 200);
      expect(find.text('Batalkan pesanan'), findsOneWidget);
      expect(session.reads, 2);
    },
  );

  testWidgets('rejected reason is visible and cancellation is unavailable', (
    tester,
  ) async {
    final session = StatusSession();
    await show(tester, session);
    session.status = 'rejected';
    await tester.tap(find.byTooltip('Perbarui status'));
    await tester.pumpAndSettle();
    expect(find.text('Ditolak'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Alasan penolakan: Jadwal tidak dapat dilayani'),
      200,
    );
    expect(
      find.text('Alasan penolakan: Jadwal tidak dapat dilayani'),
      findsOneWidget,
    );
    expect(find.text('Batalkan pesanan'), findsNothing);
    final count = session.reads;
    await tester.pump(const Duration(seconds: 30));
    expect(
      session.reads,
      count,
      reason: 'Terminal order does not need polling.',
    );
  });

  testWidgets('list refreshes status and keeps known orders when offline', (
    tester,
  ) async {
    final session = StatusSession();
    await show(tester, session, list: true);
    session.status = 'rejected';
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ditolak'), findsOneWidget);
    session.offline = true;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('SX-STATUS-QA'), findsOneWidget);
    expect(find.textContaining('Periksa koneksi'), findsOneWidget);
  });

  testWidgets(
    'polling pauses behind another route and while app is backgrounded',
    (tester) async {
      final session = StatusSession();
      await show(tester, session);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Halaman lain')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      expect(session.reads, 1);
      navigator.pop();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 15));
      expect(session.reads, 1);
      session.status = 'confirmed';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Dikonfirmasi'), findsOneWidget);
      expect(session.reads, 2);
    },
  );
}
