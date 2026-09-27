import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../providers/ai_provider.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPromoBlastDialog(BuildContext context, String clusterLabel) {
    final messageController = TextEditingController(
      text: clusterLabel == 'Loyal'
          ? 'Halo Kak! Terima kasih sudah setia belanja di toko kami. Dapatkan diskon 15% khusus member VIP minggu ini!'
          : 'Halo Kak, kami rindu Anda! Dapatkan voucher belanja Rp 10.000 untuk kunjungan Anda berikutnya.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.mark_chat_unread, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Kirim Promo ($clusterLabel)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pesan promo otomatis akan dikirim ke seluruh pelanggan di segmen ini via WhatsApp Engine.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Tulis pesan promo...',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final aiProvider = Provider.of<AiProvider>(context, listen: false);
              final success = await aiProvider.sendPromoBlast(
                clusterLabel: clusterLabel,
                message: messageController.text.trim(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '🚀 Promo WhatsApp berhasil dikirim ke pelanggan $clusterLabel!'
                          : 'Gagal mengirim promo.',
                    ),
                    backgroundColor: success ? AppColors.primary : AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('Kirim Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = Provider.of<AiProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LarisAI Intelligence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Forecasting & CRM AI Engine', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.warning_amber_rounded, size: 18), text: 'Radar Habis Stok'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Segmentasi Pelanggan'),
          ],
        ),
      ),
      body: aiProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: STOCKOUT RADAR
                _buildStockoutTab(aiProvider),
                // TAB 2: CUSTOMER SEGMENTS
                _buildCustomerSegmentsTab(aiProvider),
              ],
            ),
    );
  }

  Widget _buildStockoutTab(AiProvider aiProvider) {
    if (aiProvider.stockouts.isEmpty) {
      return const Center(
        child: Text('Seluruh stok barang aman terkendali!'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: aiProvider.stockouts.length,
      itemBuilder: (ctx, idx) {
        final item = aiProvider.stockouts[idx];
        final isCritical = item.daysUntilStockout <= 2;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isCritical ? AppColors.danger.withOpacity(0.5) : AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCritical ? AppColors.danger.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${item.daysUntilStockout}h',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isCritical ? AppColors.danger : AppColors.warning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stok saat ini: ${item.currentStock} pcs • Laju laku: ~${item.dailyBurnRate}/hari',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCritical
                            ? '⚠️ Kritis: Habis dalam ${item.daysUntilStockout} hari ke depan!'
                            : '⚡ Segera restock dalam ${item.daysUntilStockout} hari.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCritical ? AppColors.danger : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerSegmentsTab(AiProvider aiProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Ringkasan Segmentasi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSegmentCountBadge('Loyal VIP', '${aiProvider.loyalCustomers.length} Pelanggan', Colors.amber),
                Container(height: 35, width: 1, color: Colors.white24),
                _buildSegmentCountBadge('Beresiko Churn', '${aiProvider.churnRiskCustomers.length} Pelanggan', Colors.redAccent),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tombol Tindakan Cepat Promo WhatsApp
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF25D366)), // WhatsApp Green
                  ),
                  onPressed: () => _showPromoBlastDialog(context, 'Loyal'),
                  icon: const Icon(Icons.send, color: Color(0xFF25D366), size: 16),
                  label: const Text('Promo Loyal WA', style: TextStyle(color: Color(0xFF25D366), fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: () => _showPromoBlastDialog(context, 'Beresiko Churn'),
                  icon: const Icon(Icons.campaign, color: AppColors.danger, size: 16),
                  label: const Text('Retensi Churn WA', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Daftar Pelanggan Tersegmentasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),

          ...aiProvider.clusters.map((cluster) {
            final isLoyal = cluster.clusterLabel.toLowerCase().contains('loyal');
            final isChurn = cluster.clusterLabel.toLowerCase().contains('churn');

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLoyal
                      ? Colors.amber.withOpacity(0.2)
                      : isChurn
                          ? Colors.red.withOpacity(0.2)
                          : AppColors.primaryLight,
                  child: Icon(
                    isLoyal
                        ? Icons.star
                        : isChurn
                            ? Icons.person_off
                            : Icons.person,
                    color: isLoyal
                        ? Colors.amber[800]
                        : isChurn
                            ? Colors.red[800]
                            : AppColors.primaryDark,
                    size: 20,
                  ),
                ),
                title: Text(cluster.customerId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  '${cluster.frequencyCount}x belanja • Total ${CurrencyFormatter.format(cluster.monetaryValue)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLoyal
                        ? Colors.amber.withOpacity(0.15)
                        : isChurn
                            ? Colors.red.withOpacity(0.15)
                            : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cluster.clusterLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLoyal
                          ? Colors.amber[900]
                          : isChurn
                              ? Colors.red[900]
                              : AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSegmentCountBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
