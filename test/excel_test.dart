import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:larisai_mobile/services/store_profile_service.dart';

void main() {
  group('StoreProfile & Excel Export Tests', () {
    test('StoreProfile default values and copyWith test', () {
      const defaultProf = StoreProfile.defaultProfile;
      expect(defaultProf.storeName, 'TOKO LARIS UMKM');
      expect(defaultProf.ownerName, 'Kasir 01');

      final updated = defaultProf.copyWith(
        storeName: 'Toko Berkah Mandiri',
        ownerName: 'Pak Haji Budi',
      );
      expect(updated.storeName, 'Toko Berkah Mandiri');
      expect(updated.ownerName, 'Pak Haji Budi');
      expect(updated.storeAddress, defaultProf.storeAddress);
    });

    test('Multi-sheet Excel Workbook generation test', () {
      final excel = Excel.createExcel();
      final sheet1 = excel['Ringkasan Penjualan'];
      final sheet2 = excel['Rincian Item Terjual'];
      excel.setDefaultSheet('Ringkasan Penjualan');
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('No Invoice');
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('Total Belanja (Rp)');
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('INV-20261003-001');
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = IntCellValue(45000);

      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('No Invoice');
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('Nama Produk');
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('INV-20261003-001');
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('Kopi Susu Gula Aren');

      final bytes = excel.save();
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);

      // Verify re-reading workbook
      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.sheets.containsKey('Ringkasan Penjualan'), isTrue);
      expect(decoded.sheets.containsKey('Rincian Item Terjual'), isTrue);
    });
  });
}
