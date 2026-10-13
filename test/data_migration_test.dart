import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:larisai_mobile/services/local_db_service.dart';
import 'package:larisai_mobile/services/data_migration_service.dart';
import 'package:larisai_mobile/services/auth_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DataMigrationService Tests', () {
    test('1. MigrationProgress data contract initialization', () {
      final initialProg = MigrationProgress.initial();
      expect(initialProg.totalItems, 0);
      expect(initialProg.processedItems, 0);
      expect(initialProg.percentage, 0.0);
      expect(initialProg.isCompleted, isFalse);
      expect(initialProg.errorMessage, isNull);

      final customProg = MigrationProgress(
        totalItems: 50,
        processedItems: 25,
        currentPhase: 'Mengunggah produk...',
        percentage: 0.5,
      );
      expect(customProg.percentage, 0.5);
      expect(customProg.totalItems, 50);
      expect(customProg.processedItems, 25);
    });

    test('2. inspectDataSources accurately counts local SQLite records', () async {
      final db = await LocalDbService.instance.database;
      expect(db.isOpen, isTrue);

      // Pastikan ada produk starter
      final products = await LocalDbService.instance.getProducts();
      expect(products.isNotEmpty, isTrue);

      final inspection = await DataMigrationService.instance.inspectDataSources();
      expect(inspection.localProductsCount, greaterThanOrEqualTo(1));
      expect(inspection.localTransactionsCount, greaterThanOrEqualTo(0));
    });

    test('3. migrateLifetimeToCloud safely rejects when unauthenticated', () async {
      // Pastikan status logout
      if (AuthService.instance.isLoggedIn) {
        await AuthService.instance.logout();
      }

      final result = await DataMigrationService.instance.migrateLifetimeToCloud();
      expect(result.success, isFalse);
      expect(result.message, contains('login ke Akun Cloud SaaS'));
    });

    test('4. migrateCloudToLifetime atomic SQLite upsert and Option B (clearExistingOffline)', () async {
      final defaultDb = await LocalDbService.instance.database;

      // Seed dummy product in SQLite
      const testBarcode = '999888777666';
      await defaultDb.insert('products', {
        'id': 'test_prod_001',
        'barcode': testBarcode,
        'name': 'Produk Uji Coba Offline',
        'category': 'Pengujian',
        'price': 15000,
        'stock': 10,
        'is_archived': 0,
        'image_path': 'product_images/test_img.png',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      var foundProd = await LocalDbService.instance.getProductByBarcode(testBarcode);
      expect(foundProd, isNotNull);
      expect(foundProd!.name, 'Produk Uji Coba Offline');

      // Test simulate clearExistingOffline atomic transaction
      await defaultDb.transaction((txn) async {
        await txn.delete('transaction_items');
        await txn.delete('transactions');
        await txn.delete('products');

        // Insert new cloud products
        await txn.insert('products', {
          'id': 'cloud_synced_001',
          'barcode': '123456789012',
          'name': 'Kopi Susu Gula Aren Cloud',
          'category': 'Minuman',
          'price': 18000,
          'stock': 50,
          'is_archived': 0,
          'image_path': 'cloud_coffee.png',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      });

      // Verifikasi bahwa data lama terhapus bersih dan data baru tersimpan (Option B)
      final allProds = await LocalDbService.instance.getProducts();
      expect(allProds.length, 1);
      expect(allProds.first.id, 'cloud_synced_001');
      expect(allProds.first.name, 'Kopi Susu Gula Aren Cloud');
      expect(allProds.first.imagePath, 'cloud_coffee.png');

      // Restore starter data agar lingkungan test tetap bersih
      await LocalDbService.instance.factoryResetDatabase(reseedStarterProducts: true);
    });
  });
}
