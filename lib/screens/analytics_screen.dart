import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/analytics_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import '../services/local_db_service.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/settings_dialog.dart';

class AnalyticsScreen extends StatefulWidget {
  final int initialSubTab;
  const AnalyticsScreen({super.key, this.initialSubTab = 0});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ApiService _apiService = ApiService();
  AnalyticsSummary? _summary;
  bool _isLoading = true;
  int _activeSubTab = 0; // 0: Ringkasan & Tren, 1: Riwayat Transaksi

  // Order History state
  final TextEditingController _searchController = TextEditingController();
  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];
  String _selectedPaymentFilter = 'SEMUA';
  final List<String> _paymentFilters = ['SEMUA', 'TUNAI', 'QRIS', 'TRANSFER', 'DEBIT'];

  @override
  void initState() {
    super.initState();
    _activeSubTab = widget.initialSubTab;
    _searchController.addListener(_applyFilters);
    _loadAnalytics();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getAnalyticsSummary();
    if (mounted) {
      setState(() {
        _summary = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final txs = await LocalDbService.instance.getTransactions(limit: 500);
      if (mounted) {
        setState(() {
          _allTransactions = txs;
        });
        _applyFilters();
      }
    } catch (_) {}
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredTransactions = _allTransactions.where((tx) {
        final paymentMatches = _selectedPaymentFilter == 'SEMUA' ||
            tx.paymentType.toUpperCase().contains(_selectedPaymentFilter);

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

  Future<void> _exportExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ExportService.instance.exportTransactionsExcel();
    if (result.success && result.filePath != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ Laporan Excel (.xlsx) berhasil disimpan!\n${result.filePath}'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
          action: ExportService.instance.isDesktopPlatform
              ? SnackBarAction(
                  label: 'Buka File',
                  textColor: Colors.white,
                  onPressed: () => ExportService.instance.openInExplorer(result.filePath!),
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Laporan & Analitik', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Ringkasan Omset, Tren & Riwayat Penjualan', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_rounded, color: Colors.green),
            tooltip: 'Ekspor Excel (.xlsx)',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan & Profil',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const SettingsDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Tab Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTabButton(
                    index: 0,
                    icon: Icons.insights_rounded,
                    label: 'Ringkasan & Tren',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSubTabButton(
                    index: 1,
                    icon: Icons.receipt_long_rounded,
                    label: 'Riwayat Transaksi',
                    badgeText: _allTransactions.isNotEmpty ? '${_allTransactions.length}' : null,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _activeSubTab == 0
                    ? _buildSummaryView(isDark)
                    : _buildHistoryView(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String label,
    String? badgeText,
    required bool isDark,
  }) {
    final isSelected = _activeSubTab == index;

    return InkWell(
      onTap: () {
        setState(() => _activeSubTab = index);
        if (index == 1) {
          _loadTransactions();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF042F2E) : AppColors.primaryLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                    : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkCard : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryView(bool isDark) {
    if (_summary == null) {
      return const Center(child: Text('Data tidak tersedia'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadAnalytics();
        await _loadTransactions();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Highlight Revenue Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pendapatan (Omset)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(_summary!.totalRevenue),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat('Total Transaksi', '${_summary!.totalOrders} Nota'),
                      _buildMiniStat('Rata-rata Nota', CurrencyFormatter.format(_summary!.averageOrderValue)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Daily Sales Chart
            Text(
              'Tren Penjualan 5 Hari Terakhir',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 1000000,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              CurrencyFormatter.format(rod.toY),
                              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final index = val.toInt();
                              if (index >= 0 && index < _summary!.dailySales.length) {
                                final d = _summary!.dailySales[index].date.substring(5);
                                return Text(d, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _summary!.dailySales.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.totalAmount.toDouble(),
                              color: AppColors.primary,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Method Breakdown
            Text(
              'Metode Pembayaran Terbanyak',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 10),
            ..._summary!.paymentMethods.map((p) {
              return Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            p.paymentType == 'QRIS'
                                ? Icons.qr_code_2
                                : p.paymentType == 'TUNAI'
                                    ? Icons.payments_outlined
                                    : Icons.credit_card,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.paymentType,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                ),
                              ),
                              Text(
                                '${p.count} transaksi (${p.percentage}%)',
                                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(p.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryView(bool isDark) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: Column(
        children: [
          // Filter & Search bar inside history
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
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
                    fillColor: isDark ? AppColors.darkCard : Colors.grey.shade50,
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
                const SizedBox(height: 8),

                // Payment Filters Chips
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
                          backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
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
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _filteredTransactions.isEmpty
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _filteredTransactions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tx = _filteredTransactions[index];
                      final totalItemsCount = tx.items.fold<int>(0, (sum, i) => sum + i.quantity);
                      final badgeColor = _getPaymentBadgeColor(tx.paymentType);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Left Details
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
                                        '$totalItemsCount item (${tx.items.length} jenis)',
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

                            // Right Amount & Print Button
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(tx.totalAmount),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
