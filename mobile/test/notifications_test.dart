import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';
import 'package:shipx/core/contact_button.dart';
import 'package:shipx/notifications_page.dart';

class InboxSession extends AuthSession {
  bool read = false;
  ApiException? failure;
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    calls.add('$method $path');
    if (failure != null) throw failure!;
    if (method == 'PUT') {
      read = true;
      return {};
    }
    return {
      'unread_count': read ? 0 : 1,
      'data': {
        'current_page': 1,
        'last_page': 1,
        'data': [
          {
            'id': 'notification-one',
            'read_at': read ? '2026-11-14T02:00:00Z' : null,
            'created_at': '2026-11-14T02:00:00Z',
            'data': {
              'title': 'SX-001',
              'message': 'Pesanan sedang diantar.',
              'kind': 'order',
              'target_id': '12',
            },
          },
        ],
      },
    };
  }
}

void main() {
  testWidgets('inbox marks owned notification before opening its order', (
    tester,
  ) async {
    final session = InboxSession();
    addTearDown(session.dispose);
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsPage(
          session: session,
          openTarget: (kind, id) async => opened = '$kind/$id',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pesanan sedang diantar.'), findsOneWidget);
    await tester.tap(find.text('SX-001'));
    await tester.pumpAndSettle();
    expect(session.calls, contains('PUT /notifications/notification-one/read'));
    expect(opened, 'order/12');
    await tester.tap(find.byTooltip('Tandai semua dibaca'));
    await tester.pumpAndSettle();
    expect(session.calls, contains('PUT /notifications/read-all'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'offline retains inbox while revoked access clears cached messages',
    (tester) async {
      final session = InboxSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsPage(
            session: session,
            openTarget: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      session.failure = const ApiException('offline', 0);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.text('SX-001'), findsOneWidget);
      expect(find.textContaining('Periksa koneksi'), findsOneWidget);
      session.failure = const ApiException('revoked', 403);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.text('SX-001'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('bell opens inbox with unread count', (tester) async {
    final session = InboxSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBell(session: session, openTarget: (_, _) async {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('SX-001'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('contact requires usable phone and fits narrow layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ContactButton(phone: null, label: 'Tidak tersedia'),
              ContactButton(phone: '+62 812-3456', label: 'Hubungi penerima'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Tidak tersedia'), findsNothing);
    expect(find.text('Hubungi penerima'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
