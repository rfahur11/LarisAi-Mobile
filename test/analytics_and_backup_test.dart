import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:larisai_mobile/models/analytics_model.dart';
import 'package:larisai_mobile/models/transaction_model.dart';
import 'package:larisai_mobile/services/local_db_service.dart';
import 'package:larisai_mobile/services/export_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Analytics Models Defensive Parsing Tests', () {
    test('AnalyticsSummary parses valid and dynamic maps safely without TypeError', () {
      final Map<dynamic, dynamic> looseMap = {
        'total_revenue': 1500000.75,
        'total_orders': '42',
        'average_order_value': 35714,
        'daily_sales': [
          {'date': '2026-10-12', 'total_amount': 750000, 'order_count': 20},
          {'date': '2026-10-13', 'total_amount': '750000', 'order_count': '22'}
        ],
        'payment_methods': [
          {'payment_type': 'TUNAI', 'total_amount': 1200000, 'count': 35, 'percentage': 80.0},
          {'payment_type': 'QRIS', 'total_amount': '300000', 'count': '7', 'percentage': '20.0'}
        ]
      };

      final summary = AnalyticsSummary.fromJson(Map<String, dynamic>.from(looseMap));
      expect(summary.totalRevenue, equals(1500000));
      expect(summary.totalOrders, equals(42));
      expect(summary.averageOrderValue, equals(35714));
      expect(summary.dailySales.length, equals(2));
      expect(summary.dailySales.first.totalAmount, equals(750000));
      expect(summary.dailySales.first.orderCount, equals(20));
      expect(summary.paymentMethods.length, equals(2));
      expect(summary.paymentMethods.first.paymentType, equals('TUNAI'));
      expect(summary.paymentMethods.first.totalAmount, equals(1200000));
    });

    test('Transaction parses Map with dynamic types and items properly', () {
      final Map<dynamic, dynamic> looseTx = {
        'id': 'tx-12345',
        'invoice_no': 'INV-20261013-001',
        'customer_id': 'cust-01',
        'total_amount': 55000,
        'payment_type': 'TUNAI',
        'created_at': '2026-10-13T10:00:00Z',
        'items': [
          {
            'product_id': 'prod-1',
            'name': 'Aqua 600ml',
            'price': 3500,
            'quantity': 2,
            'subtotal': 7000
          }
        ]
      };

      final tx = Transaction.fromJson(Map<String, dynamic>.from(looseTx));
      expect(tx.id, equals('tx-12345'));
      expect(tx.invoiceNo, equals('INV-20261013-001'));
      expect(tx.totalAmount, equals(55000));
      expect(tx.items.length, equals(1));
      expect(tx.items.first.name, equals('Aqua 600ml'));
      expect(tx.items.first.subtotal, equals(7000));
    });
  });

  group('ZIP Full Backup & Restore Tests', () {
    test('Restore from ZIP correctly extracts images and restores SQLite with image_path', () async {
      final db = await LocalDbService.instance.database;
      expect(db.isOpen, isTrue);

      // 1. Prepare JSON dataset with image_path
      final testData = {
        'version': '1.0',
        'products': [
          {
            'id': 'zip-prod-1',
            'barcode': '8999999000111',
            'name': 'Kopi ABC Susu',
            'category': 'Minuman',
            'price': 3000,
            'stock': 40,
            'is_archived': 0,
            'image_path': 'kopi_abc.png',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }
        ],
        'transactions': [],
        'transaction_items': []
      };

      final jsonBytes = utf8.encode(jsonEncode(testData));
      final fakeImageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // PNG header

      // 2. Build ZIP archive
      final archive = Archive();
      archive.addFile(ArchiveFile('larisai_data.json', jsonBytes.length, jsonBytes));
      archive.addFile(ArchiveFile('product_images/kopi_abc.png', fakeImageBytes.length, fakeImageBytes));

      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);
      expect(zipBytes, isNotNull);

      // 3. Execute restoreFromZipBytes
      final result = await ExportService.instance.restoreFromZipBytes(zipBytes!);
      expect(result['products_restored'], equals(1));
      expect(result['images'], greaterThanOrEqualTo(1));

      // 4. Verify SQLite product record has image_path preserved
      final rows = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: ['zip-prod-1'],
      );
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['name'], equals('Kopi ABC Susu'));
      expect(rows.first['image_path'], equals('kopi_abc.png'));
    });
  });
}
