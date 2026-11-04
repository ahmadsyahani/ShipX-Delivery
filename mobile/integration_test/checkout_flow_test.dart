import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shipx/main.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/commerce/shopping_state.dart';
import 'package:shipx/commerce/cart_page.dart';
import 'package:shipx/commerce/orders_page.dart';
import 'package:shipx/delivery/delivery_page.dart';

class TestTokens implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class TestPending implements PendingStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String input) async {
    value = input;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated MySQL checkout: catalog, address, slot, quote, order and cancel',
    (tester) async {
      const base = 'http://127.0.0.1:8001/api/v1';
      final session = AuthSession(
        api: AuthApi(baseUrl: base),
        store: TestTokens(),
      );
      await session.authenticate({
        'name': 'QA Customer',
        'email': 'ui-${DateTime.now().microsecondsSinceEpoch}@example.test',
        'phone': '080000000000',
        'password': 'ShipX-UI-test-2026!',
        'password_confirmation': 'ShipX-UI-test-2026!',
      }, register: true);
      final pending = TestPending();
      await tester.pumpWidget(
        ShipXApp(session: session, pendingStoreFactory: (_) => pending),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      Future<void> add(String name) async {
        await tester.ensureVisible(find.text(name));
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Tambah ke keranjang'));
        await tester.tap(find.text('Tambah ke keranjang'));
        await tester.pumpAndSettle();
      }

      await add('QA Air');
      await add('QA Air');
      await add('QA Sabun');
      await tester.tap(find.text('Pengiriman'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();
      for (final entry in {
        'label': 'Rumah QA',
        'recipient_name': 'QA Receiver',
        'phone': '080000000000',
        'address_text': 'Alamat uji dalam radius',
      }.entries) {
        final f = find.byKey(ValueKey(entry.key));
        await tester.ensureVisible(f);
        await tester.enterText(f, entry.value);
      }
      await tester.enterText(find.byType(TextFormField).at(4), '-7.25');
      await tester.enterText(find.byType(TextFormField).at(5), '112.75');
      await tester.ensureVisible(find.text('Simpan alamat'));
      await tester.tap(find.text('Simpan alamat'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Pilih alamat'));
      await tester.pumpAndSettle();
      final settings = await session.commerceRequest(
        'GET',
        '/delivery-settings',
      );
      final slots = await session.commerceRequest(
        'GET',
        '/delivery-slots?date=${settings['today']}',
        envelope: true,
      );
      expect(slots['data'], isNotEmpty);
      final slot = slots['data'][0];
      final time =
          '${slotTime(slot['window_start_at'], settings['timezone'])}–${slotTime(slot['window_end_at'], settings['timezone'])}';
      await tester.ensureVisible(find.text(time));
      await tester.tap(find.text(time));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Keranjang'),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(CartPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Hitung total terbaru'),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Hitung total terbaru'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.scrollUntilVisible(
        find.text('Lanjut buat pesanan COD'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Total COD Rp45.000'), findsOneWidget);
      await tester.tap(find.text('Lanjut buat pesanan COD'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Buat pesanan'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(pending.value, isNull);
      final orders = await session.commerceRequest(
        'GET',
        '/orders',
        envelope: true,
      );
      expect(orders['data'], hasLength(1));
      final order = orders['data'][0];
      expect(order['total_rp'], 45000);
      expect(order['status'], 'pending');
      await tester.ensureVisible(find.text('Lihat pesanan saya'));
      await tester.tap(find.text('Lihat pesanan saya'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text(order['order_number']));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.scrollUntilVisible(
        find.text('Batalkan pesanan'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(OrderDetailPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Batalkan pesanan'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Uji pembatalan',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Batalkan pesanan'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final cancelled = await session.commerceRequest(
        'GET',
        '/orders/${order['id']}',
      );
      expect(cancelled['status'], 'cancelled');
      final catalog = await session.commerceRequest(
        'GET',
        '/catalog',
        envelope: true,
      );
      for (final p in catalog['data']) {
        expect(p['available_quantity'], 5);
      }
      await session.logout();
      await tester.pumpAndSettle();
      expect(find.text('Masuk ShipX'), findsOneWidget);
    },
  );
}
