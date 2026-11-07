import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
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

// Exercise the real protected web actions against QA only. Cookies and CSRF
// stay in memory, separately from the customer's bearer session.
class TestAdmin {
  final client = HttpClient();
  final cookies = <String, Cookie>{};
  Future<void> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:8001$path'),
    );
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'text/html');
    request.cookies.addAll(cookies.values);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.headers.set(
        'X-XSRF-TOKEN',
        Uri.decodeComponent(cookies['XSRF-TOKEN']!.value),
      );
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    expect(response.headers.value('x-shipx-qa'), 'isolated-checkout');
    for (final cookie in response.cookies) {
      cookies[cookie.name] = cookie;
    }
    await response.drain<void>();
    expect(response.statusCode, method == 'GET' ? 200 : 302);
  }

  Future<void> login() async {
    await request('GET', '/admin/login');
    await request('POST', '/admin/login', {
      'email': 'admin-ui@example.test',
      'password': 'ShipX-QA-Admin-2026!',
    });
  }

  Future<void> decide(String id, String action, int version) =>
      request('POST', '/admin/orders/$id/$action', {
        'idempotency_key': const Uuid().v4(),
        'lock_version': version,
        if (action == 'reject') 'reason': 'Jadwal uji tidak dapat dilayani',
      });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated MySQL: checkout, admin decisions, cancel and courier login',
    (tester) async {
      const base = 'http://127.0.0.1:8001/api/v1';
      final session = AuthSession(
        api: AuthApi(baseUrl: base),
        store: TestTokens(),
      );
      Future<Map<String, dynamic>> api(
        String method,
        String path, {
        Map<String, dynamic>? body,
        String? key,
        bool envelope = false,
      }) async => (await tester.runAsync(
        () => session.commerceRequest(
          method,
          path,
          body: body,
          key: key,
          envelope: envelope,
        ),
      ))!;
      await tester.runAsync(
        () => session.authenticate({
          'name': 'QA Customer',
          'email': 'ui-${DateTime.now().microsecondsSinceEpoch}@example.test',
          'phone': '080000000000',
          'password': 'ShipX-UI-test-2026!',
          'password_confirmation': 'ShipX-UI-test-2026!',
        }, register: true),
      );
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
      await tester.ensureVisible(find.text('Pilih pin di peta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih pin di peta'));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gunakan titik ini'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Simpan alamat'));
      await tester.tap(find.text('Simpan alamat'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Pilih alamat'));
      await tester.pumpAndSettle();
      final settings = await api('GET', '/delivery-settings');
      final slots = await api(
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
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hitung total terbaru'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.scrollUntilVisible(
        find.text('Lanjut buat pesanan COD'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Total COD Rp45.000'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjut buat pesanan COD'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Buat pesanan'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(pending.value, isNull);
      final orders = await api('GET', '/orders', envelope: true);
      expect(orders['data'], hasLength(1));
      final order = orders['data'][0];
      expect(order['total_rp'], 45000);
      expect(order['status'], 'pending');
      await tester.ensureVisible(find.text('Lihat pesanan saya'));
      await tester.tap(find.text('Lihat pesanan saya'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text(order['order_number']));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final admin = TestAdmin();
      addTearDown(() => admin.client.close(force: true));
      await tester.runAsync(admin.login);
      await tester.runAsync(
        () => admin.decide(order['id'], 'confirm', order['lock_version']),
      );
      await tester.tap(find.byTooltip('Perbarui status'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Dikonfirmasi'), findsOneWidget);
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
      final cancelled = await api('GET', '/orders/${order['id']}');
      expect(cancelled['status'], 'cancelled');
      final catalog = await api('GET', '/catalog', envelope: true);
      for (final p in catalog['data']) {
        expect(p['available_quantity'], 5);
      }
      final addresses = await api('GET', '/addresses', envelope: true);
      final rejected = await api(
        'POST',
        '/orders',
        key: const Uuid().v4(),
        body: {
          'address_id': addresses['data'][0]['id'],
          'delivery_slot_id': slot['id'],
          'items': (order['items'] as List)
              .map(
                (item) => {
                  'product_id': item['product_id'],
                  'quantity': item['quantity'],
                },
              )
              .toList(),
          'expected_total_rp': 45000,
        },
      );
      expect(rejected['lock_version'], 0);
      await tester.runAsync(
        () => admin.decide(rejected['id'], 'reject', rejected['lock_version']),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text(rejected['order_number']));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Ditolak'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Alasan penolakan: Jadwal uji tidak dapat dilayani'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(OrderDetailPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.text('Alasan penolakan: Jadwal uji tidak dapat dilayani'),
        findsOneWidget,
      );
      expect(find.text('Batalkan pesanan'), findsNothing);
      final restored = await api('GET', '/catalog', envelope: true);
      for (final product in restored['data']) {
        expect(product['available_quantity'], 5);
      }
      await tester.runAsync(session.logout);
      await tester.pumpAndSettle();
      expect(find.text('Masuk ShipX'), findsOneWidget);
      await tester.runAsync(
        () => session.authenticate({
          'email': 'courier-ui@example.test',
          'password': 'ShipX-QA-Courier-2026!',
        }, register: false),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(session.user?.role, 'courier');
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      expect(find.text('Halo, QA Kurir'), findsOneWidget);
      expect(find.byType(CartPage), findsNothing);
      await tester.runAsync(session.logout);
      await tester.pumpAndSettle();
      expect(find.text('Masuk ShipX'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
