import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../providers/pos_provider.dart';
import '../providers/ai_provider.dart';
import '../services/export_service.dart';
import '../services/license_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _posController;
  late TextEditingController _aiController;
  late TextEditingController _licenseController;
  late ConnectionMode _selectedMode;
  bool _showAdvanced = false;

  LicenseInfo? _licenseInfo;
  bool _isLoadingLicense = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMode = ApiConstants.currentMode;
    _posController = TextEditingController(text: ApiConstants.posBaseUrl);
    _aiController = TextEditingController(text: ApiConstants.aiBaseUrl);
    _licenseController = TextEditingController();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    final info = await LicenseService.instance.getLicenseInfo();
    if (mounted) {
      setState(() {
        _licenseInfo = info;
        _isLoadingLicense = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _posController.dispose();
    _aiController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  void _selectMode(ConnectionMode mode) {
    setState(() {
      _selectedMode = mode;
      switch (mode) {
        case ConnectionMode.offline:
          _posController.text = 'local://sqlite';
          _aiController.text = 'local://sqlite';
          break;
        case ConnectionMode.cloud:
          _posController.text = ApiConstants.cloudPosBaseUrl;
          _aiController.text = ApiConstants.cloudAiBaseUrl;
          break;
        case ConnectionMode.usb:
          _posController.text = ApiConstants.usbPosBaseUrl;
          _aiController.text = ApiConstants.usbAiBaseUrl;
          break;
        case ConnectionMode.wifi:
          _posController.text = ApiConstants.lanPosBaseUrl;
          _aiController.text = ApiConstants.lanAiBaseUrl;
          break;
      }
    });
  }

  Widget _buildModeCard({
    required ConnectionMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color accentColor,
  }) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accentColor.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? accentColor : Colors.grey.shade500, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? accentColor : AppColors.textMain,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: accentColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeCard(
            mode: ConnectionMode.offline,
            icon: Icons.offline_bolt_rounded,
            title: '📦 Lifetime Mode',
            subtitle: '100% Offline — Database tersimpan di SQLite HP tanpa server',
            badgeText: 'LIFETIME',
            badgeColor: Colors.teal.shade700,
            accentColor: Colors.teal.shade700,
          ),
          _buildModeCard(
            mode: ConnectionMode.cloud,
            icon: Icons.cloud_done_rounded,
            title: '☁️ Subscription SaaS',
            subtitle: 'Cloud Atlas — Sinkron multi-device & AI realtime',
            badgeText: 'SUBSCRIPTION',
            badgeColor: Colors.indigo.shade700,
            accentColor: Colors.indigo.shade700,
          ),
          _buildModeCard(
            mode: ConnectionMode.usb,
            icon: Icons.usb_rounded,
            title: '🔌 Dev: Kabel USB',
            subtitle: 'adb reverse — Terhubung ke backend laptop',
            badgeText: 'DEV',
            badgeColor: Colors.blue.shade700,
            accentColor: Colors.blue.shade700,
          ),
          _buildModeCard(
            mode: ConnectionMode.wifi,
            icon: Icons.wifi_rounded,
            title: '📶 Dev: Wi-Fi LAN',
            subtitle: 'Jaringan Wi-Fi lokal kantor / toko',
            badgeText: 'LAN',
            badgeColor: Colors.orange.shade800,
            accentColor: Colors.orange.shade800,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(
              children: [
                Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 4),
                const Text('Kustomisasi Endpoint (Advanced)', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 8),
            const Text('POS Backend URL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _posController,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
            ),
            const SizedBox(height: 8),
            const Text('AI Engine URL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _aiController,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ekspor Laporan & Pembukuan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          const SizedBox(height: 4),
          const Text('Unduh laporan dalam format CSV yang kompatibel dengan Microsoft Excel dan Google Sheets.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          // Button 1: Export Transactions
          _buildActionButton(
            icon: Icons.table_chart_rounded,
            color: Colors.green.shade700,
            title: 'Ekspor Laporan Penjualan (CSV)',
            subtitle: 'Riwayat transaksi, omset, metode bayar, dan rincian item',
            onTap: () async {
              try {
                await ExportService.instance.exportTransactionsCsv();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal ekspor: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // Button 2: Export Inventory
          _buildActionButton(
            icon: Icons.inventory_2_rounded,
            color: Colors.blue.shade700,
            title: 'Ekspor Katalog Produk (CSV)',
            subtitle: 'Daftar semua produk, stok, harga, dan kode barcode',
            onTap: () async {
              try {
                await ExportService.instance.exportInventoryCsv();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal ekspor: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),

          const Text('Cadangan & Pemulihan (Backup)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          const SizedBox(height: 4),
          const Text('Simpan seluruh data database SQLite ke file backup untuk dipindahkan ke komputer/HP lain.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          // Button 3: Full Backup JSON
          _buildActionButton(
            icon: Icons.cloud_download_rounded,
            color: Colors.purple.shade700,
            title: 'Backup Database Lengkap (.json)',
            subtitle: 'Cadangkan seluruh tabel transaksi, stok, dan pelanggan',
            onTap: () async {
              try {
                await ExportService.instance.exportFullBackupJson();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal backup: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseTab() {
    if (_isLoadingLicense) {
      return const Center(child: CircularProgressIndicator());
    }

    final info = _licenseInfo!;
    final isLifetime = info.type == LicenseType.lifetime;
    final isSubs = info.type == LicenseType.subscription;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // License Status Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLifetime 
                    ? [Colors.teal.shade800, Colors.teal.shade600]
                    : (isSubs ? [Colors.indigo.shade800, Colors.indigo.shade600] : [Colors.amber.shade900, Colors.amber.shade700]),
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      info.typeDisplay,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        info.isValid ? 'AKTIF' : 'KADALUWARSA',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Hardware Machine ID:',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
                ),
                Text(
                  info.machineId,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                if (!isLifetime && info.expiresAt != null)
                  Text(
                    'Sisa Masa Aktif: ${info.daysRemaining} Hari',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text('Aktivasi Serial Key Lisensi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          const SizedBox(height: 4),
          const Text('Masukkan Serial Key aktivasi Lifetime atau SaaS yang Anda terima saat pembelian.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 10),

          TextField(
            controller: _licenseController,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            decoration: InputDecoration(
              hintText: 'LRS-LIFE-XXXX-XXXX-XXXX',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1),
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.verified_user_rounded, size: 18),
              label: const Text('Aktifkan Lisensi Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final key = _licenseController.text.trim();
                if (key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Silakan masukkan Serial Key lisensi.'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                try {
                  await LicenseService.instance.activateLicense(key);
                  await _loadLicense();
                  _licenseController.clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🎉 Lisensi berhasil diaktifkan secara permanen!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal aktivasi: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMain)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pengaturan LarisAI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Mode database, backup data & lisensi', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Mode Server'),
              Tab(text: 'Laporan & Data'),
              Tab(text: 'Lisensi'),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 380,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildNetworkTab(),
            _buildExportTab(),
            _buildLicenseTab(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Simpan Pengaturan'),
          onPressed: () async {
            await ApiConstants.setMode(_selectedMode);
            if (_showAdvanced) {
              await ApiConstants.setUrls(
                posUrl: _posController.text.trim(),
                aiUrl: _aiController.text.trim(),
              );
            }

            if (!context.mounted) return;

            // Refresh data in providers
            Provider.of<PosProvider>(context, listen: false).loadProducts();
            Provider.of<AiProvider>(context, listen: false).loadAiData();

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Mode ${ApiConstants.modeLabel} tersimpan!'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}
