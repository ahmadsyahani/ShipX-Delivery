import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/app_theme.dart';
import 'package:shipx/courier/reconciliation_view.dart';
import 'package:shipx/courier/trips_page.dart';
import 'courier_trips_test.dart' show TripSession, trip;

Map<String, dynamic> reconciliation(bool closed) => {
  'expected_cash_rp': 48000,
  'items': [
    {
      'product_id': '1',
      'name': 'Barang kembali dengan nama cukup panjang untuk layar kecil',
      'stock_state': 'available',
      'expected_quantity': 2,
    },
  ],
  'record': closed
      ? {
          'expected_cash_rp': 48000,
          'actual_cash_rp': 47000,
          'cash_difference_rp': -1000,
          'discrepancy_reason':
              'Setoran kurang seribu dan sudah diperiksa bersama admin.',
          'approved_at': '2026-11-08T05:00:00Z',
          'items': [
            {
              'product_id': '1',
              'name':
                  'Barang kembali dengan nama cukup panjang untuk layar kecil',
              'stock_state': 'available',
              'expected_quantity': 2,
              'actual_quantity': 1,
              'difference': -1,
              'discrepancy_reason':
                  'Satu kemasan rusak dan diterima di karantina.',
            },
            {
              'product_id': '1',
              'name':
                  'Barang kembali dengan nama cukup panjang untuk layar kecil',
              'stock_state': 'quarantine',
              'expected_quantity': 0,
              'actual_quantity': 1,
              'difference': 1,
              'discrepancy_reason':
                  'Satu kemasan rusak dan diterima di karantina.',
            },
          ],
        }
      : null,
};

class ReconciliationSession extends TripSession {
  bool closed = false;
  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    final data = {
      ...trip(),
      'status': closed ? 'completed' : 'awaiting_reconciliation',
      'reconciliation': reconciliation(closed),
    };
    return path.endsWith('/9')
        ? {'data': data}
        : {
            'data': closed ? [] : [data],
            'recent_completed': closed ? [data] : [],
          };
  }
}

void main() {
  setUpAll(() async {
    final font = FontLoader('PlusJakartaSans');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      font.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320, 390, 820]) {
    testWidgets(
      'return instructions and final receipt fit ${width}px with real fonts',
      (tester) async {
        tester.view.physicalSize = Size(width.toDouble(), 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final closed in [false, true]) {
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                theme: AppTheme.theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 1.5 : 1),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ReconciliationView(
                        summary: reconciliation(closed),
                        timezone: 'Asia/Jakarta',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              closed ? 'Setoran diterima' : 'Barang yang perlu kembali',
            ),
            findsOneWidget,
          );
          if (closed) expect(find.textContaining('Selisih -1'), findsOneWidget);
          if (Platform.environment['SHIPX_UI_CAPTURE'] == '1') {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final output = File(
                'build/ui-preview/reconciliation-${closed ? 'receipt' : 'return'}-$width.png',
              );
              await output.parent.create(recursive: true);
              await output.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      },
    );
  }
  testWidgets(
    'open courier detail changes to completed receipt on polling instead of disappearing',
    (tester) async {
      final session = ReconciliationSession();
      await tester.pumpWidget(
        MaterialApp(
          home: CourierTripsPage(session: session, id: '9'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kembali & serahkan ke admin'), findsOneWidget);
      session.closed = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Trip selesai'), findsOneWidget);
      expect(find.text('Trip selesai. Terima kasih!'), findsOneWidget);
      expect(find.textContaining('tidak lagi tersedia'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: CourierTripsPage(key: UniqueKey(), session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TR-QA'), findsOneWidget);
      expect(find.text('Trip selesai'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
