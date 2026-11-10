import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/commerce/cart_page.dart';
import 'package:shipx/commerce/shopping_state.dart';
import 'shopping_test.dart' show CommerceSession, MemoryPending, product;

class CartSession extends CommerceSession {
  bool stockAvailable = true;
  int unitPrice = 15000;
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    if (path == '/order-quotes') {
      return {
        'items': [
          {
            'product_id': '1',
            'unit_price_rp': unitPrice,
            'quantity': 1,
            'name': 'Barang 1',
            'line_total_rp': unitPrice,
          },
        ],
        'subtotal_rp': unitPrice,
        'delivery_fee_rp': 3000,
        'total_rp': unitPrice + 3000,
        'total_weight_g': 1000,
        'total_volume_cm3': 1000,
        'stock_available_now': stockAvailable,
      };
    }
    return super.commerceRequest(
      method,
      path,
      body: body,
      key: key,
      envelope: envelope,
    );
  }
}

void main() {
  Future<ShoppingState> showCart(
    WidgetTester tester,
    CartSession session,
  ) async {
    final store = MemoryPending();
    session.persistence = store;
    final state = ShoppingState(session: session, store: store);
    await state.restore();
    state.add(product('1'));
    state.chooseAddress({
      'id': '1',
      'label': 'Rumah',
      'address_text': 'Alamat',
    });
    state.chooseSlot({
      'id': '2',
      'timezone': 'Asia/Jakarta',
      'window_start_at': '2026-11-05T03:00:00Z',
      'window_end_at': '2026-11-05T05:00:00Z',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartPage(
            session: session,
            shopping: state,
            chooseDelivery: () {},
            browse: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Hitung total'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hitung total'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Total COD'), 200);
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets(
    'server quote requires confirmation and successful checkout clears cart',
    (tester) async {
      final session = CartSession();
      final state = await showCart(tester, session);
      expect(session.requests, isEmpty);
      expect(find.text('Total COD Rp18.000'), findsOneWidget);
      await tester.tap(find.text('Pesan sekarang'));
      await tester.pumpAndSettle();
      expect(session.requests, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Buat pesanan'));
      await tester.pumpAndSettle();
      expect(state.lines, isEmpty);
      expect(state.pending, isNull);
      expect(session.requests.single['body']['expected_total_rp'], 18000);
      expect(find.text('Pesanan berhasil dibuat.'), findsOneWidget);
    },
  );

  testWidgets('changed cart during confirmation prevents stale checkout', (
    tester,
  ) async {
    final session = CartSession();
    final state = await showCart(tester, session);
    await tester.tap(find.text('Pesan sekarang'));
    await tester.pumpAndSettle();
    state.quantity('1', 2);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat pesanan'));
    await tester.pumpAndSettle();
    expect(session.requests, isEmpty);
    expect(state.count, 2);
    expect(
      find.text(
        'Isi keranjang atau jadwal berubah. Hitung ulang total sebelum memesan.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('insufficient server stock disables order confirmation', (
    tester,
  ) async {
    final session = CartSession()..stockAvailable = false;
    await showCart(tester, session);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Pesan sekarang'),
    );
    expect(button.onPressed, isNull);
    expect(session.requests, isEmpty);
  });
  testWidgets(
    'server price replaces catalog estimate while checkout dock stays visible',
    (tester) async {
      final session = CartSession()..unitPrice = 17000;
      final state = await showCart(tester, session);
      expect(find.text('Total COD Rp20.000'), findsOneWidget);
      expect(find.text('Pesan sekarang').hitTestable(), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('cart-content')),
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pesan sekarang').hitTestable(), findsOneWidget);
      expect(find.text('Rp17.000'), findsOneWidget);
      expect(session.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
