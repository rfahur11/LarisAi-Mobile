import 'dart:convert';
import 'dart:io';
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
        selectedPath = await FilePicker.saveFile(
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

  // --- RESTORE DATABASE ---
  /// Membuka file picker untuk memilih file .json backup dari komputer / HP dan memulihkan database
  Future<Map<String, dynamic>?> pickAndRestoreBackup() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Pilih File Cadangan LarisAI (.json)',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final filePath = result.files.single.path!;
    final file = File(filePath);
    final jsonContent = await file.readAsString(encoding: utf8);

    final counts = await restoreFromJson(jsonContent);
    return {
      'counts': counts,
      'path': filePath,
    };
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

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
