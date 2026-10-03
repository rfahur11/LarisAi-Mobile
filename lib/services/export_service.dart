import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'local_db_service.dart';

class ExportResult {
  final bool success;
  final String? filePath;
  final String? message;
  final bool isCancelled;

  ExportResult({
    required this.success,
    this.filePath,
    this.message,
    this.isCancelled = false,
  });
}

class ExportService {
  static final ExportService instance = ExportService._init();
  ExportService._init();

  bool get isDesktopPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  // --- SILENT AUTO-BACKUP (NO POPUPS / NO SHARING) ---
  /// Digunakan oleh sistem saat reset transaksi / reset pabrik agar data aman tanpa memunculkan dialog share
  Future<String?> createSilentBackupJson() async {
    try {
      final jsonStr = await generateBackupJsonString();
      final dateOnly = DateFormat('yyyyMMdd_HHmmss');
      final fileName = 'LarisAI_AutoBackup_${dateOnly.format(DateTime.now())}.json';

      final dir = await getDedicatedBackupDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr, encoding: utf8);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // --- DIRECTORY HELPERS ---
  Future<Directory> getDedicatedBackupDirectory() async {
    Directory baseDir;
    if (Platform.isAndroid) {
      baseDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final backupDir = Directory('${baseDir.path}/LarisAI_Backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Membuka folder di Windows Explorer / macOS Finder / Linux
  Future<void> openInExplorer(String path) async {
    try {
      final file = File(path);
      final exists = await file.exists();

      if (Platform.isWindows) {
        if (exists) {
          await Process.run('explorer.exe', ['/select,', path]);
        } else {
          await Process.run('explorer.exe', [path]);
        }
      } else if (Platform.isMacOS) {
        if (exists) {
          await Process.run('open', ['-R', path]);
        } else {
          await Process.run('open', [path]);
        }
      } else if (Platform.isLinux) {
        final target = exists ? file.parent.path : path;
        await Process.run('xdg-open', [target]);
      }
    } catch (_) {}
  }

  // --- CSV / JSON GENERATORS ---
  Future<String> generateTransactionsCsvString() async {
    final db = LocalDbService.instance;
    final transactions = await db.getTransactions(limit: 10000);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    final buffer = StringBuffer();
    buffer.writeln('No Invoice,Waktu Transaksi,ID Pelanggan,Metode Pembayaran,Total Belanja (Rp),Jumlah Item,Rincian Produk');

    for (var tx in transactions) {
      final itemsSummary = tx.items.map((i) => '${i.name} (${i.quantity}x @${i.price})').join('; ');
      final invoice = _escapeCsv(tx.invoiceNo);
      final date = _escapeCsv(dateFormatter.format(tx.createdAt));
      final customer = _escapeCsv(tx.customerId.isEmpty ? 'Umum' : tx.customerId);
      final payment = _escapeCsv(tx.paymentType);
      final total = tx.totalAmount.toString();
      final itemCount = tx.items.fold<int>(0, (sum, i) => sum + i.quantity).toString();
      final itemsDetail = _escapeCsv(itemsSummary);

      buffer.writeln('$invoice,$date,$customer,$payment,$total,$itemCount,$itemsDetail');
    }
    return buffer.toString();
  }

  Future<String> generateInventoryCsvString() async {
    final db = LocalDbService.instance;
    final products = await db.getProducts();

    final buffer = StringBuffer();
    buffer.writeln('ID Produk,Barcode,Nama Produk,Kategori,Harga Jual (Rp),Stok,Status Stok');

    for (var p in products) {
      final status = p.stock == 0 ? 'HABIS' : (p.stock < 10 ? 'MENIPIS' : 'AMAN');
      buffer.writeln('${_escapeCsv(p.id)},${_escapeCsv(p.barcode)},${_escapeCsv(p.name)},${_escapeCsv(p.category)},${p.price},${p.stock},$status');
    }
    return buffer.toString();
  }

  Future<String> generateBackupJsonString() async {
    final db = await LocalDbService.instance.database;
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

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  // --- EXCEL (.XLSX) GENERATORS ---
  Future<List<int>?> generateTransactionsExcelBytes() async {
    final db = LocalDbService.instance;
    final transactions = await db.getTransactions(limit: 10000);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    final excel = Excel.createExcel();
    final summarySheet = excel['Ringkasan Penjualan'];
    final itemsSheet = excel['Rincian Item Terjual'];
    excel.setDefaultSheet('Ringkasan Penjualan');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Sheet 1 Headers
    final summaryHeaders = [
      'No Invoice',
      'Waktu Transaksi',
      'ID Pelanggan',
      'Metode Pembayaran',
      'Total Belanja (Rp)',
      'Jumlah Item',
      'Rincian Ringkas'
    ];
    for (var c = 0; c < summaryHeaders.length; c++) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
          TextCellValue(summaryHeaders[c]);
    }

    // Sheet 2 Headers
    final itemHeaders = [
      'No Invoice',
      'Waktu Transaksi',
      'ID Produk',
      'Nama Produk',
      'Qty',
      'Harga Satuan (Rp)',
      'Subtotal (Rp)'
    ];
    for (var c = 0; c < itemHeaders.length; c++) {
      itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
          TextCellValue(itemHeaders[c]);
    }

    int itemRowIdx = 1;
    for (var r = 0; r < transactions.length; r++) {
      final tx = transactions[r];
      final itemsSummary = tx.items.map((i) => '${i.name} (${i.quantity}x @${i.price})').join('; ');
      final totalQty = tx.items.fold<int>(0, (sum, i) => sum + i.quantity);

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value =
          TextCellValue(tx.invoiceNo);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value =
          TextCellValue(dateFormatter.format(tx.createdAt));
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value =
          TextCellValue(tx.customerId.isEmpty ? 'Umum' : tx.customerId);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value =
          TextCellValue(tx.paymentType);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1)).value =
          IntCellValue(tx.totalAmount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r + 1)).value =
          IntCellValue(totalQty);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r + 1)).value =
          TextCellValue(itemsSummary);

      // Populate Items Sheet
      for (var item in tx.items) {
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: itemRowIdx)).value =
            TextCellValue(tx.invoiceNo);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: itemRowIdx)).value =
            TextCellValue(dateFormatter.format(tx.createdAt));
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: itemRowIdx)).value =
            TextCellValue(item.productId);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: itemRowIdx)).value =
            TextCellValue(item.name);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: itemRowIdx)).value =
            IntCellValue(item.quantity);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: itemRowIdx)).value =
            IntCellValue(item.price);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: itemRowIdx)).value =
            IntCellValue(item.subtotal);
        itemRowIdx++;
      }
    }

    return excel.save();
  }

  Future<List<int>?> generateInventoryExcelBytes() async {
    final db = LocalDbService.instance;
    final products = await db.getProducts();

    final excel = Excel.createExcel();
    final sheet = excel['Katalog Inventori'];
    excel.setDefaultSheet('Katalog Inventori');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headers = [
      'ID Produk',
      'Barcode',
      'Nama Produk',
      'Kategori',
      'Harga Jual (Rp)',
      'Stok Saat Ini',
      'Status Stok'
    ];
    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
          TextCellValue(headers[c]);
    }

    for (var r = 0; r < products.length; r++) {
      final p = products[r];
      final status = p.stock == 0 ? 'HABIS' : (p.stock < 10 ? 'MENIPIS' : 'AMAN');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = TextCellValue(p.id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = TextCellValue(p.barcode);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = TextCellValue(p.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value = TextCellValue(p.category);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1)).value = IntCellValue(p.price);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r + 1)).value = IntCellValue(p.stock);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r + 1)).value = TextCellValue(status);
    }

    return excel.save();
  }

  // --- EXPORT TRANSACTIONS ---
  Future<ExportResult> exportTransactionsCsv({bool chooseLocalFolder = false}) async {
    final dateOnly = DateFormat('yyyyMMdd_HHmm');
    final fileName = 'LarisAI_Laporan_Transaksi_${dateOnly.format(DateTime.now())}.csv';
    final content = await generateTransactionsCsvString();

    if (chooseLocalFolder || isDesktopPlatform) {
      return await _saveViaLocalDialog(
        defaultFileName: fileName,
        content: content,
        extension: 'csv',
        dialogTitle: 'Simpan Laporan Transaksi CSV',
      );
    } else {
      return await _saveAndShare(
        fileName: fileName,
        content: content,
        mimeType: 'text/csv',
        shareText: '📊 Laporan Penjualan LarisAI POS ($fileName)',
      );
    }
  }

  // --- EXPORT INVENTORY ---
  Future<ExportResult> exportInventoryCsv({bool chooseLocalFolder = false}) async {
    final dateOnly = DateFormat('yyyyMMdd_HHmm');
    final fileName = 'LarisAI_Katalog_Inventori_${dateOnly.format(DateTime.now())}.csv';
    final content = await generateInventoryCsvString();

    if (chooseLocalFolder || isDesktopPlatform) {
      return await _saveViaLocalDialog(
        defaultFileName: fileName,
        content: content,
        extension: 'csv',
        dialogTitle: 'Simpan Katalog Inventori CSV',
      );
    } else {
      return await _saveAndShare(
        fileName: fileName,
        content: content,
        mimeType: 'text/csv',
        shareText: '📦 Katalog Inventori LarisAI POS ($fileName)',
      );
    }
  }

  // --- EXPORT TRANSACTIONS (.XLSX) ---
  Future<ExportResult> exportTransactionsExcel({bool chooseLocalFolder = false}) async {
    final dateOnly = DateFormat('yyyyMMdd_HHmm');
    final fileName = 'LarisAI_Laporan_Transaksi_${dateOnly.format(DateTime.now())}.xlsx';
    final bytes = await generateTransactionsExcelBytes();
    if (bytes == null || bytes.isEmpty) {
      return ExportResult(success: false, message: 'Gagal membuat file Excel.');
    }

    if (chooseLocalFolder || isDesktopPlatform) {
      return await _saveBytesViaLocalDialog(
        defaultFileName: fileName,
        bytes: bytes,
        extension: 'xlsx',
        dialogTitle: 'Simpan Laporan Transaksi Excel (.xlsx)',
      );
    } else {
      return await _saveBytesAndShare(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        shareText: '📊 Laporan Penjualan Excel LarisAI POS ($fileName)',
      );
    }
  }

  // --- EXPORT INVENTORY (.XLSX) ---
  Future<ExportResult> exportInventoryExcel({bool chooseLocalFolder = false}) async {
    final dateOnly = DateFormat('yyyyMMdd_HHmm');
    final fileName = 'LarisAI_Katalog_Inventori_${dateOnly.format(DateTime.now())}.xlsx';
    final bytes = await generateInventoryExcelBytes();
    if (bytes == null || bytes.isEmpty) {
      return ExportResult(success: false, message: 'Gagal membuat file Excel.');
    }

    if (chooseLocalFolder || isDesktopPlatform) {
      return await _saveBytesViaLocalDialog(
        defaultFileName: fileName,
        bytes: bytes,
        extension: 'xlsx',
        dialogTitle: 'Simpan Katalog Inventori Excel (.xlsx)',
      );
    } else {
      return await _saveBytesAndShare(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        shareText: '📦 Katalog Inventori Excel LarisAI POS ($fileName)',
      );
    }
  }

  // --- EXPORT FULL BACKUP JSON ---
  Future<ExportResult> exportFullBackupJson({bool chooseLocalFolder = false}) async {
    final dateOnly = DateFormat('yyyyMMdd_HHmm');
    final fileName = 'LarisAI_Full_Backup_${dateOnly.format(DateTime.now())}.json';
    final content = await generateBackupJsonString();

    if (chooseLocalFolder || isDesktopPlatform) {
      return await _saveViaLocalDialog(
        defaultFileName: fileName,
        content: content,
        extension: 'json',
        dialogTitle: 'Simpan Cadangan Database LarisAI (.json)',
      );
    } else {
      return await _saveAndShare(
        fileName: fileName,
        content: content,
        mimeType: 'application/json',
        shareText: '💾 Backup Database LarisAI POS Offline ($fileName)',
      );
    }
  }

  // --- SAVE VIA NATIVE DIALOG (DESKTOP / LOCAL STORAGE) ---
  Future<ExportResult> _saveViaLocalDialog({
    required String defaultFileName,
    required String content,
    required String extension,
    required String dialogTitle,
  }) async {
    try {
      String? selectedPath;

      if (isDesktopPlatform) {
        selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: dialogTitle,
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: [extension],
        );
      }

      // If user cancelled picker or picker is not supported
      if (selectedPath == null) {
        if (isDesktopPlatform) {
          return ExportResult(success: false, isCancelled: true, message: 'Penyimpanan dibatalkan.');
        }
        // Fallback for mobile
        final dir = await getDedicatedBackupDirectory();
        selectedPath = '${dir.path}/$defaultFileName';
      }

      // Ensure proper extension
      if (!selectedPath.toLowerCase().endsWith('.$extension')) {
        selectedPath = '$selectedPath.$extension';
      }

      final file = File(selectedPath);
      await file.writeAsString(content, encoding: utf8);

      return ExportResult(
        success: true,
        filePath: file.path,
        message: 'File berhasil disimpan di:\n${file.path}',
      );
    } catch (e) {
      return ExportResult(success: false, message: 'Gagal menyimpan file: $e');
    }
  }

  // --- SAVE AND SHARE (MOBILE DEFAULT) ---
  Future<ExportResult> _saveAndShare({
    required String fileName,
    required String content,
    required String mimeType,
    required String shareText,
  }) async {
    try {
      final dir = await getDedicatedBackupDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content, encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        text: shareText,
        subject: fileName,
      );

      return ExportResult(
        success: true,
        filePath: file.path,
        message: 'File tersimpan di:\n${file.path}',
      );
    } catch (e) {
      return ExportResult(success: false, message: 'Gagal membagikan file: $e');
    }
  }

  // --- SAVE BYTES VIA NATIVE DIALOG (DESKTOP) ---
  Future<ExportResult> _saveBytesViaLocalDialog({
    required String defaultFileName,
    required List<int> bytes,
    required String extension,
    required String dialogTitle,
  }) async {
    try {
      String? selectedPath;

      if (isDesktopPlatform) {
        selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: dialogTitle,
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: [extension],
        );
      }

      if (selectedPath == null) {
        if (isDesktopPlatform) {
          return ExportResult(success: false, isCancelled: true, message: 'Penyimpanan dibatalkan.');
        }
        final dir = await getDedicatedBackupDirectory();
        selectedPath = '${dir.path}/$defaultFileName';
      }

      if (!selectedPath.toLowerCase().endsWith('.$extension')) {
        selectedPath = '$selectedPath.$extension';
      }

      final file = File(selectedPath);
      await file.writeAsBytes(bytes);

      return ExportResult(
        success: true,
        filePath: file.path,
        message: 'File Excel berhasil disimpan di:\n${file.path}',
      );
    } catch (e) {
      return ExportResult(success: false, message: 'Gagal menyimpan file Excel: $e');
    }
  }

  // --- SAVE BYTES AND SHARE (MOBILE) ---
  Future<ExportResult> _saveBytesAndShare({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    required String shareText,
  }) async {
    try {
      final dir = await getDedicatedBackupDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        text: shareText,
        subject: fileName,
      );

      return ExportResult(
        success: true,
        filePath: file.path,
        message: 'File Excel tersimpan di:\n${file.path}',
      );
    } catch (e) {
      return ExportResult(success: false, message: 'Gagal membagikan file Excel: $e');
    }
  }

  // --- RESTORE DATABASE ---
  /// Membuka file picker untuk memilih file .json backup dari komputer / HP dan memulihkan database
  Future<Map<String, dynamic>?> pickAndRestoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pilih File Cadangan LarisAI (.json)',
      type: Platform.isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: Platform.isAndroid ? null : ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final platformFile = result.files.single;
    final fileName = platformFile.name.toLowerCase();
    if (!fileName.endsWith('.json')) {
      throw Exception('Format file harus berupa .json (Dipilih: ${platformFile.name})');
    }

    String jsonContent;
    if (platformFile.bytes != null && platformFile.bytes!.isNotEmpty) {
      jsonContent = utf8.decode(platformFile.bytes!);
    } else if (platformFile.path != null) {
      final file = File(platformFile.path!);
      jsonContent = await file.readAsString(encoding: utf8);
    } else {
      throw Exception('Tidak dapat membaca isi file cadangan yang dipilih.');
    }

    final counts = await restoreFromJson(jsonContent);
    return {
      'counts': counts,
      'name': platformFile.name,
      'path': platformFile.path ?? platformFile.name,
    };
  }

  /// Restore Database from JSON String
  Future<Map<String, int>> restoreFromJson(String jsonContent) async {
    final dynamic decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('File cadangan tidak valid (bukan format JSON object).');
    }

    Map<String, dynamic> data;
    if (decoded.containsKey('data') && decoded['data'] is Map) {
      data = Map<String, dynamic>.from(decoded['data']);
    } else if (decoded.containsKey('products') || decoded.containsKey('transactions')) {
      data = decoded;
    } else {
      throw Exception('Format file cadangan tidak valid: tidak ditemukan data produk atau transaksi.');
    }

    final db = await LocalDbService.instance.database;

    int prodCount = 0;
    int txCount = 0;

    await db.transaction((txn) async {
      // 1. Hapus seluruh data lama untuk menjamin kebersihan snapshot dan mencegah konflik id/foreign key
      await txn.delete('transaction_items');
      await txn.delete('transactions');
      await txn.delete('products');

      // 2. Pulihkan Produk
      if (data['products'] is List) {
        for (var raw in (data['products'] as List)) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);

          final sanitizedProduct = {
            'id': item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'barcode': item['barcode']?.toString() ?? '',
            'name': item['name']?.toString() ?? 'Produk Tanpa Nama',
            'category': item['category']?.toString() ?? 'Umum',
            'price': (item['price'] is num) ? (item['price'] as num).toInt() : int.tryParse(item['price']?.toString() ?? '0') ?? 0,
            'stock': (item['stock'] is num) ? (item['stock'] as num).toInt() : int.tryParse(item['stock']?.toString() ?? '0') ?? 0,
            'is_archived': (item['is_archived'] == 1 || item['is_archived'] == true) ? 1 : 0,
            'created_at': item['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'updated_at': item['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
          };

          await txn.insert(
            'products',
            sanitizedProduct,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          prodCount++;
        }
      }

      // 3. Pulihkan Riwayat Transaksi
      if (data['transactions'] is List) {
        for (var raw in (data['transactions'] as List)) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);

          final sanitizedTx = {
            'id': item['id']?.toString() ?? '',
            'invoice_no': item['invoice_no']?.toString() ?? '',
            'customer_id': item['customer_id']?.toString() ?? '',
            'total_amount': (item['total_amount'] is num) ? (item['total_amount'] as num).toInt() : int.tryParse(item['total_amount']?.toString() ?? '0') ?? 0,
            'payment_type': item['payment_type']?.toString() ?? 'Tunai',
            'created_at': item['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          };

          final txId = sanitizedTx['id']?.toString() ?? '';
          if (txId.isNotEmpty) {
            await txn.insert(
              'transactions',
              sanitizedTx,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            txCount++;
          }
        }
      }

      // 4. Pulihkan Rincian Item Transaksi
      if (data['transaction_items'] is List) {
        for (var raw in (data['transaction_items'] as List)) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);

          final sanitizedItem = {
            'transaction_id': item['transaction_id']?.toString() ?? '',
            'product_id': item['product_id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'price': (item['price'] is num) ? (item['price'] as num).toInt() : int.tryParse(item['price']?.toString() ?? '0') ?? 0,
            'quantity': (item['quantity'] is num) ? (item['quantity'] as num).toInt() : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1,
            'subtotal': (item['subtotal'] is num) ? (item['subtotal'] as num).toInt() : int.tryParse(item['subtotal']?.toString() ?? '0') ?? 0,
          };

          final parentTxId = sanitizedItem['transaction_id']?.toString() ?? '';
          if (parentTxId.isNotEmpty) {
            await txn.insert(
              'transaction_items',
              sanitizedItem,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    });

    return {
      'products_restored': prodCount,
      'transactions_restored': txCount,
    };
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
