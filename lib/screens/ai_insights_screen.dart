import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../providers/ai_provider.dart';
import '../providers/pos_provider.dart';
import '../services/local_db_service.dart';
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

  void _showAddCustomerDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.person_add_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Tambah Kontak CRM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama Pelanggan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
              decoration: InputDecoration(
                hintText: 'Contoh: Bu Anita / Pak Joko',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
            ),
            const SizedBox(height: 12),
            Text('No. WhatsApp (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
            const SizedBox(height: 6),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
              decoration: InputDecoration(
                hintText: '081234567890',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama pelanggan wajib diisi!'), backgroundColor: AppColors.danger),
                );
                return;
              }
              final posProv = context.read<PosProvider>();
              final aiProv = context.read<AiProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await LocalDbService.instance.saveCustomer(name: name, phone: phone);
              await posProv.loadCustomerHistory();
              await aiProv.loadAiData();
              messenger.showSnackBar(
                SnackBar(content: Text('✅ Pelanggan $name berhasil disimpan!'), backgroundColor: AppColors.primary),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showCustomerEditDialog(BuildContext context, String rawId, String currentName, String currentPhone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Edit Data Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama Pelanggan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
            ),
            const SizedBox(height: 12),
            Text('No. WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
            const SizedBox(height: 6),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama pelanggan wajib diisi!'), backgroundColor: AppColors.danger),
                );
                return;
              }
              final posProv = context.read<PosProvider>();
              final aiProv = context.read<AiProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await LocalDbService.instance.updateCustomer(id: rawId, name: name, phone: phone);
              await LocalDbService.instance.saveCustomer(name: name, phone: phone);
              await posProv.loadCustomerHistory();
              await aiProv.loadAiData();
              messenger.showSnackBar(
                SnackBar(content: Text('✅ Data pelanggan $name berhasil diperbarui!'), backgroundColor: AppColors.primary),
              );
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDeleteDialog(BuildContext context, String rawId, String displayName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.person_remove_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Hapus Kontak Pelanggan?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus kontak "$displayName" dari daftar CRM toko?',
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final posProv = context.read<PosProvider>();
              final aiProv = context.read<AiProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await LocalDbService.instance.deleteCustomer(rawId);
              await posProv.loadCustomerHistory();
              await aiProv.loadAiData();
              messenger.showSnackBar(
                SnackBar(content: Text('🗑️ Kontak $displayName telah dihapus.'), backgroundColor: Colors.red.shade700),
              );
            },
            child: const Text('Hapus Kontak'),
          ),
        ],
      ),
    );
  }

  void _showPromoBlastDialog(BuildContext context, String clusterLabel) {
    final defaultMsg = clusterLabel.toLowerCase().contains('churn')
        ? 'Halo Kak! Kami kangen nih belanja bareng Kakak di toko kami. Dapatkan DISKON SPESIAL 15% untuk transaksi hari ini! Tunjukkan pesan ini ke kasir ya 😊'
        : 'Halo Pelanggan Setia! Terima kasih sudah selalu mempercayakan kebutuhan Anda di toko kami. Khusus hari ini nikmati BONUS POIN & VOUCHER Rp 10.000! 🎉';

    final messageController = TextEditingController(text: defaultMsg);
    bool isEditing = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final now = DateTime.now();
          final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Studio Promosi WhatsApp',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Target: Pelanggan $clusterLabel',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: ApiConstants.isOfflineMode
                                ? const Color(0xFF042F2E)
                                : const Color(0xFF1E1B4B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: ApiConstants.isOfflineMode
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            ApiConstants.isOfflineMode ? '⚡ 1-Tap WA' : '☁️ Cloud Blast',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: ApiConstants.isOfflineMode
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFA5B4FC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Toggle Preview vs Edit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? '✏️ Edit Pesan Promo:' : '📱 Pratinjau Chat WhatsApp:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => setDialogState(() => isEditing = !isEditing),
                          icon: Icon(isEditing ? Icons.visibility_outlined : Icons.edit_note_rounded, size: 14),
                          label: Text(
                            isEditing ? 'Lihat Pratinjau' : 'Kustomisasi Teks',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // WhatsApp Speech Bubble Preview / Edit Area
                    if (isEditing)
                      TextField(
                        controller: messageController,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tulis pesan promosi...',
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0C1410) : const Color(0xFFEFEAE2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1B2E24) : const Color(0xFFE2DCD5),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 380),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                topRight: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                                bottomRight: Radius.circular(2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  messageController.text,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: isDark ? Colors.white : const Color(0xFF111B21),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Spacer(),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.white60 : const Color(0xFF667781),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: Color(0xFF53BDEB),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),

                    // Actions Bar (Mobile-first responsive layout to prevent horizontal overflow)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                            icon: const Icon(Icons.send_rounded, size: 15),
                            label: const Text(
                              'Buka WhatsApp',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                                ),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: messageController.text.trim()));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('📋 Teks promosi berhasil disalin ke clipboard!'),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: const Text('Salin Teks', style: TextStyle(fontSize: 11.5)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
            side: BorderSide(color: isCritical ? AppColors.danger.withValues(alpha: 0.5) : AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCritical ? AppColors.danger.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title: Campaign Action Hub
          Row(
            children: [
              const Icon(Icons.campaign_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pusat Kampanye Promosi Cerdas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2 Executive Campaign Action Cards (Responsive layout)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 360;
              final card1 = _buildCampaignActionCard(
                title: 'Loyal VIP',
                countText: '${aiProvider.loyalCustomers.length} Pelanggan',
                subtitle: 'Apresiasi pelanggan setia dengan voucher reward',
                icon: Icons.workspace_premium_rounded,
                accentColor: const Color(0xFFD97706), // Warm Amber
                bgColor: isDark ? const Color(0xFF1C1914) : const Color(0xFFFFFBEB),
                borderColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
                buttonLabel: 'Kirim Promo VIP',
                onTap: () => _showPromoBlastDialog(context, 'Loyal'),
                isDark: isDark,
              );
              final card2 = _buildCampaignActionCard(
                title: 'Beresiko Churn',
                countText: '${aiProvider.churnRiskCustomers.length} Pelanggan',
                subtitle: 'Ajak kembali pelanggan yang lama tidak berkunjung',
                icon: Icons.replay_circle_filled_rounded,
                accentColor: const Color(0xFFE11D48), // Rose / Terracotta
                bgColor: isDark ? const Color(0xFF1F1418) : const Color(0xFFFFF1F2),
                borderColor: isDark ? const Color(0xFF881337) : const Color(0xFFFECDD3),
                buttonLabel: 'Ajak Kembali',
                onTap: () => _showPromoBlastDialog(context, 'Beresiko Churn'),
                isDark: isDark,
              );

              if (isSmall) {
                return Column(
                  children: [
                    card1,
                    const SizedBox(height: 10),
                    card2,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 12),
                  Expanded(child: card2),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Section Title: Customer List (Daftar Pelanggan Tersegmentasi)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daftar Pelanggan Tersegmentasi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${aiProvider.clusters.length} Pelanggan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.person_add_rounded, size: 14, color: AppColors.primary),
                label: const Text(
                  '+ Tambah',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                onPressed: () => _showAddCustomerDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (aiProvider.clusters.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.person_search_rounded, size: 40, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'Belum Ada Data Pelanggan Terdeteksi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Input nama & no. WhatsApp saat transaksi kasir agar AI dapat menganalisis segmentasi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
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

              final accentColor = isLoyal
                  ? const Color(0xFFD97706)
                  : isChurn
                      ? const Color(0xFFE11D48)
                      : AppColors.primary;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: accentColor.withValues(alpha: 0.12),
                        child: Icon(
                          isLoyal
                              ? Icons.workspace_premium_rounded
                              : isChurn
                                  ? Icons.person_off_rounded
                                  : Icons.person_rounded,
                          color: accentColor,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isLoyal ? 'VIP' : (isChurn ? 'CHURN' : 'REGULER'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${cluster.frequencyCount}x belanja • Total ${CurrencyFormatter.format(cluster.monetaryValue)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      phone,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: isDark ? const Color(0xFF042F2E) : const Color(0xFFECFDF5),
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 13, color: Color(0xFF059669)),
                          label: const Text(
                            'Chat WA',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                          ),
                          onPressed: () {
                            final promoMsg = isChurn
                                ? 'Halo Kak $displayName! Kami kangen nih belanja bareng Kakak di toko kami. Ada voucher diskon 15% khusus hari ini ya 😊'
                                : 'Halo Kak $displayName! Terima kasih telah jadi pelanggan setia kami. Dapatkan penawaran istimewa khusus hari ini 🎉';
                            _launchWhatsApp(phone: phone, message: promoMsg);
                          },
                        ),
                      ],
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: isDark ? AppColors.darkCard : Colors.white,
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showCustomerEditDialog(context, cluster.customerId, displayName, phone);
                          } else if (val == 'delete') {
                            _showCustomerDeleteDialog(context, cluster.customerId, displayName);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('Edit Kontak', style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: const [
                                Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
                                SizedBox(width: 8),
                                Text('Hapus Kontak', style: TextStyle(fontSize: 12.5, color: AppColors.danger)),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildCampaignActionCard({
    required String title,
    required String countText,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    required String buttonLabel,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  countText,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textMain,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.send_rounded, size: 12),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
