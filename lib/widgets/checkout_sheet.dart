import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../core/constants/api_constants.dart';
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
  String _selectedBank = 'BCA';
  String _selectedEwallet = 'GoPay';
  bool _isProcessing = false;
  bool _isOrderDetailsExpanded = true;

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
    if (_selectedPayment == 'TRANSFER') {
      final bankText = 'Transfer $_selectedBank';
      customerNote = customerNote.isNotEmpty ? '$customerNote ($bankText)' : bankText;
    } else if (_selectedPayment == 'EWALLET') {
      final ewText = 'E-Wallet $_selectedEwallet';
      customerNote = customerNote.isNotEmpty ? '$customerNote ($ewText)' : ewText;
    } else if (_selectedPayment == 'DEBIT') {
      const debitText = 'Kartu Debit/EDC';
      customerNote = customerNote.isNotEmpty ? '$customerNote ($debitText)' : debitText;
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
                      ApiConstants.isOfflineMode
                          ? '📦 Mode Lifetime (100% Offline SQLite)'
                          : '☁️ Mode Cloud SaaS (Online)',
                      style: TextStyle(
                        fontSize: 11,
                        color: ApiConstants.isOfflineMode
                            ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                            : (isDark ? AppColors.accentLight : AppColors.accentDark),
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
                    color: AppColors.primary.withValues(alpha: 0.3),
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
            // Detail Pesanan (Item, Qty & Subtotal)
            Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _isOrderDetailsExpanded = !_isOrderDetailsExpanded),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 18,
                                color: isDark ? AppColors.primaryHover : AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Rincian Belanja (${posProvider.totalItems} item)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                _isOrderDetailsExpanded ? 'Sembunyikan' : 'Lihat Item',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.primaryHover : AppColors.primary,
                                ),
                              ),
                              Icon(
                                _isOrderDetailsExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: isDark ? AppColors.primaryHover : AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isOrderDetailsExpanded) ...[
                    Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: posProvider.cart.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 12,
                          color: (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.5),
                        ),
                        itemBuilder: (ctx, idx) {
                          final item = posProvider.cart[idx];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.quantity} x ${CurrencyFormatter.format(item.product.price)}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF34D399) : AppColors.primaryDark,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
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
                    color: _cashTendered >= total ? AppColors.success.withValues(alpha: 0.5) : AppColors.danger.withValues(alpha: 0.5),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 70, color: AppColors.accent),
                    const SizedBox(height: 4),
                    const Text('Scan QRIS Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(total),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ApiConstants.isOfflineMode
                          ? '🛡️ Mode Offline: 0% Biaya MDR. Minta pelanggan scan QRIS toko & cek bukti bayar di HP pelanggan.'
                          : '⚡ Mode Cloud: Webhook mendeteksi pembayaran secara otomatis.',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (_selectedPayment == 'TRANSFER') ...[
              // Bank Selection Chips
              const Text('Pilih Bank Tujuan Toko:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 6),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transfer Bank $_selectedBank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 2),
                          const Text(
                            'Pelanggan transfer ke rekening toko. Tidak perlu input nomor kartu atau referensi.',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedPayment == 'EWALLET') ...[
              // E-Wallet Choice
              const Text('Pilih E-Wallet Pelanggan / Toko:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 6),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pembayaran via $_selectedEwallet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 2),
                          const Text(
                            'Pelanggan scan QR / transfer ke akun e-wallet toko. Tidak perlu input nomor HP pelanggan.',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Debit / EDC Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mesin EDC Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(
                            'Gesek, masukkan chip, atau tap kartu pada mesin EDC kasir. Tidak perlu input nomor kartu.',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Opsional: Customer Name / Note
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
        backgroundColor: AppColors.accentLight.withValues(alpha: 0.5),
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
