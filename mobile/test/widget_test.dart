import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/main.dart';
import 'package:shipx/core/auth_session.dart';

class MemoryTokenStore implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

void main() {
  testWidgets('Connection screen starts without making network requests', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShipXApp(session: AuthSession(store: MemoryTokenStore())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Periksa koneksi'), findsOneWidget);
    expect(find.text('Masuk ShipX'), findsOneWidget);
    await tester.tap(find.text('Periksa koneksi'));
    await tester.pumpAndSettle();
    expect(find.text('Barang sampai, urusan beres.'), findsOneWidget);
  });
}
