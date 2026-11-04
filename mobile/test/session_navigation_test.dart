import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/main.dart';

class SignedSession extends AuthSession {
  SignedSession() {
    user = const ShipXUser('1', 'Courier', 'courier@example.test', 'courier');
  }
  @override
  Future<void> restore() async {
    restoring = false;
    notifyListeners();
  }

  void expire() {
    user = null;
    notifyListeners();
  }
}

void main() {
  testWidgets('revoked session removes private routes from navigation stack', (
    tester,
  ) async {
    final session = SignedSession();
    await tester.pumpWidget(ShipXApp(session: session));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Private order snapshot')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private order snapshot'), findsOneWidget);
    session.expire();
    await tester.pumpAndSettle();
    expect(find.text('Private order snapshot'), findsNothing);
    expect(find.text('Masuk ShipX'), findsOneWidget);
  });
}
