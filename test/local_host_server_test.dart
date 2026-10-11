import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:larisai_mobile/services/local_host_server_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // Enable real HTTP loopback connections
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('LocalHostServerService Tests', () {
    final server = LocalHostServerService.instance;

    setUp(() async {
      await server.startServer(port: 8099);
    });

    tearDown(() async {
      await server.stopServer();
    });

    test('Health probe endpoint returns ok status', () async {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8099/api/v1/health'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      final responseBody = await utf8.decoder.bind(res).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      expect(data['status'], equals('ok'));
      expect(data['mode'], equals('lan_host'));
      expect(data['engine'], equals('sqlite_embedded'));
      client.close();
    });

    test('Products endpoint returns JSON list', () async {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8099/api/v1/products'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      final responseBody = await utf8.decoder.bind(res).join();
      final data = jsonDecode(responseBody);

      expect(data, isA<List>());
      client.close();
    });
  });
}
