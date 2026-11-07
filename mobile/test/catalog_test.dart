import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/catalog_page.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/commerce/shopping_state.dart';
import 'shopping_test.dart' show MemoryPending;

Map<String, dynamic> item(String name) => {
  'id': name,
  'sku': 'TEST',
  'name': name,
  'category': 'Minuman',
  'unit_label': 'botol',
  'unit_price_rp': 15000,
  'shipping_weight_g': 630,
  'shipping_volume_cm3': 819,
  'length_mm': 61,
  'width_mm': 61,
  'height_mm': 220,
  'handling_notes': 'Simpan tegak.',
};
Map<String, dynamic> page(
  List<String> names, {
  int current = 1,
  int last = 1,
}) => {
  'data': names.map(item).toList(),
  'depot': {'name': 'Depot utama'},
  'meta': {'current_page': current, 'last_page': last},
};

class CatalogSession extends AuthSession {
  CatalogSession(this.handler);
  final Future<Map<String, dynamic>> Function(String, int) handler;
  @override
  Future<Map<String, dynamic>> catalog({
    String query = '',
    String? category,
    int page = 1,
  }) => handler(query, page);
}

class MenuSession extends AuthSession {
  MenuSession(this.handler);
  final Future<Map<String, dynamic>> Function(String, String?, int) handler;
  final requests = <({String query, String? category, int page})>[];
  @override
  Future<Map<String, dynamic>> catalog({
    String query = '',
    String? category,
    int page = 1,
  }) {
    requests.add((query: query, category: category, page: page));
    return handler(query, category, page);
  }
}

void main() {
  Future<void> mount(WidgetTester tester, CatalogSession session) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('catalog shows prices and opens product details', (tester) async {
    await mount(tester, CatalogSession((q, p) async => page(['Air mineral'])));
    expect(find.text('Rp15.000'), findsOneWidget);
    await tester.tap(find.text('Air mineral'));
    await tester.pumpAndSettle();
    expect(find.text('Berat kemasan: 630 gram'), findsNothing);
    expect(find.text('Rp15.000 / item'), findsOneWidget);
    expect(find.text('Simpan tegak.'), findsOneWidget);
    await tester.tap(find.text('Tutup detail'));
    await tester.pumpAndSettle();
    expect(find.text('Berat kemasan: 630 gram'), findsNothing);
  });

  testWidgets('empty and no-result states offer useful recovery', (
    tester,
  ) async {
    await mount(tester, CatalogSession((q, p) async => page([])));
    expect(find.text('Katalog sedang disiapkan'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tidak ada');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Produk tidak ditemukan'), findsOneWidget);
    await tester.ensureVisible(find.text('Lihat semua produk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat semua produk'));
    await tester.pumpAndSettle();
    expect(find.text('Katalog sedang disiapkan'), findsOneWidget);
  });

  testWidgets(
    'a failed refresh retries page one rather than skipping products',
    (tester) async {
      final requests = <int>[];
      await mount(
        tester,
        CatalogSession((q, p) async {
          requests.add(p);
          if (requests.length == 2) throw const SocketException('offline');
          return page(['Air mineral']);
        }),
      );
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Koneksi belum tersedia'), findsOneWidget);
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(requests, [1, 1, 1]);
      expect(find.text('Air mineral'), findsOneWidget);
    },
  );

  testWidgets('stale search responses cannot replace the latest query', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    await mount(
      tester,
      CatalogSession(
        (q, p) => q == 'lama'
            ? pending.future
            : Future.value(page([q.isEmpty ? 'Awal' : 'Terbaru'])),
      ),
    );
    await tester.enterText(find.byType(TextField), 'lama');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'baru');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    pending.complete(page(['Lama']));
    await tester.pumpAndSettle();
    expect(find.text('Terbaru'), findsOneWidget);
    expect(find.text('Lama'), findsNothing);
  });

  testWidgets('pagination appends subsequent products', (tester) async {
    await mount(
      tester,
      CatalogSession(
        (q, p) async =>
            page([p == 1 ? 'Pertama' : 'Kedua'], current: p, last: 2),
      ),
    );
    await tester.ensureVisible(find.text('Muat produk lainnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muat produk lainnya'));
    await tester.pumpAndSettle();
    expect(find.text('Pertama'), findsOneWidget);
    expect(find.text('Kedua'), findsOneWidget);
    expect(find.text('Muat produk lainnya'), findsNothing);
  });

  testWidgets('long product names fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = CatalogSession(
      (q, p) async =>
          page(['Produk dengan nama cukup panjang untuk ukuran layar kecil']),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(body: CatalogPage(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category selection queries the server and keeps pagination scoped',
    (tester) async {
      final session = MenuSession(
        (q, category, p) async => {
          ...page(
            [category == 'Kebersihan' ? 'Sabun $p' : 'Air mineral'],
            current: p,
            last: 2,
          ),
          'categories': ['Kebersihan', 'Minuman'],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CatalogPage(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-Kebersihan')));
      await tester.pumpAndSettle();
      expect(session.requests.last.category, 'Kebersihan');
      expect(find.text('Air mineral'), findsNothing);
      expect(find.text('Sabun 1'), findsOneWidget);
      await tester.ensureVisible(find.text('Muat produk lainnya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muat produk lainnya'));
      await tester.pumpAndSettle();
      expect(session.requests.last, (
        query: '',
        category: 'Kebersihan',
        page: 2,
      ));
      expect(find.text('Sabun 1'), findsOneWidget);
      expect(find.text('Sabun 2'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'mineral');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(session.requests.last, (
        query: 'mineral',
        category: null,
        page: 1,
      ));
    },
  );

  testWidgets('late category response cannot replace a newer category', (
    tester,
  ) async {
    final old = Completer<Map<String, dynamic>>();
    Map<String, dynamic> result(String name) => {
      ...page([name]),
      'categories': ['Minuman', 'Makanan'],
    };
    final session = MenuSession(
      (q, category, p) => category == 'Minuman'
          ? old.future
          : Future.value(result('Menu ${category ?? 'Awal'}')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-Minuman')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-Makanan')));
    await tester.pumpAndSettle();
    old.complete(result('Respons lama'));
    await tester.pumpAndSettle();
    expect(find.text('Respons lama'), findsNothing);
    expect(session.requests.last.category, 'Makanan');
    expect(find.text('Menu Makanan'), findsOneWidget);
  });

  testWidgets(
    'category rail scrolls independently to categories beyond the viewport',
    (tester) async {
      final categories = List.generate(25, (i) => 'Kategori $i');
      final session = MenuSession(
        (q, category, p) async => {
          ...page([category ?? 'Produk awal']),
          'categories': categories,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CatalogPage(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      final rail = find.descendant(
        of: find.byKey(const ValueKey('catalog-categories')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('category-Kategori 24')),
        300,
        scrollable: rail,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-Kategori 24')));
      await tester.pumpAndSettle();
      expect(session.requests.last.category, 'Kategori 24');
      final products = find.descendant(
        of: find.byKey(const ValueKey('catalog-products')),
        matching: find.byType(Scrollable),
      );
      expect(tester.state<ScrollableState>(products).position.pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick add updates cart and respects sold-out and pending-request locks',
    (tester) async {
      final session = MenuSession(
        (q, category, p) async => {
          ...page([]),
          'data': [
            item('Air mineral')..addAll({'available_quantity': 3}),
            item('Stok kosong')..addAll({'available_quantity': 0}),
          ],
          'categories': ['Minuman'],
        },
      );
      final shopping = ShoppingState(session: session, store: MemoryPending())
        ..ready = true;
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogPage(
              session: session,
              shopping: shopping,
              openCart: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tambah Air mineral'));
      await tester.pumpAndSettle();
      expect(shopping.count, 1);
      expect(find.text('Lihat keranjang (1 barang)'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.add_rounded).last,
            )
            .onPressed,
        isNull,
      );
      shopping.pending = {'pending': true};
      shopping.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.add_rounded).first,
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Lihat keranjang (1 barang)'));
      expect(opened, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      shopping.dispose();
      session.dispose();
    },
  );
}
