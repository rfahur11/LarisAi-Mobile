import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';
import '../providers/pos_provider.dart';
import '../services/local_db_service.dart';
import '../services/export_service.dart';
import 'receipt_dialog.dart';

class OrderHistoryDialog extends StatefulWidget {
  const OrderHistoryDialog({super.key});

  @override
  State<OrderHistoryDialog> createState() => _OrderHistoryDialogState();
}

class _OrderHistoryDialogState extends State<OrderHistoryDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  String _selectedPaymentFilter = 'SEMUA';

  final List<String> _paymentFilters = ['SEMUA', 'TUNAI', 'QRIS', 'TRANSFER', 'DEBIT'];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final txs = await LocalDbService.instance.getTransactions(limit: 500);
      if (mounted) {
        setState(() {
          _allTransactions = txs;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredTransactions = _allTransactions.where((tx) {
        // Payment filter
        final paymentMatches = _selectedPaymentFilter == 'SEMUA' ||
            tx.paymentType.toUpperCase().contains(_selectedPaymentFilter);

        // Search query
        final queryMatches = query.isEmpty ||
            tx.invoiceNo.toLowerCase().contains(query) ||
            tx.customerId.toLowerCase().contains(query) ||
            tx.items.any((item) => item.name.toLowerCase().contains(query));

        return paymentMatches && queryMatches;
      }).toList();
    });
  }

  Color _getPaymentBadgeColor(String paymentType) {
    switch (paymentType.toUpperCase()) {
      case 'TUNAI':
      case 'CASH':
        return Colors.green.shade700;
      case 'QRIS':
        return const Color(0xFF0284C7);
      case 'TRANSFER':
        return Colors.indigo.shade700;
      case 'DEBIT':
        return Colors.purple.shade700;
      default:
        return AppColors.accent;
    }
  }

  void _confirmVoidTransaction(Transaction tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalItemsCount = tx.items.fold<int>(0, (sum, i) => sum + i.quantity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text(
              'Batalkan Transaksi?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice: ${tx.invoiceNo}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${CurrencyFormatter.format(tx.totalAmount)} (${tx.paymentType})',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stok sebanyak $totalItemsCount item akan otomatis dikembalikan ke inventori toko.',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final posProv = context.read<PosProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await posProv.voidTransaction(tx.invoiceNo);
              if (mounted) {
                if (success) {
                  await _loadTransactions();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✅ Transaksi ${tx.invoiceNo} berhasil dibatalkan & stok dikembalikan!'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Gagal membatalkan transaksi.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Ya, Batalkan Transaksi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = (mediaQuery.size.width * 0.94).clamp(340.0, 720.0);
    final dialogHeight = (mediaQuery.size.height * 0.82).clamp(420.0, 680.0);
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.primaryHover : AppColors.primary).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Riwayat Transaksi',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_allTransactions.length} Total',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Pencarian nota penjualan, detail belanja, dan cetak ulang struk kasir',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  icon: Icon(Icons.close_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Search & Payment Filter Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari No Invoice (INV-...), Pelanggan, atau Produk...',
                      hintStyle: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : Colors.grey,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Segarkan Data',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                  onPressed: _loadTransactions,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payment Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _paymentFilters.map((filter) {
                  final isSelected = _selectedPaymentFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                        ),
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedPaymentFilter = filter);
                          _applyFilters();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // 3. Transactions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                _searchController.text.isEmpty && _selectedPaymentFilter == 'SEMUA'
                                    ? 'Belum ada transaksi tersimpan'
                                    : 'Tidak ada transaksi yang cocok dengan filter',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredTransactions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = _filteredTransactions[index];
                            final totalItemsCount = tx.items.fold<int>(0, (sum, i) => sum + i.quantity);
                            final badgeColor = _getPaymentBadgeColor(tx.paymentType);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Left Icon & Metadata
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              tx.invoiceNo,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                tx.paymentType.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: badgeColor,
                                                ),
                                              ),
                                            ),
                                            if (tx.isVoid) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(5),
                                                  border: Border.all(color: Colors.red.shade400, width: 0.8),
                                                ),
                                                child: const Text(
                                                  'BATAL (VOID)',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(Icons.schedule_rounded, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              dateFormatter.format(tx.createdAt),
                                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                            ),
                                            const SizedBox(width: 10),
                                            Icon(Icons.shopping_bag_outlined, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$totalItemsCount item (${tx.items.length} ragam)',
                                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          tx.items.map((i) => '${i.name} (${i.quantity}x)').join(', '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: isDark ? AppColors.darkTextMuted : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Right Amount & Print/Void Button
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(tx.totalAmount),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: tx.isVoid ? (isDark ? AppColors.darkTextMuted : Colors.grey) : AppColors.primary,
                                          decoration: tx.isVoid ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!tx.isVoid) ...[
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.danger,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                visualDensity: VisualDensity.compact,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                side: BorderSide(
                                                  color: AppColors.danger.withValues(alpha: 0.5),
                                                ),
                                              ),
                                              icon: const Icon(Icons.undo_rounded, size: 13, color: AppColors.danger),
                                              label: const Text(
                                                'Void',
                                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.danger),
                                              ),
                                              onPressed: () => _confirmVoidTransaction(tx),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              visualDensity: VisualDensity.compact,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              side: BorderSide(
                                                color: isDark ? AppColors.darkBorder : AppColors.primary.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            icon: const Icon(Icons.receipt_rounded, size: 14, color: AppColors.primary),
                                            label: const Text(
                                              'Struk',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) => ReceiptDialog(
                                                  transaction: tx,
                                                  cashTendered: tx.totalAmount,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 12),

            // 4. Footer Actions
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: Colors.green.shade700),
                  ),
                  icon: const Icon(Icons.table_view_rounded, size: 16),
                  label: const Text('Ekspor Excel (.xlsx)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final result = await ExportService.instance.exportTransactionsExcel();
                    if (result.success && result.filePath != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('✅ Laporan Excel tersimpan!\n${result.filePath}'),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                    }
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
