import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../providers/ai_provider.dart';
import '../widgets/settings_dialog.dart';

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

  Future<void> _launchWhatsApp({required String phone, required String message}) async {
    String cleanNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '62${cleanNumber.substring(1)}';
    }
    final encoded = Uri.encodeComponent(message);
    final waUrl = cleanNumber.isNotEmpty
        ? 'https://wa.me/$cleanNumber?text=$encoded'
        : 'https://wa.me/?text=$encoded';
    final waScheme = cleanNumber.isNotEmpty
        ? 'whatsapp://send?phone=$cleanNumber&text=$encoded'
        : 'whatsapp://send?text=$encoded';

    try {
      final uri = Uri.parse(waUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(Uri.parse(waScheme), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(Uri.parse(waScheme), mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  void _showPromoBlastDialog(BuildContext context, String clusterLabel) {
    final defaultMsg = clusterLabel.toLowerCase().contains('churn')
        ? 'Halo Kak! Kami kangen nih belanja bareng Kakak di toko kami. Dapatkan DISKON SPESIAL 15% untuk transaksi hari ini! Tunjukkan pesan ini ke kasir ya 😊'
        : 'Halo Pelanggan Setia! Terima kasih sudah selalu mempercayakan kebutuhan Anda di toko kami. Khusus hari ini nikmati BONUS POIN & VOUCHER Rp 10.000! 🎉';

    final messageController = TextEditingController(text: defaultMsg);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.mark_chat_unread, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Promo WhatsApp ($clusterLabel)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ApiConstants.isOfflineMode
                    ? const Color(0xFFECFDF5)
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ApiConstants.isOfflineMode
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    ApiConstants.isOfflineMode ? Icons.bolt_rounded : Icons.cloud_done_rounded,
                    size: 16,
                    color: ApiConstants.isOfflineMode ? const Color(0xFF059669) : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ApiConstants.isOfflineMode
                          ? 'Mode Lifetime: 1-Tap WhatsApp Launcher'
                          : 'Mode Cloud: Auto Multi-Blast Background',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ApiConstants.isOfflineMode ? const Color(0xFF065F46) : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Teks promo rekomendasi AI siap dikirim ke seluruh pelanggan di segmen ini:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: messageController,
              maxLines: 4,
              style: const TextStyle(fontSize: 13),
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
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: messageController.text.trim()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📋 Teks promo disalin ke clipboard! Siap dipaste ke status/broadcast WA.'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Salin Teks', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final text = messageController.text.trim();
              if (ApiConstants.isOfflineMode) {
                await _launchWhatsApp(phone: '', message: text);
              } else {
                final aiProvider = Provider.of<AiProvider>(context, listen: false);
                await aiProvider.sendPromoBlast(
                  clusterLabel: clusterLabel,
                  message: text,
                );
              }
            },
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text('Buka WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const SettingsDialog(),
              );
            },
          ),
        ],
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

            // Parse phone number from customerId if present (e.g. "Budi (08123456789)")
            final rawId = cluster.customerId;
            final match = RegExp(r'(08\d{8,13}|\+?62\d{8,13})').firstMatch(rawId);
            final phone = match?.group(1) ?? '';
            String displayName = rawId;
            if (match != null) {
              displayName = rawId.replaceAll(match.group(0)!, '').replaceAll(RegExp(r'[\(\)\-•]'), '').trim();
              if (displayName.isEmpty) displayName = 'Pelanggan ($phone)';
            }

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
                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (phone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 11, color: Color(0xFF25D366)),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    Text(
                      '${cluster.frequencyCount}x belanja • Total ${CurrencyFormatter.format(cluster.monetaryValue)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (phone.isNotEmpty) ...[
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366).withOpacity(0.12),
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(34, 34),
                        ),
                        icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                        tooltip: 'Kirim WhatsApp ke $displayName',
                        onPressed: () {
                          final promoMsg = isChurn
                              ? 'Halo Kak $displayName! Kami kangen nih belanja bareng Kakak di toko kami. Ada voucher diskon 15% khusus hari ini ya 😊'
                              : 'Halo Kak $displayName! Terima kasih telah jadi pelanggan setia kami. Dapatkan penawaran istimewa khusus hari ini 🎉';
                          _launchWhatsApp(phone: phone, message: promoMsg);
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
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
                  ],
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
