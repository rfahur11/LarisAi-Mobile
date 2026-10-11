import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:larisai_mobile/services/local_db_service.dart';
import 'package:larisai_mobile/services/local_host_server_service.dart';
import 'package:larisai_mobile/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('LAN Checkout Stock Reduction & Sync Tests', () {
    final server = LocalHostServerService.instance;
    final dbService = LocalDbService.instance;

    setUp(() async {
      await server.startServer(port: 8098);
      // Insert test product
      await dbService.insertProduct(Product(
        id: 'test_p_1',
        barcode: '8991234567890',
        name: 'Kopi Susu Test',
        category: 'Minuman',
        price: 5000,
        stock: 20,
      ));
    });

    tearDown(() async {
      await server.stopServer();
    });

    test('HTTP Checkout on port 8098 reduces stock and broadcasts event', () async {
      final client = HttpClient();
      
      // 1. Verify initial stock via GET /api/v1/products
      final getReq = await client.getUrl(Uri.parse('http://127.0.0.1:8098/api/v1/products'));
      final getRes = await getReq.close();
      final bodyStr = await utf8.decoder.bind(getRes).join();
      final products = jsonDecode(bodyStr) as List;
      final testProd = products.firstWhere((p) => p['barcode'] == '8991234567890');
      
      expect(testProd['id'], equals('test_p_1')); // ID must not be empty!
      expect(testProd['stock'], equals(20));

      // 2. Perform checkout from mobile client simulation (sending 3 pcs)
      bool eventFired = false;
      final sub = server.onDataChanged.listen((event) {
        if (event == 'checkout_completed') eventFired = true;
      });

      final postReq = await client.postUrl(Uri.parse('http://127.0.0.1:8098/api/v1/checkout'));
      postReq.headers.set('Content-Type', 'application/json');
      postReq.write(jsonEncode({
        'payment_type': 'TUNAI',
        'items': [
          {
            'product_id': 'test_p_1',
            'barcode': '8991234567890',
            'quantity': 3,
          }
        ],
      }));
      final postRes = await postReq.close();
      expect(postRes.statusCode, equals(HttpStatus.created));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(eventFired, isTrue);

      // 3. Verify stock has reduced from 20 to 17 in SQLite
      final updated = await dbService.getProductByBarcode('8991234567890');
      expect(updated, isNotNull);
      expect(updated!.stock, equals(17));

      await sub.cancel();
      client.close();
    });

    test('HTTP Checkout with missing product_id and barcode self-heals by name', () async {
      final client = HttpClient();

      final postReq = await client.postUrl(Uri.parse('http://127.0.0.1:8098/api/v1/checkout'));
      postReq.headers.set('Content-Type', 'application/json');
      // Simulate client sending empty ID and barcode, but with name 'Kopi Susu Test'
      postReq.write(jsonEncode({
        'payment_type': 'TUNAI',
        'items': [
          {
            'product_id': '',
            'barcode': '',
            'name': 'Kopi Susu Test',
            'quantity': 2,
          }
        ],
      }));
      final postRes = await postReq.close();
      expect(postRes.statusCode, equals(HttpStatus.created));

      // Verify stock was reduced by 2 (from 20 to 18)
      final updated = await dbService.getProductByBarcode('8991234567890');
      expect(updated, isNotNull);
      expect(updated!.stock, equals(18));

      client.close();
    });
  });
}
