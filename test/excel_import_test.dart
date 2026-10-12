import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:larisai_mobile/services/excel_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExcelImportService Tests', () {
    test('generateTemplateBytes generates valid Excel spreadsheet', () async {
      final service = ExcelImportService.instance;
      final bytes = await service.generateTemplateBytes();

      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);

      // Verifikasi parsing dari template yang baru digenerate
      final parseResult = service.parseExcelBytes(bytes);

      expect(parseResult.totalRows, equals(5));
      expect(parseResult.validProducts.length, equals(5));
      expect(parseResult.errors.isEmpty, isTrue);

      // Verifikasi item pertama (Indomie)
      final indomie = parseResult.validProducts[0];
      expect(indomie.barcode, equals('8992753112234'));
      expect(indomie.name, equals('Indomie Goreng Original 85g'));
      expect(indomie.category, equals('Makanan'));
      expect(indomie.price, equals(3500));
      expect(indomie.stock, equals(48));

      // Verifikasi item terakhir (Kerupuk tanpa barcode) mendapatkan auto-generated barcode
      final kerupuk = parseResult.validProducts[4];
      expect(kerupuk.barcode.startsWith('BRC-'), isTrue);
      expect(kerupuk.name, contains('Kerupuk'));
      expect(kerupuk.price, equals(1000));
      expect(kerupuk.stock, equals(50));
      expect(parseResult.warnings.isNotEmpty, isTrue); // Peringatan auto barcode
    });

    test('parseExcelBytes detects invalid rows and duplicate barcodes gracefully', () {
      final service = ExcelImportService.instance;

      // Buat file Excel kustom dengan anomali data
      final excel = Excel.createExcel();
      final sheet = excel['Katalog'];
      excel.setDefaultSheet('Katalog');

      // Header
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Barcode');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('Nama');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = TextCellValue('Kategori');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = TextCellValue('Harga');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value = TextCellValue('Stok');

      // Baris 1: Valid
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('1111');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('Produk A');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = TextCellValue('Umum');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = TextCellValue('Rp 15.000');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = IntCellValue(10);

      // Baris 2: Nama Kosong (Harus jadi Error)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('2222');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = TextCellValue('');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value = TextCellValue('Umum');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value = IntCellValue(5000);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2)).value = IntCellValue(5);

      // Baris 3: Harga 0 / Negatif (Harus jadi Error)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = TextCellValue('3333');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = TextCellValue('Produk C');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3)).value = TextCellValue('Umum');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3)).value = IntCellValue(0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3)).value = IntCellValue(20);

      // Baris 4: Barcode Duplikat '1111' (Harus diskip dengan warning)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = TextCellValue('1111');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = TextCellValue('Produk D Duplikat');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 4)).value = TextCellValue('Umum');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 4)).value = IntCellValue(20000);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 4)).value = IntCellValue(5);

      final bytes = excel.save()!;
      final result = service.parseExcelBytes(bytes);

      // Hanya Produk A yang valid
      expect(result.validProducts.length, equals(1));
      expect(result.validProducts.first.name, equals('Produk A'));
      expect(result.validProducts.first.price, equals(15000));

      // 2 Baris Error (Nama kosong di baris 2 & Harga 0 di baris 3)
      expect(result.errors.length, equals(2));

      // 1 Warning Barcode Duplikat di baris 4
      expect(result.warnings.any((w) => w.contains('duplikat')), isTrue);
    });
  });
}
