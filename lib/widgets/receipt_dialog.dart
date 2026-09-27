import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';

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
    final change = (cashTendered > transaction.totalAmount) 
        ? cashTendered - transaction.totalAmount 
        : 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 12),
              const Text(
                'Transaksi Berhasil!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const Text(
                'LarisAI Smart POS UMKM',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, thickness: 1),
              
              // Metadata
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('No. Invoice:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(transaction.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Waktu:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Metode Bayar:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      transaction.paymentType,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, thickness: 1),

              // Items
              ...transaction.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.name} x${item.quantity}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(item.subtotal),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),

              const Divider(color: AppColors.border, thickness: 1),
              const SizedBox(height: 8),

              // Totals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL BELANJA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    CurrencyFormatter.format(transaction.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                ],
              ),
              if (transaction.paymentType == 'TUNAI' && cashTendered > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Uang Diterima:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Text(CurrencyFormatter.format(cashTendered), style: const TextStyle(fontSize: 12)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 12)),
                    Text(CurrencyFormatter.format(change), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 12)),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🖨️ Mengirim perintah cetak struk via Bluetooth ESC/POS...'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Cetak Struk'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
