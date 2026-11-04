import 'dart:convert';
import 'dart:io';

class HealthApi {
  Future<void> check(String baseUrl) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/health');
    if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      throw const FormatException('Alamat API tidak valid.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw HttpException('Server merespons ${response.statusCode}.');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['data'] is! Map) {
        throw const FormatException('Respons API tidak sesuai kontrak.');
      }
      final data = decoded['data'] as Map;
      if (data['service'] != 'shipx-api' ||
          data['status'] != 'ok' ||
          data['api_version'] != 'v1') {
        throw const FormatException(
          'Server bukan API ShipX v1 yang diharapkan.',
        );
      }
    } finally {
      client.close(force: true);
    }
  }
}
