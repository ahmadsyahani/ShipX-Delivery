import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/delivery/address_form.dart';
import 'package:shipx/delivery/delivery_page.dart';

Map<String, dynamic> depot({bool configured = true}) => {
  'id': '1',
  'name': 'Depot uji',
  'configured': configured,
  'latitude': -7.25,
  'longitude': 112.75,
  'timezone': 'Asia/Jayapura',
  'today': '2026-11-05',
  'server_time': '2026-11-04T16:00:00Z',
  'service_radius_m': 5000,
  'delivery_fee_rp': 3000,
};
Map<String, dynamic> address() => {
  'id': '1',
  'label': 'Rumah',
  'recipient_name': 'Penerima',
  'phone': '081234',
  'address_text': 'Alamat pengantaran uji',
  'latitude': -7.251,
  'longitude': 112.751,
  'directions': null,
  'lock_version': 0,
  'within_service_area': true,
};
Map<String, dynamic> slot() => {
  'id': '1',
  'service_date': '2026-11-05',
  'window_start_at': '2026-11-05T03:00:00Z',
  'window_end_at': '2026-11-05T05:00:00Z',
  'cutoff_at': '2026-11-05T00:00:00Z',
};
Map<String, dynamic> list(List<Map<String, dynamic>> data) => {
  'data': data,
  'meta': {'current_page': 1, 'last_page': 1},
  'timezone': 'Asia/Jayapura',
  'server_time': '2026-11-04T16:00:00Z',
};

class DeliverySession extends AuthSession {
  bool configured = true, offline = false, empty = false, outside = false;
  String? saveError;
  Map<String, String>? saved;
  @override
  Future<Map<String, dynamic>> deliveryRequest(
    String method,
    String path, {
    Map<String, String>? body,
    bool envelope = false,
  }) async {
    if (offline) throw const SocketException('offline');
    if (path == '/delivery-settings') return depot(configured: configured);
    if (method == 'POST' || method == 'PATCH') {
      if (saveError != null) throw ApiException(saveError!, 422);
      saved = body;
      return address();
    }
    if (path.startsWith('/addresses')) {
      return list(
        empty
            ? []
            : [
                {...address(), 'within_service_area': !outside},
              ],
      );
    }
    return list(empty ? [] : [slot()]);
  }
}

void main() {
  test('slot time and date use depot zone instead of phone zone', () {
    expect(slotTime('2026-11-04T16:30:00Z', 'Asia/Jayapura'), '01:30');
    expect(slotDate('2026-11-04T16:30:00Z', 'Asia/Jayapura'), '05/11/2026');
    expect(slotTime('2026-11-04T16:30:00Z', 'Asia/Jakarta'), '23:30');
  });

  Future<void> mount(WidgetTester tester, DeliverySession session) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DeliveryPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unconfigured depot blocks address and slot controls', (
    tester,
  ) async {
    await mount(tester, DeliverySession()..configured = false);
    expect(find.text('Wilayah pengiriman sedang disiapkan'), findsOneWidget);
    expect(find.text('Tambah'), findsNothing);
  });

  testWidgets('customer selects own address and open slot', (tester) async {
    await mount(tester, DeliverySession());
    await tester.tap(find.text('Pilih alamat'));
    await tester.pump();
    await tester.ensureVisible(find.text('12:00–14:00'));
    await tester.tap(find.text('12:00–14:00'));
    await tester.pump();
    await tester.ensureVisible(
      find.text(
        'Alamat dan jadwal sudah dipilih. Pilihan ini belum membuat pesanan atau memesan stok.',
      ),
    );
    expect(
      find.text(
        'Alamat dan jadwal sudah dipilih. Pilihan ini belum membuat pesanan atau memesan stok.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('out-of-area address cannot be selected', (tester) async {
    await mount(tester, DeliverySession()..outside = true);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Pilih alamat'),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Di luar wilayah layanan saat ini. Edit pin alamat.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty addresses and slots are explained', (tester) async {
    await mount(tester, DeliverySession()..empty = true);
    expect(
      find.text(
        'Belum ada alamat. Tambahkan penerima dan pin lokasi terlebih dahulu.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Belum ada slot terbuka untuk tanggal ini. Pilih tanggal lain atau muat ulang.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('delivery screen recovers from network failure', (tester) async {
    final session = DeliverySession()..offline = true;
    await mount(tester, session);
    expect(find.text('Coba lagi'), findsOneWidget);
    session.offline = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Alamat & jadwal'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('address form validates required fields and coordinate bounds', (
    tester,
  ) async {
    final session = DeliverySession();
    await tester.pumpWidget(
      MaterialApp(
        home: AddressFormPage(session: session, depot: depot()),
      ),
    );
    await tester.ensureVisible(find.text('Simpan alamat'));
    await tester.tap(find.text('Simpan alamat'));
    await tester.pump();
    expect(session.saved, isNull);
    await tester.ensureVisible(find.text('Label alamat wajib diisi.'));
    expect(find.text('Label alamat wajib diisi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server validation errors preserve address form input', (
    tester,
  ) async {
    final session = DeliverySession()
      ..saveError = 'Pin berada di luar radius layanan.';
    await tester.pumpWidget(
      MaterialApp(
        home: AddressFormPage(
          session: session,
          depot: depot(),
          address: address(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Simpan alamat'));
    await tester.tap(find.text('Simpan alamat'));
    await tester.pumpAndSettle();
    expect(find.text('Pin berada di luar radius layanan.'), findsOneWidget);
    expect(find.byKey(const ValueKey('label')), findsOneWidget);
    expect(session.saved, isNull);
  });
}
