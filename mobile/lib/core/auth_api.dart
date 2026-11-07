import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, this.status, {this.code});
  final String message;
  final int status;
  final String? code;
  @override
  String toString() => message;
}

class ShipXUser {
  const ShipXUser(this.id, this.name, this.email, this.role);
  factory ShipXUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String;
    if (!['customer', 'courier', 'admin'].contains(role)) {
      throw const FormatException('Role tidak dikenal.');
    }
    return ShipXUser(
      json['id'] as String,
      json['name'] as String,
      json['email'] as String,
      role,
    );
  }
  final String id, name, email, role;
}

class AuthResult {
  const AuthResult(this.user, this.token);
  final ShipXUser user;
  final String token;
}

class AuthApi {
  AuthApi({this.baseUrl = ApiConfig.baseUrl});
  final String baseUrl;

  Future<Map<String, dynamic>> uploadProof(
    String path,
    Uint8List bytes,
    String key, {
    String? token,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await (() async {
        final boundary = 'shipx${DateTime.now().microsecondsSinceEpoch}';
        final request = await client.postUrl(
          Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path'),
        );
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.headers.set('Idempotency-Key', key);
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary',
        );
        final png = bytes.length > 3 && bytes[0] == 137 && bytes[1] == 80;
        final prefix = utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="photo"; filename="proof.${png ? 'png' : 'jpg'}"\r\nContent-Type: image/${png ? 'png' : 'jpeg'}\r\n\r\n',
        );
        final suffix = utf8.encode('\r\n--$boundary--\r\n');
        request.contentLength = prefix.length + bytes.length + suffix.length;
        request.add(prefix);
        request.add(bytes);
        request.add(suffix);
        final response = await request.close();
        final raw = await utf8.decoder.bind(response).join();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        if (response.statusCode >= 400) {
          final errors = decoded['errors'];
          final message = errors is Map && errors.isNotEmpty
              ? (errors.values.first as List).join(' ')
              : decoded['message'] as String? ?? 'Unggahan gagal.';
          throw ApiException(
            message,
            response.statusCode,
            code: decoded['code'] as String?,
          );
        }
        return decoded['data'] as Map<String, dynamic>;
      })().timeout(const Duration(seconds: 35));
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> proofPhoto(String id, {String? token}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await (() async {
        final request = await client.getUrl(
          Uri.parse(
            '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/delivery-proofs/$id',
          ),
        );
        request.followRedirects = false;
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close();
        if (response.statusCode != 200) {
          throw ApiException('Foto belum dapat dibuka.', response.statusCode);
        }
        final bytes = BytesBuilder();
        await for (final chunk in response) {
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      })().timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }

  Future<AuthResult> authenticate(
    Map<String, String> fields, {
    required bool register,
  }) async {
    final data = await request(
      'POST',
      '/auth/${register ? 'register' : 'login'}',
      body: {...fields, 'device_name': 'ShipX Android'},
    );
    return AuthResult(
      ShipXUser.fromJson(data['user'] as Map<String, dynamic>),
      data['token'] as String,
    );
  }

  Future<ShipXUser> me(String token) async =>
      ShipXUser.fromJson(await request('GET', '/me', token: token));

  Future<void> logout(String token) async {
    await request('DELETE', '/auth/token', token: token);
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    bool envelope = false,
    Map<String, String>? headers,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await (() async {
        final request = await client.openUrl(
          method,
          Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path'),
        );
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        headers?.forEach((name, value) => request.headers.set(name, value));
        if (token != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        final raw = await utf8.decoder.bind(response).join();
        if (response.statusCode == 204) return <String, dynamic>{};
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        if (response.statusCode >= 400) {
          final errors = decoded['errors'];
          final message = errors is Map && errors.isNotEmpty
              ? (errors.values.first as List).join(' ')
              : decoded['message'] as String? ?? 'Permintaan gagal.';
          throw ApiException(
            message,
            response.statusCode,
            code: decoded['code'] as String?,
          );
        }
        return envelope ? decoded : decoded['data'] as Map<String, dynamic>;
      })().timeout(const Duration(seconds: 12));
    } finally {
      client.close(force: true);
    }
  }
}
