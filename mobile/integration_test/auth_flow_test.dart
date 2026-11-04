import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shipx/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android reaches health, registers, restores, logs out and logs in',
    (tester) async {
      const email = String.fromEnvironment('SMOKE_EMAIL');
      expect(
        email,
        isNotEmpty,
        reason: 'Use a disposable smoke account email.',
      );
      const password = 'ShipX-smoke-only-2026!';
      await tester.pumpWidget(const ShipXApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Periksa koneksi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Periksa koneksi'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Terhubung ke API ShipX v1.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat akun pelanggan'));
      await tester.pumpAndSettle();
      Future<void> field(String key, String value) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
      }

      await field('name', 'ShipX Smoke Test');
      await field('email', email);
      await field('phone', '080000000000');
      await field('password', password);
      await field('password_confirmation', password);
      await tester.ensureVisible(find.text('Daftar'));
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Beranda pelanggan'), findsOneWidget);
      const productName = String.fromEnvironment('SMOKE_PRODUCT_NAME');
      if (productName.isNotEmpty) {
        await tester.enterText(find.byType(TextField), productName);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        final productLabel = find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == productName,
        );
        expect(productLabel, findsOneWidget);
        await tester.ensureVisible(productLabel);
        await tester.tap(productLabel);
        await tester.pumpAndSettle();
        expect(find.text('Tutup detail'), findsOneWidget);
        await tester.ensureVisible(find.text('Tutup detail'));
        await tester.tap(find.text('Tutup detail'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Periksa sesi'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Recreate the application: the new session must read Android secure storage
      // and validate the saved bearer token with /me.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const ShipXApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Beranda pelanggan'), findsOneWidget);
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Masuk ShipX'), findsOneWidget);
      await field('email', email);
      await field('password', password);
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Beranda pelanggan'), findsOneWidget);
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Masuk ShipX'), findsOneWidget);
    },
  );
}
