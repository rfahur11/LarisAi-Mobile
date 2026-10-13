import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:larisai_mobile/models/product_model.dart';
import 'package:larisai_mobile/services/image_storage_service.dart';
import 'package:larisai_mobile/services/local_db_service.dart';
import 'package:larisai_mobile/services/local_host_server_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Product Image CRUD & LAN Streaming Tests', () {
    test('Product model correctly serializes and deserializes imagePath', () {
      final p1 = Product(
        id: 'p_test_1',
        barcode: '899001',
        name: 'Kopi Susu Regal',
        category: 'Minuman',
        price: 18000,
        stock: 25,
        imagePath: 'prod_test_1.jpg',
      );

      final json = p1.toJson();
      expect(json['image_path'], equals('prod_test_1.jpg'));

      final p2 = Product.fromJson(json);
      expect(p2.imagePath, equals('prod_test_1.jpg'));
      expect(p2.name, equals('Kopi Susu Regal'));

      final p3 = p2.copyWith(imagePath: 'prod_updated.png');
      expect(p3.imagePath, equals('prod_updated.png'));
    });

    test('LocalDbService inserts, reads, and updates product image_path in SQLite', () async {
      final dbService = LocalDbService.instance;

      // 1. Insert product with imagePath
      final product = Product(
        id: 'prod_img_test_100',
        barcode: '8999990011',
        name: 'Chitato Sapi Panggang 68g',
        category: 'Snack',
        price: 12500,
        stock: 15,
        imagePath: 'prod_chitato_100.jpg',
      );

      final inserted = await dbService.insertProduct(product);
      expect(inserted.imagePath, equals('prod_chitato_100.jpg'));

      // 2. Fetch and verify
      final allProducts = await dbService.getProducts(search: 'Chitato');
      expect(allProducts.isNotEmpty, isTrue);
      final found = allProducts.firstWhere((p) => p.id == 'prod_img_test_100');
      expect(found.imagePath, equals('prod_chitato_100.jpg'));

      // 3. Update imagePath
      final updated = found.copyWith(imagePath: 'prod_chitato_v2.jpg', price: 13000);
      final updateSuccess = await dbService.updateProduct(updated);
      expect(updateSuccess, isTrue);

      final refetched = await dbService.getProductByBarcode('8999990011');
      expect(refetched, isNotNull);
      expect(refetched!.imagePath, equals('prod_chitato_v2.jpg'));
      expect(refetched.price, equals(13000));

      // 4. Clean up
      final deleted = await dbService.deleteProduct('prod_img_test_100');
      expect(deleted, isTrue);
    });

    test('ImageStorageService saves bytes and LocalHostServer streams GET /api/v1/images/:filename', () async {
      final storage = ImageStorageService.instance;

      // Create a dummy image file in product_images
      final dummyBytes = utf8.encode('FAKE_IMAGE_DATA_HEADER');
      final savedFileName = await storage.saveImageBytes(dummyBytes, 'test_serve_img.jpg');
      expect(savedFileName, equals('test_serve_img.jpg'));

      final localFile = await storage.getLocalImageFile(savedFileName!);
      expect(localFile, isNotNull);
      expect(await localFile!.exists(), isTrue);

      // Start server on dedicated test port 8097
      final server = LocalHostServerService.instance;
      final ok = await server.startServer(port: 8097);
      expect(ok, isTrue);

      try {
        final dio = Dio();
        final res = await dio.get<List<int>>(
          'http://127.0.0.1:8097/api/v1/images/test_serve_img.jpg',
          options: Options(responseType: ResponseType.bytes),
        );
        expect(res.statusCode, equals(200));
        expect(res.headers.value('content-type'), contains('image/jpeg'));
        expect(res.data, equals(dummyBytes));
      } finally {
        await server.stopServer();
        // Clean up dummy test file
        await storage.deleteProductImage(savedFileName);
      }
    });
  });
}
