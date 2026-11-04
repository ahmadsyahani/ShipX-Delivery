import 'dart:io';
import 'package:shipx/core/health_api.dart';

Future<void> main(List<String> args) async {
  final url = args.isEmpty ? 'http://127.0.0.1:8000/api/v1' : args.single;
  await HealthApi().check(url);
  stdout.writeln('PASS: Dart HTTP client -> ShipX /health ($url)');
}
