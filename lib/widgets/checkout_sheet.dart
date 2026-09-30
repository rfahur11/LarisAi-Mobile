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
  String _selectedPayment = 'TUNAI'; // TUNAI, QRIS, TRANSFER, DEBIT, EWALLET
  int _cashTendered = 0;
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  String _selectedBank = 'BCA';
  String _selectedEwallet = 'GoPay';
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
    _refController.dispose();
    super.dispose();
  }

  void _setCash(int amount) {
    setState(() {
      _cashTendered = amount;
      _cashController.text = amount.toString();
    });
  }

  void _addCash(int addAmount) {
    setState(() {
      _cashTendered += addAmount;
      _cashController.text = _cashTendered.toString();
    });
  }

  Future<void> _handlePay() async {
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final total = posProvider.totalAmount;

    if (_selectedPayment == 'TUNAI' && _cashTendered < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Uang yang dibayarkan kurang dari total belanja!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    String customerNote = _customerController.text.trim();
    if (_refController.text.trim().isNotEmpty) {
      final refText = _selectedPayment == 'TRANSFER'
          ? 'Transfer $_selectedBank: ${_refController.text.trim()}'
          : (_selectedPayment == 'EWALLET'
              ? '$_selectedEwallet: ${_refController.text.trim()}'
              : 'Ref: ${_refController.text.trim()}');
      customerNote = customerNote.isNotEmpty ? '$customerNote ($refText)' : refText;
    }

    final transaction = await posProvider.processCheckout(
      paymentType: _selectedPayment,
      customerId: customerNote.isNotEmpty ? customerNote : null,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posProvider = Provider.of<PosProvider>(context);
    final total = posProvider.totalAmount;
    final change = _cashTendered >= total ? _cashTendered - total : 0;
    final deficit = _cashTendered < total ? total - _cashTendered : 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
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
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Header Title & Offline Lifetime Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pembayaran Kasir',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mode Offline / Lifetime (SQLite Lokal)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${posProvider.totalItems} item',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total yang Harus Dibayar', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pilihan Metode Pembayaran (5 Options)
            Text(
              'Pilih Metode Pembayaran',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),

            // Row 1: Tunai, QRIS, Transfer
            Row(
              children: [
                _buildPaymentOption('TUNAI', '💵 Tunai', Icons.payments_outlined, isDark),
                const SizedBox(width: 6),
                _buildPaymentOption('QRIS', '📱 QRIS', Icons.qr_code_2_rounded, isDark),
                const SizedBox(width: 6),
                _buildPaymentOption('TRANSFER', '🏦 Transfer', Icons.account_balance_outlined, isDark),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Debit EDC, E-Wallet
            Row(
              children: [
                _buildPaymentOption('DEBIT', '💳 Debit EDC', Icons.credit_card_rounded, isDark),
                const SizedBox(width: 6),
                _buildPaymentOption('EWALLET', '📲 E-Wallet', Icons.phone_android_rounded, isDark),
              ],
            ),
            const SizedBox(height: 14),

            // Konten Khusus per Metode
            if (_selectedPayment == 'TUNAI') ...[
              Text(
                'Nominal Uang Diterima (Cash)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      onChanged: (val) {
                        setState(() {
                          _cashTendered = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        });
                      },
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        suffixIcon: _cashController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _cashTendered = 0;
                                    _cashController.clear();
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primaryDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _setCash(total),
                    child: const Text('Uang Pas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tombol Uang Cepat & Tambah Cepat
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickAddButton('+5rb', 5000),
                    const SizedBox(width: 6),
                    _buildQuickAddButton('+10rb', 10000),
                    const SizedBox(width: 6),
                    _buildQuickAddButton('+20rb', 20000),
                    const SizedBox(width: 6),
                    _buildQuickAddButton('+50rb', 50000),
                    const SizedBox(width: 6),
                    _buildQuickCashButton('50.000', 50000),
                    const SizedBox(width: 6),
                    _buildQuickCashButton('100.000', 100000),
                    const SizedBox(width: 6),
                    _buildQuickCashButton('200.000', 200000),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Kembalian / Kurang Status Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _cashTendered >= total
                      ? (isDark ? const Color(0xFF042F2E) : const Color(0xFFECFDF5))
                      : (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _cashTendered >= total ? AppColors.success.withOpacity(0.5) : AppColors.danger.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _cashTendered >= total ? 'Kembalian:' : 'Uang Kurang:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _cashTendered >= total ? AppColors.success : AppColors.danger,
                      ),
                    ),
                    Text(
                      _cashTendered >= total ? CurrencyFormatter.format(change) : CurrencyFormatter.format(deficit),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
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
                    color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 80, color: AppColors.accent),
                      const SizedBox(height: 6),
                      const Text('Scan QRIS Dinamis Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        CurrencyFormatter.format(total),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_selectedPayment == 'TRANSFER') ...[
              // Bank Selection Chips
              Row(
                children: ['BCA', 'Mandiri', 'BRI', 'BNI'].map((bank) {
                  final isBankSelected = _selectedBank == bank;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(bank, style: const TextStyle(fontSize: 11)),
                        selected: isBankSelected,
                        selectedColor: AppColors.primaryLight,
                        onSelected: (_) => setState(() => _selectedBank = bank),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _refController,
                decoration: const InputDecoration(
                  hintText: 'No. Referensi / Nama Pengirim (opsional)',
                  prefixIcon: Icon(Icons.receipt_long_outlined, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ] else if (_selectedPayment == 'EWALLET') ...[
              // E-Wallet Choice
              Row(
                children: ['GoPay', 'OVO', 'DANA', 'ShopeePay'].map((ew) {
                  final isEwSelected = _selectedEwallet == ew;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(ew, style: const TextStyle(fontSize: 10)),
                        selected: isEwSelected,
                        selectedColor: AppColors.primaryLight,
                        onSelected: (_) => setState(() => _selectedEwallet = ew),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _refController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Nomor HP Pelanggan (opsional)',
                  prefixIcon: Icon(Icons.phone_android_outlined, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('💳 Gesek atau Tap kartu debit/kredit pada mesin EDC toko.'),
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Opsional: Customer Name / Phone
            TextField(
              controller: _customerController,
              decoration: const InputDecoration(
                hintText: 'Nama / Catatan Pelanggan (opsional)',
                prefixIcon: Icon(Icons.person_outline, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Bayar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePay,
                child: _isProcessing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Konfirmasi & Selesaikan Transaksi',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String type, String label, IconData icon, bool isDark) {
    final isSelected = _selectedPayment == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedPayment = type;
          if (type != 'TUNAI') {
            final total = Provider.of<PosProvider>(context, listen: false).totalAmount;
            _cashTendered = total;
            _cashController.text = total.toString();
          }
        }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF042F2E) : AppColors.primaryLight)
                : (isDark ? AppColors.darkBackground : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? AppColors.primaryDark : (isDark ? AppColors.darkTextMuted : AppColors.textMuted), size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primaryDark : (isDark ? AppColors.darkTextMain : AppColors.textMain),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.border),
      ),
      onPressed: () => _setCash(amount),
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMain)),
    );
  }

  Widget _buildQuickAddButton(String label, int addAmount) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentLight.withOpacity(0.5),
        foregroundColor: AppColors.accent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () => _addCash(addAmount),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
