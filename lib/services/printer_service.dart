import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';
import 'store_profile_service.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._init();
  PrinterService._init();

  /// Generate a 58mm / 80mm Thermal Receipt Document
  Future<pw.Document> generateReceiptDocument({
    required Transaction transaction,
    required int cashTendered,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? cashierName,
    String? receiptFooter,
    bool is80mm = false,
  }) async {
    final profile = StoreProfileService.instance.profile;
    final activeStoreName = (storeName != null && storeName.isNotEmpty) ? storeName : profile.storeName;
    final activeStoreAddress = (storeAddress != null && storeAddress.isNotEmpty) ? storeAddress : profile.storeAddress;
    final activeStorePhone = (storePhone != null && storePhone.isNotEmpty) ? storePhone : profile.storePhone;
    final activeCashier = (cashierName != null && cashierName.isNotEmpty) ? cashierName : profile.ownerName;
    final activeFooter = (receiptFooter != null && receiptFooter.isNotEmpty) ? receiptFooter : profile.receiptFooter;

    final doc = pw.Document();
    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm:ss');

    final change = (cashTendered > transaction.totalAmount)
        ? cashTendered - transaction.totalAmount
        : 0;

    final dividerLine = is80mm ? '----------------------------------------' : '----------------------------';
    final doubleDividerLine = is80mm ? '========================================' : '============================';

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Store Header
              pw.Text(
                activeStoreName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                activeStoreAddress,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Telp: $activeStorePhone',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                dividerLine,
                style: const pw.TextStyle(fontSize: 8),
              ),

              // Transaction Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No: ${transaction.invoiceNo}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Kasir: $activeCashier', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tgl: ${dateFormatter.format(transaction.createdAt)}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Metode: ${transaction.paymentType}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (transaction.customerId.isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Pelanggan: ${transaction.customerId}', style: const pw.TextStyle(fontSize: 8)),
                ),
              pw.Text(
                dividerLine,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 4),

              // Items Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),

              // Items List
              ...transaction.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '  ${item.quantity} x ${currencyFormatter.format(item.price)}',
                            style: const pw.TextStyle(fontSize: 7.5),
                          ),
                          pw.Text(
                            currencyFormatter.format(item.subtotal),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Text(
                doubleDividerLine,
                style: const pw.TextStyle(fontSize: 8),
              ),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(
                    currencyFormatter.format(transaction.totalAmount),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ],
              ),

              if ((transaction.paymentType.toUpperCase() == 'TUNAI' || transaction.paymentType.toUpperCase() == 'CASH') && cashTendered > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tunai Diterima:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(currencyFormatter.format(cashTendered), style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kembalian:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(currencyFormatter.format(change), style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],

              pw.SizedBox(height: 8),
              pw.Text(
                dividerLine,
                style: const pw.TextStyle(fontSize: 8),
              ),

              // Footer
              pw.SizedBox(height: 4),
              pw.Text(
                activeFooter,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan.',
                style: const pw.TextStyle(fontSize: 6.5),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Powered by LarisAI POS & AI',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  /// Print Receipt Directly to Thermal / System Printer
  Future<bool> printReceipt({
    required Transaction transaction,
    required int cashTendered,
    String? storeName,
    bool is80mm = false,
  }) async {
    try {
      final doc = await generateReceiptDocument(
        transaction: transaction,
        cashTendered: cashTendered,
        storeName: storeName,
        is80mm: is80mm,
      );

      return await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Struk_${transaction.invoiceNo}',
      );
    } catch (e) {
      return false;
    }
  }

  /// Share Receipt as PDF bytes
  Future<void> shareReceiptPdf({
    required Transaction transaction,
    required int cashTendered,
    String? storeName,
  }) async {
    final doc = await generateReceiptDocument(
      transaction: transaction,
      cashTendered: cashTendered,
      storeName: storeName,
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Struk_${transaction.invoiceNo}.pdf',
    );
  }
}
