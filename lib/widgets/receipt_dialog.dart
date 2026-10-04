import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';
import '../services/printer_service.dart';
import '../services/store_profile_service.dart';

class ReceiptDialog extends StatelessWidget {
  final Transaction transaction;
  final int cashTendered;

  const ReceiptDialog({
    super.key,
    required this.transaction,
    this.cashTendered = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeProfile = StoreProfileService.instance.profile;
    final change = (cashTendered > transaction.totalAmount)
        ? cashTendered - transaction.totalAmount
        : 0;
    final activeCashier = storeProfile.ownerName.isNotEmpty ? storeProfile.ownerName : 'Kasir';
    final activeFooter = storeProfile.receiptFooter.isNotEmpty
        ? storeProfile.receiptFooter
        : 'Terima Kasih Atas Kunjungan Anda!';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header with Success Icon
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaksi Berhasil!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryHover : AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            'Struk pembayaran resmi LarisAI',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tactical Thermal Paper Slip Container
              Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : const Color(0xFFFBFBFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Store Header Info
                      Text(
                        storeProfile.storeName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (storeProfile.storeAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          storeProfile.storeAddress,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (storeProfile.storePhone.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          'Telp: ${storeProfile.storePhone}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      _buildDashedDivider(isDark),

                      // Transaction Metadata
                      _buildReceiptRow(
                        label: 'No. Invoice',
                        value: transaction.invoiceNo,
                        isDark: isDark,
                        valueStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      const SizedBox(height: 4),
                      _buildReceiptRow(
                        label: 'Tanggal & Waktu',
                        value: DateFormat('dd/MM/yyyy HH:mm:ss').format(transaction.createdAt),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 4),
                      _buildReceiptRow(
                        label: 'Kasir',
                        value: activeCashier,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Metode Bayar',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              transaction.paymentType,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.primaryHover : AppColors.primaryDark,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (transaction.customerId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _buildReceiptRow(
                          label: 'Keterangan',
                          value: transaction.customerId,
                          isDark: isDark,
                        ),
                      ],

                      _buildDashedDivider(isDark),

                      // Items Breakdown
                      ...transaction.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '  ${item.quantity} x ${CurrencyFormatter.format(item.price)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      _buildDashedDivider(isDark),

                      // Totals Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL BELANJA',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(transaction.totalAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: isDark ? const Color(0xFF34D399) : AppColors.primary,
                            ),
                          ),
                        ],
                      ),

                      if ((transaction.paymentType.toUpperCase() == 'TUNAI' || transaction.paymentType.toUpperCase() == 'CASH') && cashTendered > 0) ...[
                        const SizedBox(height: 6),
                        _buildReceiptRow(
                          label: 'Tunai Diterima',
                          value: CurrencyFormatter.format(cashTendered),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Kembalian',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(change),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],

                      _buildDashedDivider(isDark),

                      // Receipt Footer
                      Text(
                        activeFooter,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Simpan struk ini sebagai bukti transaksi sah',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: (isDark ? AppColors.darkTextMuted : AppColors.textMuted).withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons: Professional 2-Tier Layout
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Dual Utility Actions (Cetak Struk & Bagikan PDF)
                    Row(
                      children: [
                        // Cetak Struk (Thermal Printer)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight.withValues(alpha: 0.5),
                              foregroundColor: isDark ? AppColors.primaryHover : AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isDark ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            onPressed: () async {
                              await PrinterService.instance.printReceipt(
                                transaction: transaction,
                                cashTendered: cashTendered,
                              );
                            },
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text(
                              'Cetak Struk',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Bagikan Struk PDF
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
                              foregroundColor: isDark ? AppColors.darkTextMain : AppColors.textMain,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                              ),
                            ),
                            onPressed: () async {
                              await PrinterService.instance.shareReceiptPdf(
                                transaction: transaction,
                                cashTendered: cashTendered,
                              );
                            },
                            icon: Icon(
                              Icons.share_outlined,
                              size: 18,
                              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                            ),
                            label: const Text(
                              'Bagikan PDF',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 2: Full-width Primary Confirmation Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text(
                          'Selesai & Transaksi Baru',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow({
    required String label,
    required String value,
    required bool isDark,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            fontSize: 11.5,
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
        ),
      ],
    );
  }

  Widget _buildDashedDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 5.0;
          const dashSpace = 3.0;
          final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
          return Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
