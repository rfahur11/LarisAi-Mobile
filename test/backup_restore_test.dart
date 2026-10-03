import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:larisai_mobile/services/local_db_service.dart';
import 'package:larisai_mobile/services/export_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Test standard backup export and restore', () async {
    final db = await LocalDbService.instance.database;
    expect(db.isOpen, isTrue);

    final jsonStr = await ExportService.instance.generateBackupJsonString();
    expect(jsonStr.isNotEmpty, isTrue);

    final result = await ExportService.instance.restoreFromJson(jsonStr);
    expect(result['products_restored'], greaterThanOrEqualTo(1));
  });

  test('Test restoring loose JSON with non-standard types (boolean is_archived, string prices)', () async {
    final testJson = jsonEncode({
      'products': [
        {
          'id': 'test-1',
          'barcode': '1122334455',
          'name': 'Kecap Manis Bango',
          'category': 'Sembako',
          'price': '12500',
          'stock': '20',
          'is_archived': true,
        },
        {
          'id': 'test-2',
          'barcode': '9988776655',
          'name': 'Biskuit Roma Kelapa',
          'category': 'Makanan',
          'price': 9000,
          'stock': 15,
          'is_archived': false,
        }
      ],
      'transactions': [
        {
          'id': 'TX-TEST-001',
          'invoice_no': 'INV-20261002-001',
          'customer_id': 'Pelanggan 1',
          'total_amount': 25000,
          'payment_type': 'Tunai',
          'created_at': DateTime.now().toIso8601String(),
        }
      ],
      'transaction_items': [
        {
          'transaction_id': 'TX-TEST-001',
          'product_id': 'test-1',
          'name': 'Kecap Manis Bango',
          'price': 12500,
          'quantity': 2,
          'subtotal': 25000,
        }
      ]
    });

    final result = await ExportService.instance.restoreFromJson(testJson);
    expect(result['products_restored'], equals(2));
    expect(result['transactions_restored'], equals(1));

    // Verify products in database
    final products = await LocalDbService.instance.getProducts();
    // test-1 is archived, so only test-2 should be active
    expect(products.any((p) => p.id == 'test-2'), isTrue);

    // Check transactions
    final txs = await LocalDbService.instance.getTransactions();
    expect(txs.length, equals(1));
    expect(txs.first.invoiceNo, equals('INV-20261002-001'));
    expect(txs.first.items.length, equals(1));
  });
}
