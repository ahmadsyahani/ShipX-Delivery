import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipx/core/auth_api.dart';

void main() {
  test(
    'proof upload sends authenticated multipart bytes with the same retry key',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final received = server.first.then((request) async {
        expect(request.uri.path, '/api/v1/courier/trips/1/stops/2/proofs');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer qa-token',
        );
        expect(request.headers.value('Idempotency-Key'), 'qa-key');
        expect(request.headers.contentType!.mimeType, 'multipart/form-data');
        final data = await request.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        final body = latin1.decode(data);
        expect(body, contains('name="photo"'));
        expect(body, contains('filename="proof.png"'));
        expect(body, contains(latin1.decode(bytes)));
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': {'id': 'qa-upload'},
          }),
        );
        await request.response.close();
      });
      try {
        final api = AuthApi(baseUrl: 'http://127.0.0.1:${server.port}/api/v1/');
        final result = await api.uploadProof(
          '/courier/trips/1/stops/2/proofs',
          bytes,
          'qa-key',
          token: 'qa-token',
        );
        expect(result['id'], 'qa-upload');
        await received;
      } finally {
        await server.close(force: true);
      }
    },
  );
}
