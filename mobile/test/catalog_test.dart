import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/catalog_page.dart';
import 'package:shipx/core/auth_session.dart';

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
  Future<Map<String, dynamic>> catalog({String query = '', int page = 1}) =>
      handler(query, page);
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
    expect(find.text('Berat kemasan: 630 gram'), findsOneWidget);
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
}
