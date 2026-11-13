import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/catalog/catalog_location_header.dart';
import 'delivery_test.dart' show DeliverySession, address, depot, list;

class HeaderSession extends DeliverySession {
  bool several = false;
  @override
  Future<Map<String, dynamic>> deliveryRequest(
    String method,
    String path, {
    Map<String, String>? body,
    bool envelope = false,
  }) async {
    if (several && path.startsWith('/addresses')) {
      return list([
        address(),
        {...address(), 'id': '2'},
      ]);
    }
    return super.deliveryRequest(method, path, body: body, envelope: envelope);
  }
}

void main() {
  test('distance handles saved coordinates and missing or invalid pins', () {
    expect(catalogDistance(depot(), address()), '0,2 km');
    expect(catalogDistance(depot(), depot()), '0,0 km');
    expect(catalogDistance(null, address()), isNull);
    expect(catalogDistance(depot(), {'latitude': 91, 'longitude': 0}), isNull);
    expect(
      catalogDistance(depot(), {'latitude': 'NaN', 'longitude': 0}),
      isNull,
    );
    expect(
      catalogDistance(
        {'latitude': 0, 'longitude': 0},
        {'latitude': '0', 'longitude': '1'},
      ),
      '111,2 km',
    );
  });

  testWidgets(
    'uses saved address, updates for chosen address and opens store info',
    (tester) async {
      final session = HeaderSession();
      var chooseCount = 0;
      Widget screen([Map<String, dynamic>? chosen]) => MaterialApp(
        home: Scaffold(
          body: CatalogLocationHeader(
            session: session,
            address: chosen,
            onChooseAddress: () => chooseCount++,
          ),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('Depot uji'), findsOneWidget);
      expect(find.text('Alamat pengantaran uji'), findsOneWidget);
      expect(find.text('0,2 km · perkiraan'), findsOneWidget);
      await tester.tap(find.text('Lokasimu saat ini'));
      expect(chooseCount, 1);
      await tester.pumpWidget(
        screen({...depot(), 'address_text': 'Alamat pilihan'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alamat pilihan'), findsOneWidget);
      expect(find.text('0,0 km · perkiraan'), findsOneWidget);
      await tester.tap(find.text('Depot uji'));
      await tester.pumpAndSettle();
      expect(find.textContaining('perkiraan garis lurus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'several addresses require a choice and failed location reads can retry',
    (tester) async {
      final session = HeaderSession()..offline = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogLocationHeader(
              session: session,
              storeName: 'Toko tersimpan',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Toko tersimpan'), findsOneWidget);
      expect(find.text('Muat ulang lokasi toko'), findsOneWidget);
      session.offline = false;
      session.several = true;
      await tester.tap(find.text('Muat ulang lokasi toko'));
      await tester.pumpAndSettle();
      expect(find.text('Depot uji'), findsOneWidget);
      expect(find.text('Pilih alamat terdaftar'), findsOneWidget);
      expect(find.textContaining('km'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
