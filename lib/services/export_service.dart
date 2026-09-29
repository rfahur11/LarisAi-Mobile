import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'local_db_service.dart';

class ExportService {
  static final ExportService instance = ExportService._init();
  ExportService._init();

  /// Export All Transactions to CSV File and Share / Save
  Future<String?> exportTransactionsCsv() async {
    final db = LocalDbService.instance;
    final transactions = await db.getTransactions(limit: 10000);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final dateOnly = DateFormat('yyyyMMdd_HHmm');

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('No Invoice,Waktu Transaksi,ID Pelanggan,Metode Pembayaran,Total Belanja (Rp),Jumlah Item,Rincian Produk');

    for (var tx in transactions) {
      final itemsSummary = tx.items.map((i) => '${i.name} (${i.quantity}x @${i.price})').join('; ');
      
      // Escape CSV values
      final invoice = _escapeCsv(tx.invoiceNo);
      final date = _escapeCsv(dateFormatter.format(tx.createdAt));
      final customer = _escapeCsv(tx.customerId.isEmpty ? 'Umum' : tx.customerId);
      final payment = _escapeCsv(tx.paymentType);
      final total = tx.totalAmount.toString();
      final itemCount = tx.items.fold<int>(0, (sum, i) => sum + i.quantity).toString();
      final itemsDetail = _escapeCsv(itemsSummary);

      buffer.writeln('$invoice,$date,$customer,$payment,$total,$itemCount,$itemsDetail');
    }

    // Save to file
    final dir = await _getExportDirectory();
    final fileName = 'LarisAI_Laporan_Transaksi_${dateOnly.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString(), encoding: utf8);

    // Share via share_plus
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: '📊 Laporan Penjualan LarisAI POS ($fileName)',
      subject: 'Laporan Penjualan CSV',
    );

    return file.path;
  }

  /// Export All Inventory Products to CSV
  Future<String?> exportInventoryCsv() async {
    final db = LocalDbService.instance;
    final products = await db.getProducts();
    final dateOnly = DateFormat('yyyyMMdd_HHmm');

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('ID Produk,Barcode,Nama Produk,Kategori,Harga Jual (Rp),Stok,Status Stok');

    for (var p in products) {
      final status = p.stock == 0 ? 'HABIS' : (p.stock < 10 ? 'MENIPIS' : 'AMAN');
      buffer.writeln('${_escapeCsv(p.id)},${_escapeCsv(p.barcode)},${_escapeCsv(p.name)},${_escapeCsv(p.category)},${p.price},${p.stock},$status');
    }

    final dir = await _getExportDirectory();
    final fileName = 'LarisAI_Katalog_Inventori_${dateOnly.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString(), encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: '📦 Katalog Inventori LarisAI POS ($fileName)',
      subject: 'Katalog Produk CSV',
    );

    return file.path;
  }

  /// Export Complete SQLite Database to JSON Backup
  Future<String?> exportFullBackupJson() async {
    final db = await LocalDbService.instance.database;
    final dateOnly = DateFormat('yyyyMMdd_HHmm');

    final products = await db.query('products');
    final transactions = await db.query('transactions');
    final txItems = await db.query('transaction_items');

    final backupData = {
      'app': 'LarisAI',
      'version': '1.0.0',
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'products': products,
        'transactions': transactions,
        'transaction_items': txItems,
      },
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);

    final dir = await _getExportDirectory();
    final fileName = 'LarisAI_Full_Backup_${dateOnly.format(DateTime.now())}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: '💾 Backup Database LarisAI POS Offline ($fileName)',
      subject: 'Backup Database LarisAI',
    );

    return file.path;
  }

  /// Restore Database from JSON String
  Future<Map<String, int>> restoreFromJson(String jsonContent) async {
    final Map<String, dynamic> parsed = jsonDecode(jsonContent);
    if (parsed['app'] != 'LarisAI' || parsed['data'] == null) {
      throw Exception('Format file backup tidak valid untuk LarisAI.');
    }

    final data = parsed['data'] as Map<String, dynamic>;
    final db = await LocalDbService.instance.database;

    int prodCount = 0;
    int txCount = 0;

    await db.transaction((txn) async {
      // 1. Restore Products
      if (data['products'] is List) {
        for (var item in (data['products'] as List)) {
          await txn.insert(
            'products',
            Map<String, dynamic>.from(item),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          prodCount++;
        }
      }

      // 2. Restore Transactions
      if (data['transactions'] is List) {
        for (var item in (data['transactions'] as List)) {
          await txn.insert(
            'transactions',
            Map<String, dynamic>.from(item),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          txCount++;
        }
      }

      // 3. Restore Items
      if (data['transaction_items'] is List) {
        for (var item in (data['transaction_items'] as List)) {
          await txn.insert(
            'transaction_items',
            Map<String, dynamic>.from(item),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    return {
      'products_restored': prodCount,
      'transactions_restored': txCount,
    };
  }

  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
