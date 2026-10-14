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
    PdfPageFormat? pageFormat,
    bool forceThermalRoll = true,
  }) async {
    final profile = StoreProfileService.instance.profile;
    final activeStoreName = (storeName != null && storeName.isNotEmpty) ? storeName : profile.storeName;
    final activeStoreAddress = (storeAddress != null && storeAddress.isNotEmpty) ? storeAddress : profile.storeAddress;
    final activeStorePhone = (storePhone != null && storePhone.isNotEmpty) ? storePhone : profile.storePhone;
    final activeCashier = (cashierName != null && cashierName.isNotEmpty) ? cashierName : profile.ownerName;
    final activeFooter = (receiptFooter != null && receiptFooter.isNotEmpty) ? receiptFooter : profile.receiptFooter;

    final doc = pw.Document();
    final thermalRoll = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final effectivePageFormat = (forceThermalRoll || pageFormat == null) ? thermalRoll : pageFormat;
    final isWidePaper = effectivePageFormat.width > 80 * PdfPageFormat.mm;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm:ss');

    final change = (cashTendered > transaction.totalAmount)
        ? cashTendered - transaction.totalAmount
        : 0;

    doc.addPage(
      pw.Page(
        pageFormat: effectivePageFormat,
        margin: isWidePaper
            ? const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24)
            : const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        build: (pw.Context context) {
          final receiptBody = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Store Header
              pw.Center(
                child: pw.Text(
                  activeStoreName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (activeStoreAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    activeStoreAddress,
                    style: const pw.TextStyle(fontSize: 7.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              if (activeStorePhone.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    'Telp: $activeStorePhone',
                    style: const pw.TextStyle(fontSize: 7.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8, color: PdfColors.grey700),
              pw.SizedBox(height: 3),

              // Transaction Metadata (Separated key-value rows to eliminate collisions)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No. Invoice:', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(transaction.invoiceNo, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Waktu:', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(dateFormatter.format(transaction.createdAt), style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kasir:', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(activeCashier, style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Metode Bayar:', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(transaction.paymentType, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (transaction.customerId.isNotEmpty) ...[
                pw.SizedBox(height: 1.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Pelanggan:', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text(transaction.customerId, style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8, color: PdfColors.grey700),
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
              pw.Divider(thickness: 1.0, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
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
                    pw.Text('Tunai Diterima:', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text(currencyFormatter.format(cashTendered), style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kembalian:', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text(currencyFormatter.format(change), style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8, color: PdfColors.grey700),
              pw.SizedBox(height: 4),

              // Tactile Merchant Footer (Option A)
              pw.Center(
                child: pw.Text(
                  activeFooter.isNotEmpty ? activeFooter : 'Terima Kasih Atas Kunjungan Anda!',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Senang melayani Anda! Semoga hari Anda menyenangkan & penuh berkah.',
                  style: const pw.TextStyle(fontSize: 6.5),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  '~ Sampai Jumpa Kembali ~',
                  style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );

          if (isWidePaper) {
            // When previewing or printing on wide paper (A4 / Letter / Android Print Spooler preview),
            // CENTER the thermal slip horizontally so margins on the left and right are perfectly balanced!
            return pw.Center(
              child: pw.Container(
                width: is80mm ? 76 * PdfPageFormat.mm : 56 * PdfPageFormat.mm,
                child: receiptBody,
              ),
            );
          }

          return receiptBody;
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
      final thermalFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
      return await Printing.layoutPdf(
        format: thermalFormat,
        dynamicLayout: false,
        onLayout: (PdfPageFormat format) async {
          // Force compact thermal roll format (roll57 / roll80) so mobile print spoolers and PDF viewers
          // do NOT shrink the receipt into a tiny speck on a 30cm A4 sheet!
          final doc = await generateReceiptDocument(
            transaction: transaction,
            cashTendered: cashTendered,
            storeName: storeName,
            is80mm: is80mm,
            forceThermalRoll: true,
          );
          return doc.save();
        },
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
    bool is80mm = false,
  }) async {
    final doc = await generateReceiptDocument(
      transaction: transaction,
      cashTendered: cashTendered,
      storeName: storeName,
      is80mm: is80mm,
      forceThermalRoll: true,
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Struk_${transaction.invoiceNo}.pdf',
    );
  }
}
