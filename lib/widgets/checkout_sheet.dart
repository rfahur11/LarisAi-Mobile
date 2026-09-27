import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../providers/pos_provider.dart';
import 'receipt_dialog.dart';

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  String _selectedPayment = 'TUNAI'; // TUNAI, QRIS, DEBIT
  int _cashTendered = 0;
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final total = Provider.of<PosProvider>(context, listen: false).totalAmount;
    _cashTendered = total;
    _cashController.text = total.toString();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  void _setCash(int amount) {
    setState(() {
      _cashTendered = amount;
      _cashController.text = amount.toString();
    });
  }

  Future<void> _handlePay() async {
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final total = posProvider.totalAmount;

    if (_selectedPayment == 'TUNAI' && _cashTendered < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uang yang dibayarkan kurang dari total belanja!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final transaction = await posProvider.processCheckout(
      paymentType: _selectedPayment,
      customerId: _customerController.text.trim(),
    );

    setState(() => _isProcessing = false);

    if (mounted && transaction != null) {
      Navigator.pop(context); // Close checkout sheet
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReceiptDialog(
          transaction: transaction,
          cashTendered: _selectedPayment == 'TUNAI' ? _cashTendered : total,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final total = posProvider.totalAmount;
    final change = _cashTendered > total ? _cashTendered - total : 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pembayaran Kasir',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                Text(
                  '${posProvider.totalItems} item',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total Tagihan Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total yang Harus Dibayar', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pilihan Metode Pembayaran
            const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildPaymentOption('TUNAI', Icons.payments_outlined),
                const SizedBox(width: 8),
                _buildPaymentOption('QRIS', Icons.qr_code_2),
                const SizedBox(width: 8),
                _buildPaymentOption('DEBIT', Icons.credit_card),
              ],
            ),
            const SizedBox(height: 16),

            // Konten Khusus per Metode
            if (_selectedPayment == 'TUNAI') ...[
              const Text('Uang Diterima (Cash)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  setState(() {
                    _cashTendered = int.tryParse(val) ?? 0;
                  });
                },
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
              ),
              const SizedBox(height: 10),
              // Tombol Uang Cepat
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickCashButton('Uang Pas', total),
                    const SizedBox(width: 8),
                    if (total <= 20000) ...[
                      _buildQuickCashButton('20.000', 20000),
                      const SizedBox(width: 8),
                    ],
                    if (total <= 50000) ...[
                      _buildQuickCashButton('50.000', 50000),
                      const SizedBox(width: 8),
                    ],
                    if (total <= 100000) ...[
                      _buildQuickCashButton('100.000', 100000),
                      const SizedBox(width: 8),
                    ],
                    _buildQuickCashButton('200.000', 200000),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Kembalian
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    Text(
                      CurrencyFormatter.format(change),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _cashTendered >= total ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedPayment == 'QRIS') ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 100, color: AppColors.textMain),
                      const SizedBox(height: 8),
                      const Text('QRIS Statis / Dinamis Toko', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyFormatter.format(total),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Gesek / Tap kartu pelanggan pada mesin EDC Anda.'),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Opsional: Customer Name / Phone
            TextField(
              controller: _customerController,
              decoration: const InputDecoration(
                hintText: 'Nama / ID Pelanggan (opsional)',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Bayar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePay,
                child: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Konfirmasi & Bayar ${CurrencyFormatter.format(total)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String label, IconData icon) {
    final isSelected = _selectedPayment == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPayment = label),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primaryDark : AppColors.textMuted, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primaryDark : AppColors.textMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashButton(String label, int amount) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: AppColors.border),
      ),
      onPressed: () => _setCash(amount),
      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMain)),
    );
  }
}
