import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../services/auth_service.dart';

class SaaSPaymentSheet extends StatefulWidget {
  const SaaSPaymentSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SaaSPaymentSheet(),
    );
  }

  @override
  State<SaaSPaymentSheet> createState() => _SaaSPaymentSheetState();
}

class _SaaSPaymentSheetState extends State<SaaSPaymentSheet> {
  String _selectedTier = 'subs_yearly'; // 'subs_yearly', 'subs_monthly', 'lan_multidevice'
  bool _isCheckingStatus = false;

  final Map<String, Map<String, dynamic>> _tiers = {
    'subs_yearly': {
      'title': 'Cloud SaaS Tahunan',
      'price': 399000,
      'originalPrice': 600000,
      'billing': '/ tahun (~Rp 33rb/bln)',
      'badge': '⭐ PALING HEMAT (Diskon 33%)',
      'badgeColor': Colors.amber.shade800,
      'features': [
        'Multi-Perangkat Sinkronisasi Cloud Tanpa Batas',
        'Web Dashboard Owner & Analitik Toko Lengkap',
        'AI Stockout Radar & Prediksi Habis Barang',
        'MongoDB Atlas Auto-Backup Aman 60 Hari',
      ],
    },
    'subs_monthly': {
      'title': 'Cloud SaaS Bulanan',
      'price': 49000,
      'originalPrice': 79000,
      'billing': '/ bulan',
      'badge': '⚡ FLEKSIBEL',
      'badgeColor': Colors.blue.shade700,
      'features': [
        'Akses Penuh Semua Fitur Cloud POS',
        'Bayar Fleksibel 30 Hari, Batalkan Kapan Saja',
        'Dukungan Update Fitur Berkala',
      ],
    },
    'lan_multidevice': {
      'title': 'Lifetime Wi-Fi LAN Resto',
      'price': 599000,
      'originalPrice': 1200000,
      'billing': 'sekali bayar seumur hidup',
      'badge': '🍽️ KHUSUS RESTO / CAFE',
      'badgeColor': Colors.purple.shade700,
      'features': [
        '1 Host PC Server + 3 HP Waiter / Kasir Meja',
        'Wi-Fi Lokal Tanpa Kuota Internet Sama Sekali',
        'Kirim Pesanan Instan ke Dapur & Bar',
        'Lisensi Kriptografi Resmi Seumur Hidup',
      ],
    },
  };

  Future<void> _payViaWeboz() async {
    final auth = AuthService.instance;
    final storeId = auth.storeId ?? 'STORE_DIRECT';
    final phone = auth.phone ?? '';
    final url = 'https://weboz.my.id/larisai?plan=$_selectedTier&store_id=$storeId&phone=$phone#checkout';
    final uri = Uri.parse(url);

    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka halaman pembayaran: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmViaWhatsApp() async {
    final selectedInfo = _tiers[_selectedTier]!;
    final tierTitle = selectedInfo['title'];
    final priceStr = CurrencyFormatter.format(selectedInfo['price']);
    final storeName = AuthService.instance.storeName;
    final storeId = AuthService.instance.storeId ?? '-';

    final text = 'Halo Admin Weboz, saya ingin konfirmasi pembayaran paket $tierTitle ($priceStr) untuk Toko: $storeName (Store ID: $storeId). Mohon verifikasi aktivasi lisensi.';
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse('https://wa.me/628881264995?text=$encoded');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _checkPaymentStatus() async {
    setState(() => _isCheckingStatus = true);
    final messenger = ScaffoldMessenger.of(context);

    final res = await AuthService.instance.fetchSubscriptionStatus();
    if (!mounted) return;
    setState(() => _isCheckingStatus = false);

    if (res != null && res['status'] == 'active') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('🎉 Pembayaran Terverifikasi! Paket Anda kini AKTIF.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Status saat ini: ${AuthService.instance.subscriptionBadgeText}. Jika baru transfer, tunggu 1-2 menit lalu cek lagi.'),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $label berhasil disalin ke clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedInfo = _tiers[_selectedTier]!;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Paket Lisensi LarisAI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                        ),
                      ),
                      Text(
                        'Aktivasi instan via QRIS Weboz (0% Komisi)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 3 Tier Option Cards
                ..._tiers.entries.map((entry) {
                  final key = entry.key;
                  final info = entry.value;
                  final isSelected = _selectedTier == key;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedTier = key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(isDark ? 0.15 : 0.05)
                            : (isDark ? AppColors.darkCard : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorder : AppColors.border),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: info['badgeColor'] as Color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  info['badge'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: isSelected ? AppColors.primary : Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                info['title'] as String,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                CurrencyFormatter.format(info['price'] as int),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                info['billing'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(info['originalPrice'] as int),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Feature Bullets
                          ...(info['features'] as List<String>).map((feat) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    feat,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // Manual Bank Transfer Info Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.blue.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.blue.shade100,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_rounded, size: 16, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Pilihan Transfer Manual (BCA)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextMain : Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bank Central Asia (BCA)', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                const Text('8930847403', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const Text('a.n. Fahrur Rozi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _copyToClipboard('8930847403', 'Nomor Rekening BCA'),
                            icon: const Icon(Icons.copy_rounded, size: 13),
                            label: const Text('Salin No. Rek', style: TextStyle(fontSize: 10.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: _payViaWeboz,
                        icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                        label: Text(
                          'Bayar ${CurrencyFormatter.format(selectedInfo['price'] as int)} via QRIS',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isCheckingStatus ? null : _checkPaymentStatus,
                        icon: _isCheckingStatus
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Cek Status',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _confirmViaWhatsApp,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.green),
                  label: const Text(
                    'Konfirmasi Bukti Transfer via WhatsApp CS (0888-1264-995)',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
