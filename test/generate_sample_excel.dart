import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final excel = Excel.createExcel();
  const sheetName = 'Produk Warung';
  final sheet = excel[sheetName];
  excel.setDefaultSheet(sheetName);
  if (excel.sheets.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }

  final headers = ['Barcode', 'Nama Produk', 'Kategori', 'Harga Jual', 'Harga Modal', 'Stok Awal'];
  for (var c = 0; c < headers.length; c++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value = TextCellValue(headers[c]);
  }

  final products = [
    ['8992753112234', 'Indomie Goreng Original 85g', 'Makanan', 3500, 3000, 50],
    ['8992753112241', 'Indomie Ayam Bawang 75g', 'Makanan', 3500, 3000, 40],
    ['8992753112258', 'Indomie Soto Mie 70g', 'Makanan', 3500, 3000, 35],
    ['8992772111029', 'Aqua Air Mineral 600ml', 'Minuman', 3500, 2700, 48],
    ['8992772111036', 'Aqua Air Mineral 1500ml', 'Minuman', 6500, 5200, 24],
    ['8999999002133', 'Teh Botol Sosro 450ml', 'Minuman', 5000, 4000, 24],
    ['8998866100124', 'Kopi Kapal Api Special Mix', 'Minuman', 2000, 1500, 60],
    ['8996001301014', 'Gula Pasir Gulaku 1kg', 'Sembako', 18500, 16500, 20],
    ['8991002103321', 'Minyak Goreng Sania 2L', 'Sembako', 36000, 32500, 12],
    ['8991001223019', 'Susu Ultra Milk Cokelat 250ml', 'Minuman', 6500, 5400, 30],
    ['8999999042211', 'Sabun Lifebuoy Total 10 85g', 'Kebersihan', 4500, 3600, 25],
    ['8999999043322', 'Pasta Gigi Pepsodent 190g', 'Kebersihan', 14000, 11500, 15],
    ['8999999044433', 'Deterjen Rinso Molto 770g', 'Kebersihan', 21000, 18000, 10],
    ['', 'Tahu Putih Segar (Otomatis Barcode)', 'Sembako', 5000, 4000, 15],
    ['', 'Tempe Mendoan Daun (Otomatis Barcode)', 'Sembako', 4000, 3000, 20],
  ];

  for (var r = 0; r < products.length; r++) {
    final p = products[r];
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = TextCellValue(p[0].toString());
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = TextCellValue(p[1].toString());
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = TextCellValue(p[2].toString());
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value = IntCellValue(p[3] as int);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1)).value = IntCellValue(p[4] as int);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r + 1)).value = IntCellValue(p[5] as int);
  }

  final bytes = excel.save()!;
  File('test_produk_warung.xlsx').writeAsBytesSync(bytes);
  print('Generated test_produk_warung.xlsx with ${products.length} products.');
}
