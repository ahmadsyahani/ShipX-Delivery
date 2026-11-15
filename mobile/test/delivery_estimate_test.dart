import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/commerce/shop_widgets.dart';

void main() {
  testWidgets('road estimate fits compact screens and legacy orders hide it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: DeliveryEstimateNote(
                data: {
                  'delivery_distance_m': 2100,
                  'delivery_estimate': {
                    'travel_seconds': 301,
                    'travel_mode': 'motorcycle',
                    'calculated_at': '2026-11-14T02:00:00Z',
                  },
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Jarak jalan 2,1 km'), findsOneWidget);
    expect(find.textContaining('±6 menit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(home: DeliveryEstimateNote(data: {})),
    );
    expect(find.textContaining('Jarak jalan'), findsNothing);
  });
}
