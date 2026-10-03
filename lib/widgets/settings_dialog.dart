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
import '../services/store_profile_service.dart';

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

  late TextEditingController _storeNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _storeAddressController;
  late TextEditingController _storePhoneController;
  late TextEditingController _receiptFooterController;

  LicenseInfo? _licenseInfo;
  bool _isLoadingLicense = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedMode = ApiConstants.currentMode;
    _posController = TextEditingController(text: ApiConstants.posBaseUrl);
    _aiController = TextEditingController(text: ApiConstants.aiBaseUrl);
    _licenseController = TextEditingController();

    final profile = StoreProfileService.instance.profile;
    _storeNameController = TextEditingController(text: profile.storeName);
    _ownerNameController = TextEditingController(text: profile.ownerName);
    _storeAddressController = TextEditingController(text: profile.storeAddress);
    _storePhoneController = TextEditingController(text: profile.storePhone);
    _receiptFooterController = TextEditingController(text: profile.receiptFooter);

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
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _receiptFooterController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? AppColors.darkSurface : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: isDark ? 0.25 : 0.15)
                    : (isDark ? AppColors.darkCard : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? accentColor : (isDark ? AppColors.darkTextMuted : Colors.grey.shade500), size: 22),
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
                          color: isSelected ? accentColor : (isDark ? AppColors.darkTextMain : AppColors.textMain),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.15),
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
                  Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: accentColor, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _saveStoreProfile() async {
    await StoreProfileService.instance.saveProfile(
      StoreProfile(
        storeName: _storeNameController.text.trim().isEmpty ? 'TOKO LARIS UMKM' : _storeNameController.text.trim(),
        ownerName: _ownerNameController.text.trim().isEmpty ? 'Kasir 01' : _ownerNameController.text.trim(),
        storeAddress: _storeAddressController.text.trim(),
        storePhone: _storePhoneController.text.trim(),
        receiptFooter: _receiptFooterController.text.trim().isEmpty
            ? 'Terima Kasih Atas Kunjungan Anda!'
            : _receiptFooterController.text.trim(),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profil Toko & UMKM berhasil disimpan!'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildStoreProfileTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identitas Usaha & Struk Kasir',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Data ini otomatis dicetak pada struk thermal, file PDF, serta header sistem POS.',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          _buildProfileInputField(
            controller: _storeNameController,
            label: 'Nama UMKM / Toko',
            hint: 'Contoh: Toko Berkah Jaya UMKM',
            icon: Icons.storefront_rounded,
          ),
          const SizedBox(height: 10),

          _buildProfileInputField(
            controller: _ownerNameController,
            label: 'Nama Pemilik / Kasir Utama',
            hint: 'Contoh: Budi Santoso / Kasir 01',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 10),

          _buildProfileInputField(
            controller: _storeAddressController,
            label: 'Alamat Usaha',
            hint: 'Contoh: Jl. Pasar Ritel No. 88, Indonesia',
            icon: Icons.place_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 10),

          _buildProfileInputField(
            controller: _storePhoneController,
            label: 'Nomor Telepon / WhatsApp',
            hint: 'Contoh: 0812-3456-7890',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),

          _buildProfileInputField(
            controller: _receiptFooterController,
            label: 'Catatan Kaki Struk (Footer)',
            hint: 'Contoh: Terima Kasih Atas Kunjungan Anda!',
            icon: Icons.receipt_long_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saveStoreProfile,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Simpan Profil UMKM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextMain : AppColors.textMain,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.6) : Colors.grey.shade400,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                Icon(
                  _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Kustomisasi Endpoint (Advanced)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 8),
            Text(
              'POS Backend URL:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _posController,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI Engine URL:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _aiController,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ekspor Laporan & Pembukuan Excel (.xlsx)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unduh laporan dalam format Microsoft Excel murni (.xlsx). Bebas kendala pemisah desimal koma/titik regional.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Button 1: Export Transactions (Excel .xlsx)
          _buildActionButton(
            icon: Icons.table_view_rounded,
            color: Colors.green.shade800,
            title: 'Ekspor Laporan Penjualan (Excel .xlsx)',
            subtitle: ExportService.instance.isDesktopPlatform
                ? 'Multi-sheet: Sheet 1 (Ringkasan) & Sheet 2 (Rincian Item Terjual)'
                : 'Unduh file Excel lengkap transaksi dan rincian item',
            onTap: () async {
              try {
                final result = await ExportService.instance.exportTransactionsExcel();
                if (mounted && result.success && result.filePath != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
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
                } else if (mounted && !result.isCancelled && result.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal ekspor Excel: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // Button 2: Export Inventory (Excel .xlsx)
          _buildActionButton(
            icon: Icons.inventory_2_rounded,
            color: Colors.teal.shade800,
            title: 'Ekspor Katalog Produk (Excel .xlsx)',
            subtitle: ExportService.instance.isDesktopPlatform
                ? 'Simpan file Excel daftar inventori, stok, barcode, dan harga jual'
                : 'Daftar semua produk dan status stok dalam format Excel',
            onTap: () async {
              try {
                final result = await ExportService.instance.exportInventoryExcel();
                if (mounted && result.success && result.filePath != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Katalog Excel (.xlsx) berhasil disimpan!\n${result.filePath}'),
                      backgroundColor: Colors.teal.shade800,
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
                } else if (mounted && !result.isCancelled && result.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message!), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal ekspor Excel: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // Button 3: Legacy CSV Export
          _buildActionButton(
            icon: Icons.file_present_rounded,
            color: Colors.blueGrey.shade700,
            title: 'Ekspor Format CSV (Teks Alternatif)',
            subtitle: 'Format CSV klasik untuk integrasi software legacy atau script data',
            onTap: () async {
              try {
                final result = await ExportService.instance.exportTransactionsCsv();
                if (mounted && result.success && result.filePath != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Laporan CSV berhasil disimpan!\n${result.filePath}'),
                      backgroundColor: Colors.blueGrey.shade700,
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
          Divider(color: isDark ? AppColors.darkBorder : null),
          const SizedBox(height: 8),

          Text(
            'Cadangan & Pemulihan (Backup & Restore)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Simpan seluruh database SQLite ke direktori lokal PC/HP atau pulihkan cadangan yang ada.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
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
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.teal, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Pulihkan Database?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'Pemulihan database akan mengganti seluruh katalog produk, stok, dan riwayat transaksi saat ini dengan data yang ada di dalam file cadangan (.json).\n\nApakah Anda yakin ingin melanjutkan?',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        'Batal',
                        style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Pilih File & Pulihkan'),
                    ),
                  ],
                ),
              );

              if (confirmed != true || !mounted) return;

              final messenger = ScaffoldMessenger.of(context);
              final posProvider = Provider.of<PosProvider>(context, listen: false);
              final aiProvider = Provider.of<AiProvider>(context, listen: false);

              try {
                final res = await ExportService.instance.pickAndRestoreBackup();
                if (res != null && mounted) {
                  posProvider.clearCart();
                  await posProvider.loadProducts();
                  await posProvider.loadSummary();
                  await aiProvider.loadAiData();

                  final counts = res['counts'] as Map<String, int>? ?? {};
                  final prodCount = counts['products_restored'] ?? 0;
                  final txCount = counts['transactions_restored'] ?? 0;
                  final fileName = res['name']?.toString() ?? 'file';

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✅ Berhasil memulihkan database dari $fileName! ($prodCount produk, $txCount transaksi)'),
                      backgroundColor: Colors.teal.shade700,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('ℹ️ Pemulihan dibatalkan (tidak ada file dipilih).'),
                      backgroundColor: Colors.blueGrey,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('❌ Gagal memulihkan database: $e'),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 5),
                    ),
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
          Divider(color: isDark ? AppColors.darkBorder : null),
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
          Text(
            'Gunakan setelah masa uji coba / training kasir atau tutup buku tahunan. Sistem otomatis mencadangkan data sebelum dihapus.',
            style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Text(
            'Aktivasi Serial Key Lisensi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Masukkan Serial Key aktivasi Lifetime atau SaaS yang Anda terima saat pembelian.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _licenseController,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
            ),
            decoration: InputDecoration(
              hintText: 'LRS-LIFE-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(
                color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.6) : Colors.grey,
                fontSize: 12,
                letterSpacing: 1,
              ),
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
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
          Divider(color: isDark ? AppColors.darkBorder : null),
          const SizedBox(height: 12),
          Text(
            'Belum Memiliki Lisensi?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dapatkan lisensi resmi seumur hidup (Lifetime) atau langganan Cloud SaaS melalui portal Weboz Store.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),

          // CTA Button 1: Weboz Official Store
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
                side: BorderSide(color: isDark ? Colors.teal.shade600 : Colors.teal.shade400, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: isDark ? Colors.teal.shade900.withValues(alpha: 0.3) : Colors.teal.shade50.withValues(alpha: 0.5),
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
                foregroundColor: isDark ? Colors.green.shade300 : Colors.green.shade800,
                side: BorderSide(color: isDark ? Colors.green.shade600 : Colors.green.shade400, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50.withValues(alpha: 0.5),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetTransactions(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final aiProvider = Provider.of<AiProvider>(context, listen: false);

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hapus Riwayat Transaksi?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tindakan ini akan menghapus seluruh data transaksi, nota kasir, dan laporan omzet kembali ke Rp 0.',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMain : null),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.green.shade700 : Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: isDark ? Colors.green.shade300 : Colors.green.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Katalog produk, harga, dan stok Anda TETAP AMAN dan tidak akan terhapus.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.green.shade100 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 Sistem akan otomatis membuat cadangan (.json) sebelum pembersihan dimulai.',
              style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final aiProvider = Provider.of<AiProvider>(context, listen: false);
    final confirmController = TextEditingController();

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
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
              Text(
                'Hak lisensi perangkat Anda tetap tersimpan dan aktif. Salinan cadangan .json akan otomatis disimpan sebelum reset.',
                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                'Untuk konfirmasi, ketik kata "HAPUS" di bawah ini:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: confirmController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
                decoration: InputDecoration(
                  hintText: 'Ketik HAPUS',
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = (mediaQuery.size.width * 0.92).clamp(280.0, 480.0);
    final dialogHeight = (mediaQuery.size.height * 0.60).clamp(320.0, 480.0);

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan LarisAI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                      ),
                    ),
                    Text(
                      'Profil UMKM, mode server & backup data',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Profil UMKM'),
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
            _buildStoreProfileTab(),
            _buildNetworkTab(),
            _buildExportTab(),
            _buildLicenseTab(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Tutup',
            style: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Simpan Pengaturan'),
          onPressed: () async {
            // Save Store Profile
            await StoreProfileService.instance.saveProfile(
              StoreProfile(
                storeName: _storeNameController.text.trim().isEmpty ? 'TOKO LARIS UMKM' : _storeNameController.text.trim(),
                ownerName: _ownerNameController.text.trim().isEmpty ? 'Kasir 01' : _ownerNameController.text.trim(),
                storeAddress: _storeAddressController.text.trim(),
                storePhone: _storePhoneController.text.trim(),
                receiptFooter: _receiptFooterController.text.trim().isEmpty
                    ? 'Terima Kasih Atas Kunjungan Anda!'
                    : _receiptFooterController.text.trim(),
              ),
            );

            // Save Connection Mode & URLs
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
              const SnackBar(
                content: Text('✅ Pengaturan & Profil UMKM berhasil disimpan!'),
                backgroundColor: AppColors.primary,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}
