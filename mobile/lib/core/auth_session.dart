import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_api.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  final _storage = const FlutterSecureStorage();
  static const _key = 'shipx.auth.token';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class AuthSession extends ChangeNotifier {
  AuthSession({AuthApi? api, TokenStore? store})
    : api = api ?? AuthApi(),
      store = store ?? SecureTokenStore();
  final AuthApi api;
  final TokenStore store;
  ShipXUser? user;
  String? _token;
  bool restoring = true;
  String? restoreError;

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<Map<String, dynamic>> catalog({
    String query = '',
    String? category,
    int page = 1,
  }) async {
    try {
      final path = Uri(
        path: '/catalog',
        queryParameters: {'q': query, 'page': '$page', 'category': ?category},
      ).toString();
      return await api.request('GET', path, token: _token, envelope: true);
    } on ApiException catch (error) {
      if (error.status == 401 ||
          (error.status == 403 && user?.role == 'customer')) {
        await _clear();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> restore() async {
    restoring = true;
    restoreError = null;
    notifyListeners();
    try {
      _token = await store.read();
      if (_token != null) user = await api.me(_token!);
    } on ApiException catch (error) {
      if ([401, 403].contains(error.status)) {
        await _clear();
      } else {
        restoreError = 'Sesi belum dapat diperiksa. Coba lagi.';
      }
    } catch (_) {
      restoreError =
          'Sesi belum dapat diperiksa. Periksa koneksi lalu coba lagi.';
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> deliveryRequest(
    String method,
    String path, {
    Map<String, String>? body,
    bool envelope = false,
  }) async {
    try {
      return await api.request(
        method,
        path,
        token: _token,
        body: body,
        envelope: envelope,
      );
    } on ApiException catch (error) {
      if (error.status == 401 ||
          (error.status == 403 && user?.role == 'customer')) {
        await _clear();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> authenticate(
    Map<String, String> fields, {
    required bool register,
  }) async {
    final result = await api.authenticate(fields, register: register);
    await store.write(result.token);
    _token = result.token;
    user = result.user;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      user = await api.me(_token!);
      notifyListeners();
    } on ApiException catch (error) {
      if ([401, 403].contains(error.status)) {
        await _clear();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await api.logout(_token!);
    } on ApiException catch (error) {
      if (![401, 403].contains(error.status)) rethrow;
    }
    await _clear();
    notifyListeners();
  }

  Future<Map<String, dynamic>> commerceRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
    bool envelope = false,
  }) async {
    try {
      return await api.request(
        method,
        path,
        token: _token,
        body: body,
        envelope: envelope,
        headers: key == null ? null : {'Idempotency-Key': key},
      );
    } on ApiException catch (error) {
      if (error.status == 401 ||
          (error.status == 403 &&
              (user?.role == 'customer' ||
                  (user?.role == 'courier' && path.startsWith('/courier/'))))) {
        await _clear();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> _clear() async {
    await store.clear();
    _token = null;
    user = null;
  }

  Future<Map<String, dynamic>> uploadProof(
    String path,
    Uint8List bytes,
    String key,
  ) async {
    try {
      return await api.uploadProof(path, bytes, key, token: _token);
    } on ApiException catch (error) {
      if ([401, 403].contains(error.status)) {
        await _clear();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<Uint8List> proofPhoto(String id) async {
    try {
      return await api.proofPhoto(id, token: _token);
    } on ApiException catch (error) {
      if ([401, 403].contains(error.status)) {
        await _clear();
        notifyListeners();
      }
      rethrow;
    }
  }
}
