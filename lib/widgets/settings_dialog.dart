import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _openWebStore(String machineId) async {
    final uri = Uri.parse('https://weboz.my.id/larisai?mid=$machineId');
    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka halaman web: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String machineId) async {
    final waText = 'Halo Admin Weboz, saya ingin membeli/aktivasi lisensi LarisAI untuk Machine ID: $machineId';
    final encoded = Uri.encodeComponent(waText);
    
    final waUrlScheme = 'whatsapp://send?phone=628881264995&text=$encoded';
    final waWebUrl = 'https://wa.me/628881264995?text=$encoded';

    try {
      final uriWeb = Uri.parse(waWebUrl);
      bool launched = await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
      
      if (!launched) {
        final uriScheme = Uri.parse(waUrlScheme);
        launched = await launchUrl(uriScheme, mode: LaunchMode.externalApplication);
      }

      if (!launched) {
        await launchUrl(uriWeb, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        final uriScheme = Uri.parse(waUrlScheme);
        await launchUrl(uriScheme, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp. Silakan hubungi 0888-1264-995 secara manual.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
            subtitle: ExportService.instance.isDesktopPlatform
                ? 'Simpan file CSV transaksi ke folder komputer pilihan Anda'
                : 'Riwayat transaksi, omset, metode bayar, dan rincian item',
            onTap: () async {
              try {
                final result = await ExportService.instance.exportTransactionsCsv();
                if (mounted && result.success && result.filePath != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Laporan CSV berhasil disimpan!\n${result.filePath}'),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 4),
                      action: ExportService.instance.isDesktopPlatform
                          ? SnackBarAction(
                              label: 'Buka Folder',
                              textColor: Colors.white,
                              onPressed: () => ExportService.instance.openInExplorer(result.filePath!),
                            )
                          : null,
                    ),
                  );
                } else if (mounted && !result.isCancelled && result.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
                  );
                }
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
            subtitle: ExportService.instance.isDesktopPlatform
                ? 'Simpan file CSV katalog dan stok ke folder komputer'
                : 'Daftar semua produk, stok, harga, dan kode barcode',
            onTap: () async {
              try {
                final result = await ExportService.instance.exportInventoryCsv();
                if (mounted && result.success && result.filePath != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Katalog CSV berhasil disimpan!\n${result.filePath}'),
                      backgroundColor: Colors.blue.shade700,
                      duration: const Duration(seconds: 4),
                      action: ExportService.instance.isDesktopPlatform
                          ? SnackBarAction(
                              label: 'Buka Folder',
                              textColor: Colors.white,
                              onPressed: () => ExportService.instance.openInExplorer(result.filePath!),
                            )
                          : null,
                    ),
                  );
                } else if (mounted && !result.isCancelled && result.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
                  );
                }
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

          const Text('Cadangan & Pemulihan (Backup & Restore)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          const SizedBox(height: 4),
          const Text('Simpan seluruh database SQLite ke direktori lokal PC/HP atau pulihkan cadangan yang ada.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          // Button 3: Full Backup JSON (Save to Local Folder on Desktop)
          _buildActionButton(
            icon: Icons.cloud_download_rounded,
            color: Colors.purple.shade700,
            title: 'Cadangkan Database Lengkap (.json)',
            subtitle: ExportService.instance.isDesktopPlatform
                ? 'Pilih direktori lokal di PC untuk menyimpan file cadangan'
                : 'Cadangkan seluruh tabel transaksi, stok, dan pelanggan',
            onTap: () async {
              try {
                final result = await ExportService.instance.exportFullBackupJson();
                if (mounted && result.success && result.filePath != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Cadangan database tersimpan!\n${result.filePath}'),
                      backgroundColor: Colors.purple.shade700,
                      duration: const Duration(seconds: 4),
                      action: ExportService.instance.isDesktopPlatform
                          ? SnackBarAction(
                              label: 'Buka Folder',
                              textColor: Colors.white,
                              onPressed: () => ExportService.instance.openInExplorer(result.filePath!),
                            )
                          : null,
                    ),
                  );
                } else if (mounted && !result.isCancelled && result.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal backup: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // Button 4: Restore Backup from JSON
          _buildActionButton(
            icon: Icons.settings_backup_restore_rounded,
            color: Colors.teal.shade700,
            title: 'Pulihkan Database dari File (.json)',
            subtitle: 'Pilih file backup .json dari komputer/HP untuk memulihkan transaksi & produk',
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final posProvider = Provider.of<PosProvider>(context, listen: false);
              final aiProvider = Provider.of<AiProvider>(context, listen: false);

              try {
                final res = await ExportService.instance.pickAndRestoreBackup();
                if (res != null && mounted) {
                  await posProvider.loadProducts();
                  await posProvider.loadSummary();
                  await aiProvider.loadAiData();

                  final counts = res['counts'] as Map<String, int>? ?? {};
                  final prodCount = counts['products_restored'] ?? 0;
                  final txCount = counts['transactions_restored'] ?? 0;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✅ Berhasil memulihkan $prodCount produk dan $txCount transaksi!'),
                      backgroundColor: Colors.teal.shade700,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Gagal memulihkan database: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),

          if (ExportService.instance.isDesktopPlatform) ...[
            // Button 5: Open Dedicated Backup Folder in Explorer (Desktop Only)
            _buildActionButton(
              icon: Icons.folder_open_rounded,
              color: Colors.blueGrey.shade700,
              title: 'Buka Folder Cadangan Otomatis',
              subtitle: 'Buka direktori penyimpanan auto-backup di Windows File Explorer',
              onTap: () async {
                final dir = await ExportService.instance.getDedicatedBackupDirectory();
                await ExportService.instance.openInExplorer(dir.path);
              },
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // --- DANGER ZONE / DATA RESET ---
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
              const SizedBox(width: 6),
              Text(
                'Zona Bahaya & Reset Data',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Gunakan setelah masa uji coba / training kasir atau tutup buku tahunan. Sistem otomatis mencadangkan data sebelum dihapus.',
            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Option 1: Bersihkan Riwayat Transaksi Saja
          _buildActionButton(
            icon: Icons.delete_sweep_rounded,
            color: Colors.amber.shade800,
            title: 'Hapus Riwayat Transaksi Saja',
            subtitle: 'Reset omzet & nota kasir ke Rp 0. Katalog produk & stok TETAP AMAN.',
            onTap: () => _confirmResetTransactions(context),
          ),
          const SizedBox(height: 8),

          // Option 2: Factory Reset Database (Reset Semua)
          _buildActionButton(
            icon: Icons.delete_forever_rounded,
            color: Colors.red.shade700,
            title: 'Reset Pabrik Database (Hapus Semua)',
            subtitle: 'Mengosongkan semua transaksi & produk. Hak lisensi perangkat tetap aktif.',
            onTap: () => _confirmFactoryReset(context),
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

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Belum Memiliki Lisensi?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          const SizedBox(height: 4),
          const Text('Dapatkan lisensi resmi seumur hidup (Lifetime) atau langganan Cloud SaaS melalui portal Weboz Store.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 10),

          // CTA Button 1: Weboz Official Store
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal.shade800,
                side: BorderSide(color: Colors.teal.shade400, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: Colors.teal.shade50.withValues(alpha: 0.5),
              ),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Beli Lisensi Resmi di Weboz.my.id', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
              onPressed: () => _openWebStore(info.machineId),
            ),
          ),

          const SizedBox(height: 8),

          // CTA Button 2: WhatsApp Sales & Support
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade800,
                side: BorderSide(color: Colors.green.shade400, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: Colors.green.shade50.withValues(alpha: 0.5),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Chat WhatsApp Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
              onPressed: () => _openWhatsApp(info.machineId),
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

  Future<void> _confirmResetTransactions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final aiProvider = Provider.of<AiProvider>(context, listen: false);

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Hapus Riwayat Transaksi?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tindakan ini akan menghapus seluruh data transaksi, nota kasir, dan laporan omzet kembali ke Rp 0.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade800, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Katalog produk, harga, dan stok Anda TETAP AMAN dan tidak akan terhapus.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Sistem akan otomatis membuat cadangan (.json) sebelum pembersihan dimulai.',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus Transaksi'),
          ),
        ],
      ),
    );

    if (shouldReset == true && mounted) {
      try {
        // 1. Silent auto-backup to local disk (never blocks or throws UI popups)
        final backupPath = await ExportService.instance.createSilentBackupJson();

        // 2. Clear transactions & reset metrics to real zero
        await posProvider.clearTransactions();
        await aiProvider.loadAiData();

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              backupPath != null
                  ? '✅ Riwayat transaksi dibersihkan! Omset kembali Rp 0.\nCadangan aman: ${backupPath.split(Platform.isWindows ? '\\' : '/').last}'
                  : '✅ Riwayat transaksi berhasil dibersihkan! Omset kembali ke Rp 0.',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
            action: backupPath != null && ExportService.instance.isDesktopPlatform
                ? SnackBarAction(
                    label: 'Buka Cadangan',
                    textColor: Colors.white,
                    onPressed: () => ExportService.instance.openInExplorer(backupPath),
                  )
                : null,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal reset transaksi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmFactoryReset(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final aiProvider = Provider.of<AiProvider>(context, listen: false);
    final confirmController = TextEditingController();

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.dangerous_rounded, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '🚨 Reset Pabrik Database?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PERINGATAN: Tindakan ini akan MENGHAPUS SEMUA transaksi dan SELURUH katalog produk di database.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hak lisensi perangkat Anda tetap tersimpan dan aktif. Salinan cadangan .json akan otomatis disimpan sebelum reset.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              const Text(
                'Untuk konfirmasi, ketik kata "HAPUS" di bawah ini:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: confirmController,
                autofocus: true,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                decoration: const InputDecoration(
                  hintText: 'Ketik HAPUS',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: confirmController.text.trim().toUpperCase() == 'HAPUS'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Reset Total'),
            ),
          ],
        ),
      ),
    );

    if (shouldReset == true && mounted) {
      try {
        // 1. Silent auto-backup to local disk
        final backupPath = await ExportService.instance.createSilentBackupJson();

        // 2. Wipe database (products & transactions)
        await posProvider.factoryResetDatabase(reseedStarterProducts: false);
        await aiProvider.loadAiData();

        messenger.showSnackBar(
          SnackBar(
            content: const Text('✅ Database berhasil di-reset total! Produk & transaksi telah dikosongkan.'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            action: backupPath != null && ExportService.instance.isDesktopPlatform
                ? SnackBarAction(
                    label: 'Buka Cadangan',
                    textColor: Colors.white,
                    onPressed: () => ExportService.instance.openInExplorer(backupPath),
                  )
                : null,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal reset pabrik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = (mediaQuery.size.width * 0.92).clamp(280.0, 480.0);
    final dialogHeight = (mediaQuery.size.height * 0.60).clamp(320.0, 480.0);

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
        width: dialogWidth,
        height: dialogHeight,
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
