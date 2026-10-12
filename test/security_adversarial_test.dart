import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:larisai_mobile/services/excel_import_service.dart';
import 'package:larisai_mobile/services/local_host_server_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('🛡️ Cyber Threat Guard: Security & Adversarial Tests', () {
    // ========================================================
    // 1. FORMULA / DDE INJECTION SANITIZATION TESTS (CWE-1236)
    // ========================================================
    test('sanitizeFormulaInjection neutralizes dangerous spreadsheet prefixes', () {
      // 1. Equal sign formula injection
      expect(
        ExcelImportService.sanitizeFormulaInjection('=cmd|\'/C calc\'!A0'),
        equals("'=cmd|'/C calc'!A0"),
      );

      // 2. Plus sign formula injection
      expect(
        ExcelImportService.sanitizeFormulaInjection('+12345+cmd'),
        equals("'+12345+cmd"),
      );

      // 3. At symbol formula injection
      expect(
        ExcelImportService.sanitizeFormulaInjection('@SUM(1,2)'),
        equals("'@SUM(1,2)"),
      );

      // 4. Legitimate negative number must NOT be broken
      expect(
        ExcelImportService.sanitizeFormulaInjection('-15000'),
        equals('-15000'),
      );
      expect(
        ExcelImportService.sanitizeFormulaInjection('-250.50'),
        equals('-250.50'),
      );

      // 5. Normal product name remains clean
      expect(
        ExcelImportService.sanitizeFormulaInjection('Indomie Goreng 85g'),
        equals('Indomie Goreng 85g'),
      );
    });

    test('parseExcelBytes sanitizes formula strings inside actual Excel rows', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Headers
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          TextCellValue('Barcode');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
          TextCellValue('Nama Produk');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
          TextCellValue('Kategori');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value =
          TextCellValue('Harga Jual');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value =
          TextCellValue('Harga Modal');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value =
          TextCellValue('Stok Awal');

      // Row with malicious formula injection payload
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
          TextCellValue('8990001');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value =
          TextCellValue('=cmd|\'/C calc\'!A0');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value =
          TextCellValue('@Sembako');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value =
          IntCellValue(5000);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value =
          IntCellValue(4000);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value =
          IntCellValue(10);

      final bytes = excel.save()!;
      final result = ExcelImportService.instance.parseExcelBytes(bytes);

      expect(result.validProducts.length, equals(1));
      final product = result.validProducts.first;

      // Assert that product name and category are safely escaped with single quote (')
      expect(product.name, equals("'=cmd|'/C calc'!A0"));
      expect(product.category, equals("'@Sembako"));
    });

    // ========================================================
    // 2. DOS FILE SIZE & ROW COUNT GUARD TESTS
    // ========================================================
    test('parseExcelBytes rejects oversized files with clean error', () {
      final dummyBytes = List<int>.filled(200, 65); // 200 bytes
      // Set maxBytes constraint to 100 bytes
      final result = ExcelImportService.instance.parseExcelBytes(dummyBytes, maxBytes: 100);

      expect(result.validProducts, isEmpty);
      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('File terlalu besar'));
    });

    // ========================================================
    // 3. WI-FI LAN HUB CLUSTER TOKEN & PIN RATE-LIMITER TESTS
    // ========================================================
    group('LocalHostServerService LAN Security', () {
      final server = LocalHostServerService.instance;
      const testPort = 8097;

      setUp(() async {
        server.setClusterToken('sec-cluster-test-token-xyz');
        server.setServerPin('8899');
        server.clearPinAttempts();
        await server.startServer(port: testPort);
      });

      tearDown(() async {
        await server.stopServer();
      });

      test('Protected endpoint rejects rogue client with invalid cluster token (401)', () async {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/api/v1/products'));
        // Provide an INVALID token explicitly
        req.headers.set('x-cluster-auth', 'malicious-attacker-token');
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.unauthorized));
        final bodyStr = await utf8.decoder.bind(res).join();
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        expect(body['error'], contains('Akses Ditolak'));
        client.close();
      });

      test('Protected endpoint accepts client with valid cluster token (200)', () async {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/api/v1/products'));
        // Provide the VALID token
        req.headers.set('x-cluster-auth', 'sec-cluster-test-token-xyz');
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.ok));
        final bodyStr = await utf8.decoder.bind(res).join();
        final body = jsonDecode(bodyStr);
        expect(body, isA<List>());
        client.close();
      });

      test('PIN Brute-Force lockout triggers after 5 failed attempts (429 Too Many Requests)', () async {
        final client = HttpClient();

        // 1. Perform 4 failed attempts
        for (int i = 1; i <= 4; i++) {
          final req = await client.postUrl(Uri.parse('http://127.0.0.1:$testPort/api/v1/auth/login'));
          req.headers.set('Content-Type', 'application/json');
          req.write(jsonEncode({'password': 'wrong_pin_$i'}));
          final res = await req.close();

          expect(res.statusCode, equals(HttpStatus.unauthorized));
          final bodyStr = await utf8.decoder.bind(res).join();
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;
          expect(body['remaining_attempts'], equals(5 - i));
          expect(body['locked'], isFalse);
        }

        // 2. 5th failed attempt -> Triggers lockout
        final req5 = await client.postUrl(Uri.parse('http://127.0.0.1:$testPort/api/v1/auth/login'));
        req5.headers.set('Content-Type', 'application/json');
        req5.write(jsonEncode({'password': 'wrong_pin_5'}));
        final res5 = await req5.close();

        expect(res5.statusCode, equals(HttpStatus.unauthorized));
        final bodyStr5 = await utf8.decoder.bind(res5).join();
        final body5 = jsonDecode(bodyStr5) as Map<String, dynamic>;
        expect(body5['locked'], isTrue);

        // 3. 6th attempt -> Blocked immediately with 429 Too Many Requests
        final req6 = await client.postUrl(Uri.parse('http://127.0.0.1:$testPort/api/v1/auth/login'));
        req6.headers.set('Content-Type', 'application/json');
        req6.write(jsonEncode({'password': 'any_pin'}));
        final res6 = await req6.close();

        expect(res6.statusCode, equals(HttpStatus.tooManyRequests));
        final bodyStr6 = await utf8.decoder.bind(res6).join();
        final body6 = jsonDecode(bodyStr6) as Map<String, dynamic>;
        expect(body6['locked'], isTrue);
        expect(body6['remaining_seconds'], greaterThan(0));

        client.close();
      });

      test('Login succeeds with correct PIN and returns cluster token', () async {
        final client = HttpClient();
        final req = await client.postUrl(Uri.parse('http://127.0.0.1:$testPort/api/v1/auth/login'));
        req.headers.set('Content-Type', 'application/json');
        req.write(jsonEncode({'email': 'kasir@toko.id', 'password': '8899'}));
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.ok));
        final bodyStr = await utf8.decoder.bind(res).join();
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        expect(body['token'], equals('sec-cluster-test-token-xyz'));
        expect(body['cluster_token'], equals('sec-cluster-test-token-xyz'));
        client.close();
      });
    });
  });
}
