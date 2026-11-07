import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/auth_api.dart';
import 'package:shipx/core/auth_session.dart';

class MemoryStore implements TokenStore {
  String? value = 'saved-token';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

class FakeApi extends AuthApi {
  Object? error;
  final profile = const ShipXUser(
    '1',
    'Courier',
    'courier@example.test',
    'courier',
  );
  @override
  Future<ShipXUser> me(String token) async {
    if (error != null) throw error!;
    return profile;
  }

  @override
  Future<void> logout(String token) async {
    if (error != null) throw error!;
  }
}

void main() {
  test(
    'catalog encodes category and page without sending null category',
    () async {
      final api = CatalogQueryApi();
      final session = AuthSession(api: api, store: MemoryStore());
      await session.catalog(
        category: 'Rumah & perawatan',
        query: 'sabun cair',
        page: 2,
      );
      expect(Uri.parse(api.path!).queryParameters, {
        'q': 'sabun cair',
        'category': 'Rumah & perawatan',
        'page': '2',
      });
      await session.catalog();
      expect(
        Uri.parse(api.path!).queryParameters.containsKey('category'),
        isFalse,
      );
      session.dispose();
    },
  );
  test(
    'restore uses server role and clears invalid or inactive sessions',
    () async {
      final api = FakeApi();
      final store = MemoryStore();
      final session = AuthSession(api: api, store: store);
      await session.restore();
      expect(session.user?.role, 'courier');
      for (final status in [401, 403]) {
        store.value = 'invalid-token';
        api.error = ApiException('Denied', status);
        await session.restore();
        expect(session.user, isNull);
        expect(store.value, isNull);
        expect(session.restoreError, isNull);
      }
    },
  );

  test('offline restoration retains token and supports retry', () async {
    final api = FakeApi()..error = const SocketException('offline');
    final store = MemoryStore();
    final session = AuthSession(api: api, store: store);
    await session.restore();
    expect(store.value, 'saved-token');
    expect(session.restoreError, isNotNull);
    api.error = null;
    await session.restore();
    expect(session.user?.role, 'courier');
    expect(session.restoreError, isNull);
  });

  test(
    'logout retains session on network failure and clears after revocation',
    () async {
      final api = FakeApi();
      final store = MemoryStore();
      final session = AuthSession(api: api, store: store);
      await session.restore();
      api.error = const SocketException('offline');
      await expectLater(session.logout(), throwsA(isA<SocketException>()));
      expect(store.value, 'saved-token');
      expect(session.user, isNotNull);
      api.error = null;
      await session.logout();
      expect(store.value, isNull);
      expect(session.user, isNull);
    },
  );

  test('refresh clears a revoked session', () async {
    final api = FakeApi();
    final store = MemoryStore();
    final session = AuthSession(api: api, store: store);
    await session.restore();
    api.error = const ApiException('Expired', 401);
    await expectLater(session.refresh(), throwsA(isA<ApiException>()));
    expect(session.user, isNull);
    expect(store.value, isNull);
  });
}

class CatalogQueryApi extends AuthApi {
  String? path;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Map<String, String>? headers,
    bool envelope = false,
  }) async {
    this.path = path;
    return {};
  }
}
