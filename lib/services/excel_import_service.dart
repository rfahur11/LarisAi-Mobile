import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product_model.dart';
import 'api_service.dart';

class ExcelParseResult {
  final int totalRows;
  final List<Product> validProducts;
  final List<String> errors;
  final List<String> warnings;

  ExcelParseResult({
    required this.totalRows,
    required this.validProducts,
    required this.errors,
    required this.warnings,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasValidData => validProducts.isNotEmpty;
}

class ExcelImportService {
  static final ExcelImportService instance = ExcelImportService._internal();
  ExcelImportService._internal();

  final ApiService _apiService = ApiService();

  // ==========================================
  // 1. GENERATE TEMPLATE EXCEL (.XLSX)
  // ==========================================
  Future<List<int>?> generateTemplateBytes() async {
    final excel = Excel.createExcel();
    const sheetName = 'Template Produk LarisAI';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headers = [
      'Barcode',
      'Nama Produk',
      'Kategori',
      'Harga Jual',
      'Harga Modal',
      'Stok Awal',
    ];

    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
          TextCellValue(headers[c]);
    }

    // Sampel FMCG populer Indonesia sebagai panduan pedagang
    final sampleRows = [
      ['8992753112234', 'Indomie Goreng Original 85g', 'Makanan', 3500, 3000, 48],
      ['8992772111029', 'Aqua Air Mineral 600ml', 'Minuman', 3500, 2800, 24],
      ['8996001301014', 'Gulaku Gula Pasir Tebu 1kg', 'Sembako', 18500, 16500, 10],
      ['8998866100124', 'Kopi Kapal Api Special Mix', 'Minuman', 2000, 1500, 60],
      ['', 'Kerupuk Putih Kaleng (Contoh Barcode Kosong)', 'Camilan', 1000, 700, 50],
    ];

    for (var r = 0; r < sampleRows.length; r++) {
      final row = sampleRows[r];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value =
          TextCellValue(row[0].toString());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value =
          TextCellValue(row[1].toString());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value =
          TextCellValue(row[2].toString());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value =
          IntCellValue(row[3] as int);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1)).value =
          IntCellValue(row[4] as int);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r + 1)).value =
          IntCellValue(row[5] as int);
    }

    return excel.save();
  }

  /// Membagikan / menyimpan template Excel ke penyimpanan pengguna
  Future<String?> downloadOrShareTemplate() async {
    final bytes = await generateTemplateBytes();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Gagal membuat template file Excel.');
    }

    const fileName = 'larisai_template_import_produk.xlsx';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan Template Excel Produk LarisAI',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (selectedPath != null) {
        String finalPath = selectedPath;
        if (!finalPath.toLowerCase().endsWith('.xlsx')) {
          finalPath = '$finalPath.xlsx';
        }
        final file = File(finalPath);
        await file.writeAsBytes(bytes);
        return finalPath;
      }
      return null;
    } else {
      // Mobile (Android / iOS): Simpan ke cache & Share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: fileName,
          )
        ],
        subject: 'Template Import Produk LarisAI',
        text: '📥 Unduh & isi template ini dengan Excel/Sheets, lalu import ke LarisAI POS.',
      );
      return file.path;
    }
  }

  // ==========================================
  // 2. PARSE EXCEL BYTES KE LIST PRODUK
  // ==========================================
  ExcelParseResult parseExcelBytes(
    List<int> bytes, {
    int maxBytes = 5 * 1024 * 1024, // 5 MB DoS Guard
    int maxRows = 5000,              // 5,000 Rows OOM Guard
  }) {
    // 1. DoS File Size Check
    if (bytes.length > maxBytes) {
      final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return ExcelParseResult(
        totalRows: 0,
        validProducts: [],
        errors: [
          'File terlalu besar ($sizeMb MB). Batas maksimum file adalah 5 MB untuk mencegah beban memori perangkat berlebih.',
        ],
        warnings: [],
      );
    }

    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ExcelParseResult(
        totalRows: 0,
        validProducts: [],
        errors: ['File Excel tidak memiliki sheet yang valid.'],
        warnings: [],
      );
    }

    // Ambil sheet pertama atau sheet dengan data
    Sheet? targetSheet;
    for (var tableName in excel.tables.keys) {
      final s = excel.tables[tableName];
      if (s != null && s.maxRows > 1) {
        targetSheet = s;
        break;
      }
    }
    targetSheet ??= excel.tables.values.first;

    final rows = targetSheet.rows;
    if (rows.isEmpty || rows.length < 2) {
      return ExcelParseResult(
        totalRows: 0,
        validProducts: [],
        errors: ['File Excel kosong atau hanya berisi baris header tanpa data produk.'],
        warnings: [],
      );
    }

    // 2. DoS Row Count Check
    if (rows.length > maxRows) {
      return ExcelParseResult(
        totalRows: rows.length - 1,
        validProducts: [],
        errors: [
          'Jumlah baris (${rows.length}) melebihi batas maksimum aman ($maxRows baris). Mohon pisah file menjadi beberapa bagian untuk mencegah aplikasi kehabisan memori.',
        ],
        warnings: [],
      );
    }

    // Pemetaan indeks kolom fleksibel berdasarkan header
    final headerRow = rows[0];
    int colBarcode = 0;
    int colName = 1;
    int colCategory = 2;
    int colPrice = 3;
    int colStock = 5;

    for (var c = 0; c < headerRow.length; c++) {
      final headerTitle = _cellToString(headerRow[c]?.value, sanitize: false).toLowerCase();
      if (headerTitle.contains('barcode') || headerTitle.contains('kode')) {
        colBarcode = c;
      } else if (headerTitle.contains('nama') || headerTitle.contains('produk') || headerTitle.contains('item')) {
        colName = c;
      } else if (headerTitle.contains('kategori') || headerTitle.contains('category')) {
        colCategory = c;
      } else if (headerTitle.contains('jual') || (headerTitle.contains('harga') && !headerTitle.contains('modal'))) {
        colPrice = c;
      } else if (headerTitle.contains('stok') || headerTitle.contains('stock') || headerTitle.contains('qty')) {
        colStock = c;
      }
    }

    final List<Product> validProducts = [];
    final List<String> errors = [];
    final List<String> warnings = [];
    final Set<String> seenBarcodes = {};
    int generatedBarcodeSeq = 1;
    final nowTimestamp = DateTime.now().millisecondsSinceEpoch;

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      // Cek apakah seluruh baris kosong
      bool allEmpty = true;
      for (var cell in row) {
        if (_cellToString(cell?.value, sanitize: false).isNotEmpty) {
          allEmpty = false;
          break;
        }
      }
      if (allEmpty) continue;

      final rowNum = r + 1; // 1-indexed untuk tampilan ramah pengguna
      final rawName = colName < row.length ? _cellToString(row[colName]?.value) : '';
      if (rawName.isEmpty) {
        errors.add('Baris $rowNum: Nama produk wajib diisi (saat ini kosong).');
        continue;
      }

      final rawPrice = colPrice < row.length ? _parseNumeric(row[colPrice]?.value) : 0;
      if (rawPrice <= 0) {
        errors.add('Baris $rowNum: Harga jual produk "$rawName" tidak valid (harus > 0).');
        continue;
      }

      var rawBarcode = colBarcode < row.length ? _cellToString(row[colBarcode]?.value) : '';
      if (rawBarcode.isEmpty) {
        // Auto-generate barcode jika pengguna membiarkan kosong
        rawBarcode = 'BRC-$nowTimestamp-$generatedBarcodeSeq';
        generatedBarcodeSeq++;
        warnings.add('Baris $rowNum: Barcode produk "$rawName" dibuat otomatis ($rawBarcode).');
      }

      // Cek duplikasi barcode di dalam file yang sama
      if (seenBarcodes.contains(rawBarcode)) {
        warnings.add('Baris $rowNum: Barcode duplikat "$rawBarcode" untuk "$rawName" dilewati.');
        continue;
      }
      seenBarcodes.add(rawBarcode);

      final rawCategory = colCategory < row.length ? _cellToString(row[colCategory]?.value) : 'Umum';
      final cleanCategory = rawCategory.isNotEmpty ? rawCategory : 'Umum';
      final rawStock = colStock < row.length ? _parseNumeric(row[colStock]?.value, defaultValue: 0) : 0;

      validProducts.add(Product(
        id: '',
        barcode: rawBarcode,
        name: rawName,
        category: cleanCategory,
        price: rawPrice,
        stock: rawStock,
        isArchived: false,
        imagePath: '',
      ));
    }

    return ExcelParseResult(
      totalRows: rows.length - 1,
      validProducts: validProducts,
      errors: errors,
      warnings: warnings,
    );
  }

  // ==========================================
  // 3. EKSEKUSI PENYIMPANAN IMPORT
  // ==========================================
  Future<Map<String, dynamic>> executeBulkImport(List<Product> products) async {
    return await _apiService.createProductsBulk(products);
  }

  /// Sanitasi teks sel untuk mencegah Formula / DDE Injection (CWE-1236).
  /// Mencegah eksekusi script berbahaya jika data diekspor kembali ke spreadsheet.
  static String sanitizeFormulaInjection(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // Deteksi awalan formula berbahaya: =, +, -, @
    final firstChar = trimmed[0];
    if (firstChar == '=' || firstChar == '+' || firstChar == '-' || firstChar == '@') {
      // Kecualikan format angka minus murni (contoh: "-500" atau "-10.5")
      if (firstChar == '-' && RegExp(r'^-\d+(\.\d+)?$').hasMatch(trimmed)) {
        return trimmed;
      }
      return "'$trimmed";
    }
    return trimmed;
  }

  // Helper konversi teks & nilai sel
  String _cellToString(dynamic cellValue, {bool sanitize = true}) {
    if (cellValue == null) return '';
    String res = '';
    if (cellValue is TextCellValue) {
      res = cellValue.value.toString().trim();
    } else if (cellValue is IntCellValue) {
      res = cellValue.value.toString();
    } else if (cellValue is DoubleCellValue) {
      res = cellValue.value.toInt().toString();
    } else if (cellValue is DateCellValue) {
      res = cellValue.asDateTimeLocal().toIso8601String();
    } else {
      res = cellValue.toString().trim();
    }
    return sanitize ? sanitizeFormulaInjection(res) : res;
  }

  int _parseNumeric(dynamic cellValue, {int defaultValue = 0}) {
    if (cellValue == null) return defaultValue;
    if (cellValue is IntCellValue) return cellValue.value;
    if (cellValue is DoubleCellValue) return cellValue.value.toInt();
    final str = _cellToString(cellValue, sanitize: false);
    final digitsOnly = str.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return defaultValue;
    return int.tryParse(digitsOnly) ?? defaultValue;
  }
}
