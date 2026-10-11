import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:larisai_mobile/core/constants/api_constants.dart';
import 'package:larisai_mobile/services/api_service.dart';
import 'package:larisai_mobile/services/local_db_service.dart';
import 'package:larisai_mobile/models/product_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Strict Database Isolation & Anti-Fallback Tests', () {
    test('Offline mode accesses larisai_offline.db directly', () async {
      ApiConstants.currentMode = ConnectionMode.offline;
      await LocalDbService.instance.insertProduct(Product(
        id: 'test_off_1',
        barcode: '8992753112234',
        name: 'Indomie Goreng Offline',
        price: 3500,
        stock: 50,
      ));
      final apiService = ApiService();
      final products = await apiService.getProducts();

      expect(products, isNotEmpty);
      expect(products.any((p) => p.name.contains('Indomie')), isTrue);
    });

    test('Cloud mode throws CloudConnectionException when unreachable and NEVER falls back to offline db', () async {
      ApiConstants.currentMode = ConnectionMode.cloud;
      ApiConstants.posBaseUrl = 'http://127.0.0.1:59999'; // unreachable port
      final apiService = ApiService();

      expect(
        () async => await apiService.getProducts(),
        throwsA(isA<CloudConnectionException>()),
      );
    });

    test('LAN mode throws LanConnectionException when host unreachable', () async {
      ApiConstants.currentMode = ConnectionMode.wifi;
      ApiConstants.posBaseUrl = 'http://127.0.0.1:59998'; // unreachable port
      final apiService = ApiService();

      expect(
        () async => await apiService.getProducts(),
        throwsA(isA<LanConnectionException>()),
      );
    });

    test('Tenant database is completely isolated from offline db', () async {
      final tenantId = 'store_iso_${DateTime.now().millisecondsSinceEpoch}';
      final tenantDb = await LocalDbService.instance.getTenantDatabase(tenantId);
      expect(tenantDb.isOpen, isTrue);

      final tenantProducts = await LocalDbService.instance.getProducts(customDb: tenantDb);
      // Fresh tenant db does not have starter offline products seeded
      expect(tenantProducts.isEmpty, isTrue);

      // Inserting product to tenant DB
      final testProd = Product(
        id: 'tp_01',
        barcode: '111222333',
        name: 'Produk Eksklusif Toko Cloud XYZ',
        category: 'Spesial',
        price: 99000,
        stock: 10,
      );
      await LocalDbService.instance.insertProduct(testProd, customDb: tenantDb);

      final updatedTenant = await LocalDbService.instance.getProducts(customDb: tenantDb);
      expect(updatedTenant.length, 1);
      expect(updatedTenant.first.name, 'Produk Eksklusif Toko Cloud XYZ');

      // Verify that offline db does not contain this tenant product
      final offlineProducts = await LocalDbService.instance.getProducts();
      expect(offlineProducts.any((p) => p.id == 'tp_01'), isFalse);
    });
  });
}
