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
    String collection = 'all',
    bool grouped = false,
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
    String collection = 'all',
    bool grouped = false,
    int page = 1,
  }) {
    requests.add((query: query, category: category, page: page));
    return handler(query, category, page);
  }
}

class PersonalCatalogSession extends AuthSession {
  final favorites = <String>{};
  final collections = <String>[];
  bool failSave = false;

  @override
  Future<Map<String, dynamic>> catalog({
    String query = '',
    String? category,
    String collection = 'all',
    bool grouped = false,
    int page = 1,
  }) async {
    collections.add(collection);
    final products = [
      item('Air mineral')
        ..addAll({'available_quantity': 3, 'customer_order_count': 2}),
      item('Sabun')
        ..addAll({'available_quantity': 3, 'customer_order_count': 0}),
    ];
    for (final product in products) {
      product['is_favorite'] = favorites.contains(product['id']);
    }
    return {
      'depot': {'name': 'Depot utama'},
      'meta': {'current_page': 1, 'last_page': 1},
      'data': products
          .where(
            (product) => collection == 'favorites'
                ? product['is_favorite'] == true
                : collection == 'frequent'
                ? product['customer_order_count'] as int > 0
                : true,
          )
          .toList(),
      'categories': ['Minuman'],
    };
  }

  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    if (failSave) throw const HttpException('Offline');
    final id = path.split('/')[2];
    if (body!['is_favorite'] == true) {
      favorites.add(id);
    } else {
      favorites.remove(id);
    }
    return {
      'data': {'product_id': id, 'is_favorite': favorites.contains(id)},
    };
  }
}

class RankedCatalogSession extends AuthSession {
  bool? lastGrouped;
  String? lastCollection;
  @override
  Future<Map<String, dynamic>> catalog({
    String query = '',
    String? category,
    String collection = 'all',
    bool grouped = false,
    int page = 1,
  }) async {
    lastGrouped = grouped;
    lastCollection = collection;
    return {
      'meta': {'current_page': 1, 'last_page': 1},
      'depot': {'name': 'Depot utama'},
      'categories': ['A', 'Z'],
      'data': [
        item('Teratas')..addAll({'category': 'Z', 'customer_order_count': 8}),
        item('Kedua')..addAll({'category': 'A', 'customer_order_count': 4}),
        item('Ketiga')..addAll({'category': 'Z', 'customer_order_count': 2}),
      ],
    };
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

  testWidgets('star directly opens frequent products in global order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = RankedCatalogSession();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Paling sering dipesan'));
    await tester.pumpAndSettle();
    expect(session.lastCollection, 'frequent');
    expect(session.lastGrouped, false);
    expect(find.text('Paling sering dipesan'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Teratas')).dy,
      tester.getTopLeft(find.text('Kedua')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Ketiga')).dy,
      greaterThan(tester.getTopLeft(find.text('Kedua')).dy),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('category-all')));
    await tester.tap(find.byKey(const ValueKey('category-all')));
    await tester.pumpAndSettle();
    expect(session.lastCollection, 'all');
    expect(session.lastGrouped, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'favorites survive reopening and collection filters reach the session',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = PersonalCatalogSession();
      Widget screen() => MaterialApp(
        home: Scaffold(body: CatalogPage(session: session)),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favoritkan Air mineral'));
      await tester.pumpAndSettle();
      expect(session.favorites, {'Air mineral'});
      expect(find.byTooltip('Hapus Air mineral dari favorit'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('catalog-collection-favorites')),
      );
      await tester.pumpAndSettle();
      expect(session.collections.last, 'favorites');
      expect(find.text('Air mineral'), findsOneWidget);
      expect(find.text('Sabun'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hapus Air mineral dari favorit'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('catalog-collection-frequent')),
      );
      await tester.pumpAndSettle();
      expect(session.collections.last, 'frequent');
      expect(find.text('Sabun'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('catalog-collection-favorites')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus Air mineral dari favorit'));
      await tester.pumpAndSettle();
      expect(session.favorites, isEmpty);
      expect(find.text('Belum ada barang favorit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed favorite save retains previous state and can be retried',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = PersonalCatalogSession()..failSave = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CatalogPage(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favoritkan Air mineral'));
      await tester.pumpAndSettle();
      expect(session.favorites, isEmpty);
      expect(
        find.text('Favorit belum dapat disimpan. Coba lagi.'),
        findsOneWidget,
      );
      session.failSave = false;
      await tester.tap(find.byTooltip('Favoritkan Air mineral'));
      await tester.pumpAndSettle();
      expect(session.favorites, {'Air mineral'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog shows prices and opens product details', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, CatalogSession((q, p) async => page([])));
    expect(find.text('Katalog sedang disiapkan'), findsOneWidget);
    await tester.tap(find.byTooltip('Cari barang'));
    await tester.pumpAndSettle();
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
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<Map<String, dynamic>>();
    await mount(
      tester,
      CatalogSession(
        (q, p) => q == 'lama'
            ? pending.future
            : Future.value(page([q.isEmpty ? 'Awal' : 'Terbaru'])),
      ),
    );
    await tester.tap(find.byTooltip('Cari barang'));
    await tester.pumpAndSettle();
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

  testWidgets('short catalog pages automatically load subsequent products', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(
      tester,
      CatalogSession(
        (q, p) async =>
            page([p == 1 ? 'Pertama' : 'Kedua'], current: p, last: 2),
      ),
    );
    expect(find.text('Pertama'), findsOneWidget);
    expect(find.text('Kedua'), findsOneWidget);
    expect(find.text('Muat produk lainnya'), findsNothing);
  });

  testWidgets('long product names fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

  testWidgets('category pills jump across pages and track vertical scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = MenuSession(
      (q, category, p) async => {
        ...page([], current: p, last: 2),
        'data': p == 1
            ? List.generate(
                8,
                (i) => item('Makanan $i')..['category'] = 'Makanan',
              )
            : List.generate(
                4,
                (i) => item('Minuman $i')..['category'] = 'Minuman',
              ),
        'categories': ['Makanan', 'Minuman'],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-Minuman')));
    await tester.tap(find.byKey(const ValueKey('category-Minuman')));
    await tester.pumpAndSettle();
    expect(session.requests.last.page, 2);
    expect(session.requests.last.category, isNull);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('category-Minuman')))
          .selected,
      isTrue,
    );
    final products = find
        .descendant(
          of: find.byKey(const ValueKey('catalog-products')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(products).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('category-all')))
          .selected,
      isTrue,
    );
    final section = find.descendant(
      of: find.byKey(const ValueKey('catalog-products')),
      matching: find.byKey(const ValueKey('section-heading-Minuman')),
    );
    await tester.ensureVisible(section);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('category-Minuman')))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search cancels a pending jump to an unloaded category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final old = Completer<Map<String, dynamic>>();
    final session = MenuSession((q, category, p) {
      if (q.isNotEmpty) {
        return Future.value({
          ...page(['Terbaru']),
          'categories': ['Minuman'],
        });
      }
      if (p == 2) return old.future;
      return Future.value({
        ...page([], last: 2),
        'data': List.generate(
          8,
          (i) => item('Makanan $i')..['category'] = 'Makanan',
        ),
        'categories': ['Makanan', 'Minuman'],
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-Minuman')));
    await tester.tap(find.byKey(const ValueKey('category-Minuman')));
    await tester.pump();
    await tester.tap(find.byTooltip('Cari barang'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'baru');
    await tester.pumpAndSettle();
    old.complete({
      ...page(['Respons lama'], current: 2, last: 2),
      'categories': ['Minuman'],
    });
    await tester.pumpAndSettle();
    expect(find.text('Terbaru'), findsOneWidget);
    expect(find.text('Respons lama'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrolling reveals the selected pill beyond the horizontal viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final categories = List.generate(12, (i) => 'Kategori $i');
      final session = MenuSession(
        (q, category, p) async => {
          ...page([]),
          'categories': categories,
          'data': categories
              .map((c) => item('Barang $c')..['category'] = c)
              .toList(),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CatalogPage(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      final section = find.descendant(
        of: find.byKey(const ValueKey('catalog-products')),
        matching: find.byKey(const ValueKey('section-heading-Kategori 10')),
      );
      await tester.ensureVisible(section);
      await tester.pumpAndSettle();
      final pill = find.byKey(const ValueKey('category-Kategori 10'));
      expect(tester.widget<ChoiceChip>(pill).selected, isTrue);
      expect(pill.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick add updates cart and respects sold-out and pending-request locks',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      final quantityLabel = find.byKey(
        const ValueKey('catalog-quantity-Air mineral'),
      );
      expect(tester.widget<Text>(quantityLabel).data, '1');
      await tester.tap(find.byTooltip('Tambah Air mineral'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(quantityLabel).data, '2');
      expect(shopping.count, 2);
      await tester.tap(find.byTooltip('Kurangi Air mineral'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(quantityLabel).data, '1');
      await tester.tap(find.byTooltip('Kurangi Air mineral'));
      await tester.pumpAndSettle();
      expect(shopping.count, 0);
      expect(find.byTooltip('Kurangi Air mineral'), findsNothing);
      expect(find.byKey(const ValueKey('catalog-checkout')), findsNothing);
      await tester.tap(find.byTooltip('Tambah Air mineral'));
      await tester.pumpAndSettle();
      shopping.quantity('Air mineral', 20);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(
                    of: find.byTooltip('Tambah Air mineral'),
                    matching: find.byType(IconButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Kurangi Air mineral'));
      await tester.pumpAndSettle();
      expect(shopping.count, 19);
      shopping.quantity('Air mineral', 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('catalog-checkout')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('catalog-checkout'))).height,
        lessThanOrEqualTo(48),
      );
      final productsScroll = find
          .descendant(
            of: find.byKey(const ValueKey('catalog-products')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byTooltip('Tambah Stok kosong'),
        150,
        scrollable: productsScroll,
      );
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(
                    of: find.byTooltip('Tambah Stok kosong'),
                    matching: find.byType(IconButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Tambah Air mineral'),
        -150,
        scrollable: productsScroll,
      );
      shopping.pending = {'pending': true};
      shopping.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(
                    of: find.byTooltip('Tambah Air mineral'),
                    matching: find.byType(IconButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(
                    of: find.byTooltip('Kurangi Air mineral'),
                    matching: find.byType(IconButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('catalog-checkout')));
      expect(opened, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      shopping.dispose();
      session.dispose();
    },
  );
}
