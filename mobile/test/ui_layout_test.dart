import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/auth_page.dart';
import 'package:shipx/catalog_page.dart';
import 'package:shipx/core/app_theme.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/commerce/orders_page.dart';
import 'package:shipx/commerce/cart_page.dart';
import 'package:shipx/commerce/shopping_state.dart';
import 'package:shipx/delivery/delivery_page.dart';
import 'package:shipx/delivery/address_form.dart';

import 'catalog_test.dart' show CatalogSession, item;
import 'courier_trips_test.dart' show TripSession, trip;
import 'delivery_test.dart' show DeliverySession, depot;
import 'shopping_test.dart' show MemoryPending;
import 'order_status_test.dart' show StatusSession;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      loader.addFont(
        rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'),
      );
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(820, 1180),
  ]) {
    testWidgets('real font and primary screens fit ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      final scale = size.width == 320 ? 1.5 : 1.0;
      Future<void> mount(Widget screen) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final error = tester.takeException();
        if (error != null) {
          fail(error is FlutterError ? error.toStringDeep() : error.toString());
        }
      }

      Future<void> snapshot(String name) async {
        if (!const bool.fromEnvironment('SHIPX_UI_SCREENSHOTS')) return;
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/ui-preview/$name-${size.width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await mount(AuthPage(session: AuthSession()));
      await snapshot('login');
      await tester.ensureVisible(find.text('Masuk').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masuk').last);
      await tester.pumpAndSettle();
      expect(find.text('Email wajib diisi.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      const name = 'Air mineral kemasan untuk kebutuhan sehari-hari';
      final catalog = CatalogSession(
        (query, page) async => {
          'data': [
            item(name)..addAll({'available_quantity': 12}),
            item('Sabun cuci')
              ..addAll({'available_quantity': 8, 'category': 'Kebersihan'}),
            item('Roti gandum')..addAll({
              'available_quantity': 6,
              'category': 'Makanan',
              'unit_label': 'bungkus',
            }),
            item('Paket kebutuhan rumah')..addAll({
              'available_quantity': 4,
              'category': 'Kebutuhan rumah',
              'unit_label': 'pak',
            }),
            item('Sabun mandi')..addAll({
              'available_quantity': 10,
              'category': 'Perawatan diri',
              'unit_label': 'batang',
            }),
          ],
          'depot': {'name': 'Depot ShipX'},
          'meta': {'current_page': 1, 'last_page': 1},
        },
      );
      await mount(
        Scaffold(
          appBar: AppBar(title: const Text('ShipX')),
          body: CatalogPage(session: catalog),
        ),
      );
      await snapshot('catalog');
      await tester.scrollUntilVisible(
        find.text(name),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('catalog-products')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await snapshot('product');

      // A new navigator removes the open product sheet before showing courier UI.
      await tester.pumpWidget(const SizedBox.shrink());
      final courier = _LongTripSession();
      await mount(RoleHome(session: courier));
      await snapshot('courier');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final customer = _CustomerSession();
      await mount(
        RoleHome(
          session: customer,
          pendingStoreFactory: (_) => MemoryPending(),
        ),
      );
      await snapshot('customer');
      await tester.tap(find.byTooltip('Tambah Air mineral kemasan'));
      await tester.pumpAndSettle();
      expect(find.text('Lihat keranjang (1 barang)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await snapshot('customer-cart');
      for (final label in ['Pengiriman', 'Keranjang', 'Akun']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        await snapshot(label.toLowerCase());
        final error = tester.takeException();
        if (error != null) {
          fail(
            '$label: ${error is FlutterError ? error.toStringDeep() : error.toString()}',
          );
        }
        if (label == 'Pengiriman') {
          final scroll = find
              .descendant(
                of: find.byType(DeliveryPage),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text('Pilih alamat'),
            180,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Pilih alamat'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('12:00\u201314:00'),
            180,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('12:00\u201314:00'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Lanjut ke keranjang'),
            180,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();
          await snapshot('pengiriman-selected');
          await tester.tap(find.text('Lanjut ke keranjang'));
          await tester.pumpAndSettle();
          expect(find.text('Keranjang kamu'), findsOneWidget);
        }
        if (label == 'Keranjang') {
          final scroll = find
              .descendant(
                of: find.byType(CartPage),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text('Hitung total terbaru'),
            180,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Hitung total terbaru'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Lanjut buat pesanan COD'),
            180,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();
          await snapshot('checkout');
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Lanjut buat pesanan COD'));
          await tester.pumpAndSettle();
          expect(find.text('Buat pesanan COD?'), findsOneWidget);
          await snapshot('checkout-confirm');
          await tester.tap(find.text('Kembali'));
          await tester.pumpAndSettle();
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      catalog.dispose();
      courier.dispose();
      customer.dispose();

      final status = _LayoutOrderSession()..status = 'confirmed';
      final orderShopping = ShoppingState(
        session: status,
        store: MemoryPending(),
      );
      await orderShopping.restore();
      await mount(OrdersPage(session: status, shopping: orderShopping));
      await snapshot('orders');
      await tester.tap(find.text(status.snapshot()['order_number']));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await snapshot('order-detail');
      await tester.scrollUntilVisible(find.text('Total COD Rp48.000'), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await snapshot('order-payment');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await mount(AddressFormPage(session: status, depot: depot()));
      await snapshot('address-form');
      await tester.ensureVisible(find.text('Simpan alamat'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await snapshot('address-location');
      await tester.pumpWidget(const SizedBox.shrink());
      orderShopping.dispose();
      status.dispose();
    });
  }
}

class _LongTripSession extends TripSession {
  _LongTripSession() {
    user = const ShipXUser('9', 'Kurir ShipX', 'kurir@example.test', 'courier');
  }
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async => {
    'data': [
      trip()..addAll({
        'status': 'awaiting_reconciliation',
        'vehicle': {
          'plate_number': 'B1234SHP',
          'name': 'Kendaraan pengiriman depot utama',
        },
      }),
    ],
  };
}

class _CustomerSession extends CatalogSession {
  _CustomerSession()
    : super(
        (q, p) async => {
          'data': [
            item('Air mineral kemasan')
              ..addAll({'id': '1', 'available_quantity': 12}),
            item('Sabun cuci')..addAll({
              'id': '2',
              'available_quantity': 8,
              'category': 'Kebersihan',
            }),
            item('Roti gandum')..addAll({
              'id': '3',
              'available_quantity': 6,
              'category': 'Makanan',
              'unit_label': 'bungkus',
            }),
            item('Paket kebutuhan rumah')..addAll({
              'id': '4',
              'available_quantity': 4,
              'category': 'Kebutuhan rumah',
              'unit_label': 'pak',
            }),
            item('Sabun mandi')..addAll({
              'id': '5',
              'available_quantity': 10,
              'category': 'Perawatan diri',
              'unit_label': 'batang',
            }),
          ],
          'depot': {'name': 'Depot ShipX'},
          'meta': {'current_page': 1, 'last_page': 1},
        },
      ) {
    user = const ShipXUser(
      '8',
      'Pelanggan ShipX',
      'pelanggan@example.test',
      'customer',
    );
  }
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    if (path != '/order-quotes') {
      throw StateError('Unexpected mutation in UI preview');
    }
    return {
      'items': [
        {'quantity': 1, 'name': 'Air mineral kemasan', 'line_total_rp': 15000},
      ],
      'subtotal_rp': 15000,
      'delivery_fee_rp': 3000,
      'total_rp': 18000,
      'total_weight_g': 630,
      'total_volume_cm3': 819,
      'stock_available_now': true,
    };
  }

  final delivery = DeliverySession();
  @override
  Future<Map<String, dynamic>> deliveryRequest(
    String method,
    String path, {
    Map<String, String>? body,
    bool envelope = false,
  }) => delivery.deliveryRequest(method, path, body: body, envelope: envelope);
}

class _LayoutOrderSession extends StatusSession {
  @override
  Map<String, dynamic> snapshot() => {
    ...super.snapshot(),
    'order_number': 'SX-20261107-01JCP7Y8Z9ABCDEFGH1234567890',
    'address': {
      'recipient_name': 'Penerima dengan nama lengkap yang cukup panjang',
      'phone': '081234567890',
      'address_text':
          'Jalan pengantaran nomor 24, rumah dengan pagar hijau di sebelah toko.',
    },
    'items': [
      {
        'quantity': 3,
        'unit_label': 'botol',
        'name': 'Air mineral kemasan',
        'line_total_rp': 45000,
      },
    ],
    'total_rp': 48000,
  };
}
