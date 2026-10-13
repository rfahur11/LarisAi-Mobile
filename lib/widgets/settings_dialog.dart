import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../providers/pos_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/scanner_screen.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../services/license_service.dart';
import '../services/local_host_server_service.dart';
import '../services/store_profile_service.dart';
import '../services/cloud_health_service.dart';
import '../services/excel_import_service.dart';
import '../services/data_migration_service.dart';
import 'bulk_import_dialog.dart';
import 'saas_payment_sheet.dart';

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

  final TextEditingController _authEmailController = TextEditingController();
  final TextEditingController _authPasswordController = TextEditingController();

  int _cloudAuthTab = 0; // 0: Login, 1: Register
  bool _showSandboxTour = false;
  String? _authFeedbackMessage;
  bool _isAuthFeedbackError = false;
  final TextEditingController _regOwnerNameController = TextEditingController();
  final TextEditingController _regStoreNameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPhoneController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();

  LicenseInfo? _licenseInfo;
  bool _isLoadingLicense = true;

  bool _isTestingLan = false;
  String? _lanTestStatus;
  String? _lanTestMessage;

  // In-Dialog Reactive Notification Banner
  String? _dialogNotificationMessage;
  Color _dialogNotificationColor = AppColors.primary;
  IconData _dialogNotificationIcon = Icons.check_circle_rounded;
  Timer? _dialogNotificationTimer;

  void showDialogNotification(
    String message, {
    Color? color,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    _dialogNotificationTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _dialogNotificationMessage = message;
      _dialogNotificationColor = color ?? AppColors.primary;
      _dialogNotificationIcon = icon ?? Icons.check_circle_outline_rounded;
    });

    _dialogNotificationTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _dialogNotificationMessage = null;
        });
      }
    });
  }

  Future<void> _testLanConnection(String targetUrl, [String? clusterToken]) async {
    if (targetUrl.trim().isEmpty) return;
    setState(() {
      _isTestingLan = true;
      _lanTestStatus = null;
      _lanTestMessage = null;
    });

    try {
      var url = targetUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      final token = clusterToken ?? AuthService.instance.lanClusterToken;
      final effectiveToken = token.isNotEmpty ? token : 'laris-lan-sec-key';
      final dio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {
          'x-cluster-auth': effectiveToken,
          'Authorization': 'Bearer $effectiveToken',
        },
      ));

      final sw = Stopwatch()..start();
      final res = await dio.get('/api/v1/health');
      sw.stop();

      if (res.statusCode == 200 && res.data != null) {
        final storeName = res.data['store_name'] ?? 'Toko Kasir Master';
        setState(() {
          _isTestingLan = false;
          _lanTestStatus = 'success';
          _lanTestMessage = '🟢 Terhubung: $storeName (${sw.elapsedMilliseconds} ms)';
        });
        return;
      }
      throw Exception('HTTP ${res.statusCode}');
    } catch (e) {
      setState(() {
        _isTestingLan = false;
        _lanTestStatus = 'error';
        _lanTestMessage = '🔴 Gagal: Pastikan Host Server aktif di Wi-Fi/Hotspot yang sama.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _selectedMode = ApiConstants.currentMode;
    _posController = TextEditingController(text: ApiConstants.posBaseUrl);
    _aiController = TextEditingController(text: ApiConstants.aiBaseUrl);
    _licenseController = TextEditingController();

    if (AuthService.instance.email != null && AuthService.instance.email!.isNotEmpty) {
      _authEmailController.text = AuthService.instance.email!;
    }

    final profile = StoreProfileService.instance.profile;
    _storeNameController = TextEditingController(text: profile.storeName);
    _ownerNameController = TextEditingController(text: profile.ownerName);
    _storeAddressController = TextEditingController(text: profile.storeAddress);
    _storePhoneController = TextEditingController(text: profile.storePhone);
    _receiptFooterController = TextEditingController(text: profile.receiptFooter);

    _loadLicense();
  }

  @override
  void dispose() {
    _dialogNotificationTimer?.cancel();
    _tabController.dispose();
    _posController.dispose();
    _aiController.dispose();
    _licenseController.dispose();
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _receiptFooterController.dispose();
    _authEmailController.dispose();
    _authPasswordController.dispose();
    _regOwnerNameController.dispose();
    _regStoreNameController.dispose();
    _regEmailController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    super.dispose();
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
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? accentColor : (isDark ? AppColors.darkTextMain : AppColors.textMain),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
      showDialogNotification(
        'Profil Toko & UMKM berhasil disimpan!',
        color: AppColors.primary,
        icon: Icons.check_circle_rounded,
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

  Widget _buildThemeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProv = Provider.of<ThemeProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mode Tampilan (Theme)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: themeProv.isDarkMode
                      ? Colors.indigo.withValues(alpha: 0.2)
                      : Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      themeProv.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      size: 13,
                      color: themeProv.isDarkMode ? Colors.indigoAccent : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      themeProv.isDarkMode ? 'Mode Gelap Aktif' : 'Mode Terang Aktif',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: themeProv.isDarkMode ? Colors.indigoAccent : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Sesuaikan kenyamanan mata kasir dengan kondisi pencahayaan toko Anda.',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Bright / Light Mode Card
          _buildThemeCard(
            title: 'Mode Terang (Bright / Light)',
            subtitle: 'Latar putih bersih dengan kontras optimal untuk siang hari atau toko terang.',
            icon: Icons.light_mode_rounded,
            isSelected: !themeProv.isDarkMode,
            activeColor: Colors.amber.shade700,
            previewBg: Colors.white,
            previewCard: const Color(0xFFF3F4F6),
            previewAccent: AppColors.primary,
            onTap: () => themeProv.setDarkMode(false),
          ),
          const SizedBox(height: 10),

          // Dark Mode Card
          _buildThemeCard(
            title: 'Mode Gelap (Dark Mode)',
            subtitle: 'Warna pekat elegan, mengurangi silau saat shift malam & hemat daya baterai.',
            icon: Icons.dark_mode_rounded,
            isSelected: themeProv.isDarkMode,
            activeColor: Colors.indigoAccent,
            previewBg: const Color(0xFF0F172A),
            previewCard: const Color(0xFF1E293B),
            previewAccent: const Color(0xFF38BDF8),
            onTap: () => themeProv.setDarkMode(true),
          ),
          const SizedBox(height: 12),

          // Quick switch row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: isDark ? AppColors.accent : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peralihan Cepat (Quick Switch)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                        ),
                      ),
                      Text(
                        'Ketuk saklar untuk beralih mode seketika',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: themeProv.isDarkMode,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) => themeProv.setDarkMode(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Info note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.primary : Colors.blue).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (isDark ? AppColors.primary : Colors.blue).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pilihan tema tersimpan permanen di perangkat ini dan langsung diterapkan ke seluruh fitur POS, Katalog, dan Laporan AI.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.35,
                      color: isDark ? AppColors.darkTextMuted : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color previewBg,
    required Color previewCard,
    required Color previewAccent,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? AppColors.darkSurface : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: isDark ? 0.3 : 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: previewBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: previewAccent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: previewCard,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: previewCard,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Icon(icon, size: 10, color: isSelected ? activeColor : Colors.grey),
                ],
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
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? activeColor : (isDark ? AppColors.darkTextMain : AppColors.textMain),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'AKTIF',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: activeColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
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
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? activeColor : (isDark ? AppColors.darkTextMuted : Colors.grey.shade400),
              size: 22,
            ),
          ],
        ),
      ),
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
          if (_selectedMode == ConnectionMode.cloud) ...[
            _buildStoreAccountSection(),
          ],
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
          if (_selectedMode == ConnectionMode.wifi) ...[
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi_tethering_rounded, size: 18, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Mode LAN Resto / Multi-Kasir Wi-Fi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '💡 100% Offline Lokal (Bebas Registrasi & Tanpa Internet)\nSemua kasir HP langsung terhubung ke PC Kasir Utama via Wi-Fi lokal. Tidak perlu mendaftar akun atau mengisi formulir data.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<bool>(
                    valueListenable: LocalHostServerService.instance.isRunning,
                    builder: (context, running, _) {
                      final url = LocalHostServerService.instance.serverUrl;
                      final token = LocalHostServerService.instance.clusterToken;
                      final pin = LocalHostServerService.instance.serverPin;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: running
                              ? (isDark ? Colors.teal.shade900.withValues(alpha: 0.3) : Colors.teal.shade50)
                              : (isDark ? AppColors.darkCard : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: running ? Colors.teal : Colors.orange.shade300,
                            width: running ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: running ? Colors.teal.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    running ? Icons.wifi_tethering_rounded : Icons.cell_tower_rounded,
                                    size: 20,
                                    color: running ? Colors.teal : Colors.orange.shade800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        running ? '👑 Server Host Aktif (Master Hub)' : 'Peran Server Host (Master Kasir)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: running ? (isDark ? Colors.tealAccent : Colors.teal.shade900) : (isDark ? AppColors.darkTextMain : AppColors.textMain),
                                        ),
                                      ),
                                      Text(
                                        running ? 'Melayani klien di $url' : 'Jadikan perangkat ini sebagai pusat database SQLite',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: running ? Colors.red.shade700 : Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () async {
                                    if (running) {
                                      await LocalHostServerService.instance.stopServer();
                                      await LocalHostServerService.instance.setAutoStartHost(false);
                                    } else {
                                      await LocalHostServerService.instance.startServer();
                                      await LocalHostServerService.instance.setAutoStartHost(true);
                                      _posController.text = 'http://127.0.0.1:${LocalHostServerService.instance.port}';
                                      _aiController.text = 'http://127.0.0.1:${LocalHostServerService.instance.port}';
                                    }
                                    setState(() {});
                                  },
                                  child: Text(
                                    running ? 'Matikan' : 'Aktifkan',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            if (running) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: jsonEncode({
                                      'url': url,
                                      'cluster_token': token,
                                      'pin': pin,
                                    }),
                                    version: QrVersions.auto,
                                    size: 130,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Pindai QR ini dari HP Kasir Klien untuk koneksi otomatis 1-detik',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      'PIN: $pin',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(Icons.refresh_rounded, size: 14),
                                    label: const Text('Refresh IP', style: TextStyle(fontSize: 11)),
                                    onPressed: () async {
                                      await LocalHostServerService.instance.refreshIp();
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              if (LocalHostServerService.instance.availableIps.length > 1) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Pilih IP Interface Server:',
                                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  children: LocalHostServerService.instance.availableIps.map((ip) {
                                    final isSel = LocalHostServerService.instance.localIp == ip;
                                    return ChoiceChip(
                                      label: Text(ip, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                      selected: isSel,
                                      selectedColor: Colors.teal.withValues(alpha: 0.3),
                                      onSelected: (val) {
                                        if (val) {
                                          LocalHostServerService.instance.setLocalIp(ip);
                                          setState(() {});
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Alamat IP Host (Kasir Master):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 14),
                        label: const Text('Scan QR Master', style: TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final scanned = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(builder: (_) => const ScannerScreen()),
                          );
                          if (scanned != null && scanned.isNotEmpty) {
                            try {
                              final data = jsonDecode(scanned);
                              if (data is Map && data['url'] != null) {
                                final hostUrl = data['url'].toString();
                                final clusterToken = data['cluster_token']?.toString() ?? 'laris-lan-sec-key';
                                final pin = data['pin']?.toString() ?? '1234';

                                await AuthService.instance.setLanClusterSession(
                                  clusterToken: clusterToken,
                                  pin: pin,
                                );

                                setState(() {
                                  _posController.text = hostUrl;
                                  _aiController.text = hostUrl;
                                });

                                await _testLanConnection(hostUrl, clusterToken);
                                return;
                              }
                            } catch (_) {}
                            setState(() {
                              _posController.text = scanned.trim();
                              _aiController.text = scanned.trim();
                            });
                            await _testLanConnection(scanned.trim());
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _posController,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Contoh: http://192.168.1.3:8080 atau 192.168.43.1:8080',
                      prefixIcon: const Icon(Icons.link_rounded, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? AppColors.darkCard : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.orange.shade300),
                          ),
                          icon: _isTestingLan
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.network_check_rounded, size: 16),
                          label: Text(
                            _isTestingLan ? 'Memeriksa...' : '🔍 Uji Sambungan Host',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isTestingLan
                              ? null
                              : () => _testLanConnection(_posController.text.trim()),
                        ),
                      ),
                    ],
                  ),
                  if (_lanTestMessage != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _lanTestStatus == 'success'
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _lanTestStatus == 'success' ? Colors.green : Colors.red,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lanTestStatus == 'success' ? Icons.check_circle_rounded : Icons.error_rounded,
                            size: 16,
                            color: _lanTestStatus == 'success' ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _lanTestMessage!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _lanTestStatus == 'success'
                                    ? (isDark ? Colors.greenAccent : Colors.green.shade900)
                                    : (isDark ? Colors.redAccent : Colors.red.shade900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Hotspot (192.168.43.1)', style: TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _posController.text = 'http://192.168.43.1:8080';
                            _aiController.text = 'http://192.168.43.1:8080';
                          });
                          _testLanConnection('http://192.168.43.1:8080');
                        },
                      ),
                      ActionChip(
                        label: const Text('Lokal (127.0.0.1)', style: TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _posController.text = 'http://127.0.0.1:8080';
                            _aiController.text = 'http://127.0.0.1:8080';
                          });
                          _testLanConnection('http://127.0.0.1:8080');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildInlineAuthFeedback() {
    if (_authFeedbackMessage == null || _authFeedbackMessage!.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _isAuthFeedbackError
            ? (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50)
            : (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isAuthFeedbackError ? Colors.redAccent : Colors.green,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isAuthFeedbackError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: _isAuthFeedbackError ? Colors.redAccent : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _authFeedbackMessage!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isAuthFeedbackError
                    ? (isDark ? Colors.red.shade200 : Colors.red.shade800)
                    : (isDark ? Colors.green.shade200 : Colors.green.shade800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreAccountSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = AuthService.instance;
    final health = CloudHealthService.instance;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub_rounded,
                size: 18,
                color: auth.isLoggedIn ? Colors.green.shade600 : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  auth.isLoggedIn ? 'Profil Toko Cloud & Status Lisensi' : 'Hubungkan / Daftarkan Akun Toko',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (auth.isLoggedIn ? Colors.green : Colors.amber).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: auth.isLoggedIn ? Colors.green : Colors.amber.shade800,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      auth.isLoggedIn ? 'TERHUBUNG' : 'BELUM LOGIN',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: auth.isLoggedIn ? Colors.green.shade700 : Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (auth.isLoggedIn) ...[
            // 1. Store Profile & Subscription Hub Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.storeName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Store ID: ${auth.storeId ?? "-"}',
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Owner: ${auth.email ?? "-"}',
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Subscription Status Badge & Latency
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: auth.isSubscriptionActive
                                ? Colors.green.withOpacity(0.1)
                                : (auth.isTrialActive ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            auth.subscriptionBadgeText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: auth.isSubscriptionActive
                                  ? Colors.green.shade700
                                  : (auth.isTrialActive ? Colors.blue.shade700 : Colors.red.shade700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Latency meter with refresh
                      InkWell(
                        onTap: () => health.checkHealth(),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: health.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: health.statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                health.latencyMs != null ? '${health.latencyMs}ms' : 'Ping',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: health.statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Actions: Upgrade & Logout (Responsive Wrap to prevent tight overflow)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => SaaSPaymentSheet.show(context),
                        icon: const Icon(Icons.rocket_launch_rounded, size: 14),
                        label: const Text(
                          'Perpanjang / Upgrade Paket',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await auth.logout();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.logout_rounded, size: 13),
                        label: const Text('Keluar', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Divider(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                  const SizedBox(height: 8),

                  // Section: Cross-Mode Data Migration
                  Row(
                    children: [
                      Icon(Icons.sync_alt_rounded, size: 16, color: isDark ? Colors.indigo.shade300 : Colors.indigo.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Migrasi Data Antar-Mode (Offline ⇄ Cloud)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pindahkan data katalog & transaksi antara Mode Offline (Lifetime SQLite) dan Akun Cloud SaaS toko Anda.',
                    style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    icon: Icons.cloud_upload_rounded,
                    color: Colors.indigo.shade700,
                    title: 'Migrasikan Data Offline ➔ Cloud SaaS',
                    subtitle: 'Unggah seluruh katalog & riwayat transaksi SQLite offline ke Cloud',
                    onTap: () => _showMigrationPreFlightDialog(context, MigrationDirection.lifetimeToCloud),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.cloud_download_rounded,
                    color: Colors.teal.shade700,
                    title: 'Sinkronkan Data Cloud ➔ Offline Lokal',
                    subtitle: 'Unduh seluruh data Cloud ke penyimpanan SQLite lokal perangkat ini',
                    onTap: () => _showMigrationPreFlightDialog(context, MigrationDirection.cloudToLifetime),
                  ),
                ],
              ),
            ),
          ] else ...[
            // 2. Dual Tab: [ Masuk Akun ] vs [ Daftar Toko Baru ]
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _cloudAuthTab = 0;
                      _authFeedbackMessage = null;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _cloudAuthTab == 0
                            ? AppColors.primary
                            : (isDark ? AppColors.darkCard : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '🔑 Masuk Akun',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _cloudAuthTab == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _cloudAuthTab = 1;
                      _authFeedbackMessage = null;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _cloudAuthTab == 1
                            ? AppColors.primary
                            : (isDark ? AppColors.darkCard : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '📝 Daftar Toko Baru',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _cloudAuthTab == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_cloudAuthTab == 0) ...[
              // LOGIN TAB
              Text(
                'Masuk dengan akun terdaftar untuk sinkronisasi multi-kasir.',
                style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _authEmailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined, size: 16),
                  hintText: 'Email Toko / Akun Owner',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _authPasswordController,
                obscureText: true,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 16),
                  hintText: 'Password',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              _buildInlineAuthFeedback(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleLogin(
                    _authEmailController.text.trim(),
                    _authPasswordController.text.trim(),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 14),
                  label: const Text('Hubungkan Akun Toko', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              // REGISTER TAB (14-DAY TRIAL)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded, color: Colors.blue, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Gratis Free Trial 14 Hari penuh tanpa kartu kredit!',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _regStoreNameController,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.storefront_outlined, size: 16),
                  hintText: 'Nama Toko / Usaha (misal: Toko Berkah)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _regOwnerNameController,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline, size: 16),
                  hintText: 'Nama Pemilik / Kasir',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _regEmailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined, size: 16),
                  hintText: 'Email Toko (untuk login)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _regPhoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_outlined, size: 16),
                  hintText: 'No. WhatsApp Toko (08xxx)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _regPasswordController,
                obscureText: true,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 16),
                  hintText: 'Password Toko (min. 6 karakter)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              _buildInlineAuthFeedback(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _handleRegister,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 14),
                  label: const Text('Daftar & Aktifkan Free Trial 14 Hari', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],

          // 3. Collapsible Sandbox Accordion (Moved to bottom)
          const SizedBox(height: 14),
          InkWell(
            onTap: () => setState(() => _showSandboxTour = !_showSandboxTour),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, size: 14, color: Colors.purple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '🧪 Sandbox / Demo Tour (Evaluasi Tanpa Akun)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextMain : Colors.purple.shade900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showSandboxTour ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          if (_showSandboxTour) ...[
            const SizedBox(height: 8),
            Text(
              'Coba cepat multi-tenant demo toko siap pakai tanpa registrasi:',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleLogin('admin@larisai.com', 'admin123'),
                    icon: const Icon(Icons.store_rounded, size: 13, color: AppColors.primary),
                    label: const Text('Toko Demo 1 (Berkah)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleLogin('toko2@larisai.com', 'admin123'),
                    icon: const Icon(Icons.storefront_rounded, size: 13, color: Colors.orange),
                    label: const Text('Toko Demo 2 (Sejahtera)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    final name = _regOwnerNameController.text.trim();
    final storeName = _regStoreNameController.text.trim();
    final email = _regEmailController.text.trim();
    final phone = _regPhoneController.text.trim();
    final password = _regPasswordController.text.trim();

    if (name.isEmpty || storeName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      setState(() {
        _authFeedbackMessage = 'Harap lengkapi semua kolom data pendaftaran toko.';
        _isAuthFeedbackError = true;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _authFeedbackMessage = 'Password minimal harus 6 karakter.';
        _isAuthFeedbackError = true;
      });
      return;
    }

    setState(() {
      _authFeedbackMessage = '⏳ Mendaftarkan toko baru ke cloud...';
      _isAuthFeedbackError = false;
    });

    final effectiveUrl = _posController.text.trim().startsWith('http')
        ? _posController.text.trim()
        : ApiConstants.cloudPosBaseUrl;

    final success = await AuthService.instance.registerMerchant(
      name: name,
      storeName: storeName,
      email: email,
      password: password,
      phone: phone,
      baseUrl: effectiveUrl,
    );

    if (!mounted) return;

    if (success) {
      if (_selectedMode == ConnectionMode.offline) {
        _selectMode(ConnectionMode.cloud);
      }
      await ApiConstants.setMode(_selectedMode);
      final posProv = Provider.of<PosProvider>(context, listen: false);
      posProv.updateBaseUrls();
      await posProv.loadProducts();

      setState(() {
        _authFeedbackMessage = '🎉 Selamat datang, ${AuthService.instance.storeName}! Free Trial 14 Hari aktif.';
        _isAuthFeedbackError = false;
      });
    } else {
      setState(() {
        _authFeedbackMessage = '❌ ' + (AuthService.instance.lastError ?? 'Gagal mendaftar toko baru. Periksa koneksi internet.');
        _isAuthFeedbackError = true;
      });
    }
  }

  Future<void> _handleLogin(String email, String password) async {
    final posProv = Provider.of<PosProvider>(context, listen: false);

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _authFeedbackMessage = 'Harap masukkan email dan password toko.';
        _isAuthFeedbackError = true;
      });
      return;
    }

    setState(() {
      _authFeedbackMessage = '⏳ Menghubungkan ke akun toko...';
      _isAuthFeedbackError = false;
    });

    final effectiveUrl = _posController.text.trim().startsWith('http')
        ? _posController.text.trim()
        : ApiConstants.cloudPosBaseUrl;

    final success = await AuthService.instance.login(
      email: email,
      password: password,
      baseUrl: effectiveUrl,
    );
    if (!mounted) return;

    if (success) {
      if (_selectedMode == ConnectionMode.offline) {
        _selectMode(ConnectionMode.cloud);
      }
      await ApiConstants.setMode(_selectedMode);
      posProv.updateBaseUrls();
      await posProv.loadProducts();

      setState(() {
        _authFeedbackMessage = '✅ Berhasil terhubung ke ${AuthService.instance.storeName}!';
        _isAuthFeedbackError = false;
      });
    } else {
      setState(() {
        _authFeedbackMessage = '❌ ' + (AuthService.instance.lastError ?? 'Gagal login toko. Periksa email & password.');
        _isAuthFeedbackError = true;
      });
    }
  }

  Widget _buildExportTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SEKSI IMPOR & TEMPLATE PRODUK EXCEL ---
          Row(
            children: [
              const Icon(Icons.table_chart_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Impor & Input Produk Massal (Excel .xlsx)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Unggah ratusan data inventori sekaligus atau unduh format template resmi untuk toko Anda.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Action 1: Buka Dialog Impor Produk
          _buildActionButton(
            icon: Icons.upload_file_rounded,
            color: Colors.teal.shade700,
            title: 'Impor Produk Massal (Excel .xlsx)',
            subtitle: 'Upload file spreadsheet (.xlsx) dan tinjau pratinjau barang sebelum disimpan',
            onTap: () {
              BulkImportDialog.show(
                context,
                onImportSuccess: () {
                  final posProv = Provider.of<PosProvider>(context, listen: false);
                  posProv.loadProducts();
                },
              );
            },
          ),
          const SizedBox(height: 8),

          // Action 2: Langsung Unduh Template Excel
          _buildActionButton(
            icon: Icons.download_rounded,
            color: Colors.blue.shade700,
            title: 'Unduh Template Excel (.xlsx)',
            subtitle: 'Format tabel standar lengkap dengan 5 baris contoh produk FMCG siap edit',
            onTap: () async {
              try {
                final savedPath = await ExcelImportService.instance.downloadOrShareTemplate();
                if (!mounted) return;
                if (savedPath != null) {
                  showDialogNotification(
                    Platform.isWindows
                        ? 'Template berhasil disimpan di: $savedPath'
                        : 'Template Excel siap diedit atau dibagikan.',
                    color: Colors.blue.shade700,
                    icon: Icons.check_circle_rounded,
                  );
                }
              } catch (e) {
                if (!mounted) return;
                showDialogNotification(
                  'Gagal menyiapkan template: $e',
                  color: Colors.red,
                  icon: Icons.error_outline_rounded,
                );
              }
            },
          ),
          const SizedBox(height: 14),
          Divider(color: isDark ? AppColors.darkBorder : null),
          const SizedBox(height: 8),

          // --- SEKSI EKSPOR LAPORAN ---
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
                  showDialogNotification(
                    'Laporan Excel (.xlsx) tersimpan di:\n${result.filePath}',
                    color: Colors.green.shade800,
                    icon: Icons.check_circle_rounded,
                  );
                } else if (mounted && !result.isCancelled && result.message != null) {
                  showDialogNotification(
                    result.message!,
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialogNotification(
                    'Gagal ekspor Excel: $e',
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
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
                  showDialogNotification(
                    'Katalog Excel (.xlsx) tersimpan di:\n${result.filePath}',
                    color: Colors.teal.shade800,
                    icon: Icons.check_circle_rounded,
                  );
                } else if (mounted && !result.isCancelled && result.message != null) {
                  showDialogNotification(
                    result.message!,
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialogNotification(
                    'Gagal ekspor Excel: $e',
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
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
                  showDialogNotification(
                    'Laporan CSV berhasil disimpan di:\n${result.filePath}',
                    color: Colors.blueGrey.shade700,
                    icon: Icons.check_circle_rounded,
                  );
                } else if (mounted && !result.isCancelled && result.message != null) {
                  showDialogNotification(
                    result.message!,
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialogNotification(
                    'Gagal ekspor CSV: $e',
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
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

          // Button 3: Full Backup ZIP (Data + Images)
          _buildActionButton(
            icon: Icons.folder_zip_rounded,
            color: Colors.purple.shade700,
            title: 'Cadangkan Penuh (.zip: Data + Foto)',
            subtitle: 'Bundel database transaksi, inventori, dan seluruh foto produk dalam satu arsip .zip',
            onTap: () async {
              try {
                final result = await ExportService.instance.exportFullBackupZip();
                if (mounted && result.success && result.filePath != null) {
                  showDialogNotification(
                    'Cadangan penuh berhasil disimpan di:\n${result.filePath}',
                    color: Colors.purple.shade700,
                    icon: Icons.check_circle_rounded,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Cadangan penuh tersimpan!\n${result.filePath}'),
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
                  showDialogNotification(
                    result.message!,
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialogNotification(
                    'Gagal backup ZIP: $e',
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // Button 3B: Full Backup JSON Only
          _buildActionButton(
            icon: Icons.cloud_download_rounded,
            color: Colors.indigo.shade600,
            title: 'Cadangkan Data Teks Saja (.json)',
            subtitle: 'Hanya mencadangkan teks tabel transaksi, stok, dan pelanggan tanpa menyertakan foto',
            onTap: () async {
              try {
                final result = await ExportService.instance.exportFullBackupJson();
                if (mounted && result.success && result.filePath != null) {
                  showDialogNotification(
                    'Cadangan database JSON tersimpan di:\n${result.filePath}',
                    color: Colors.indigo.shade600,
                    icon: Icons.check_circle_rounded,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Cadangan database JSON tersimpan!\n${result.filePath}'),
                      backgroundColor: Colors.indigo.shade600,
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
                  showDialogNotification(
                    result.message!,
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialogNotification(
                    'Gagal backup JSON: $e',
                    color: Colors.red,
                    icon: Icons.error_outline_rounded,
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),

          // Button 4: Restore Backup (.zip / .json)
          _buildActionButton(
            icon: Icons.settings_backup_restore_rounded,
            color: Colors.teal.shade700,
            title: 'Pulihkan Database (.zip / .json)',
            subtitle: 'Mendukung pemulihan arsip paket .zip (data + foto) atau file .json cadangan lama',
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
                    'Pemulihan database akan mengganti seluruh katalog produk, foto, dan riwayat transaksi saat ini dengan data dari file cadangan yang Anda pilih (.zip / .json).\n\nApakah Anda yakin ingin melanjutkan?',
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
                  final imgCount = counts['images'] ?? 0;
                  final fileName = res['name']?.toString() ?? 'file';

                  final imgInfo = imgCount > 0 ? ', $imgCount foto' : '';
                  final successMsg = 'Berhasil memulihkan database dari $fileName! ($prodCount produk, $txCount transaksi$imgInfo)';
                  showDialogNotification(
                    successMsg,
                    color: Colors.teal.shade700,
                    icon: Icons.check_circle_rounded,
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✅ $successMsg'),
                      backgroundColor: Colors.teal.shade700,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else if (mounted) {
                  showDialogNotification(
                    'Pemulihan dibatalkan (tidak ada file dipilih).',
                    color: Colors.blueGrey,
                    icon: Icons.info_outline_rounded,
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialogNotification(
                    'Gagal memulihkan database: $e',
                    color: Colors.red.shade700,
                    icon: Icons.error_outline_rounded,
                  );
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

          const SizedBox(height: 8),
          // --- Cross-Mode Data Migration Section ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.teal.shade900.withValues(alpha: 0.18) : Colors.teal.shade50.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.teal.shade800 : Colors.teal.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: isDark ? Colors.teal.shade300 : Colors.teal.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Migrasi Data 2 Arah (Lifetime ⇄ Cloud SaaS)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.teal.shade200 : Colors.teal.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Sinkronkan data offline SQLite dengan akun Cloud SaaS secara aman dan non-destructive.',
                  style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                _buildActionButton(
                  icon: Icons.cloud_upload_rounded,
                  color: Colors.indigo.shade700,
                  title: 'Migrasikan Data Offline ➔ Cloud SaaS',
                  subtitle: 'Unggah seluruh katalog & riwayat transaksi SQLite offline ke Cloud',
                  onTap: () => _showMigrationPreFlightDialog(context, MigrationDirection.lifetimeToCloud),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  icon: Icons.cloud_download_rounded,
                  color: Colors.teal.shade700,
                  title: 'Sinkronkan Data Cloud ➔ Offline Lokal',
                  subtitle: 'Unduh seluruh data Cloud ke penyimpanan SQLite lokal perangkat ini',
                  onTap: () => _showMigrationPreFlightDialog(context, MigrationDirection.cloudToLifetime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const SizedBox(height: 8),
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
                  showDialogNotification(
                    'Silakan masukkan Serial Key lisensi.',
                    color: Colors.orange.shade800,
                    icon: Icons.warning_amber_rounded,
                  );
                  return;
                }

                try {
                  await LicenseService.instance.activateLicense(key);
                  await _loadLicense();
                  _licenseController.clear();
                  if (mounted) {
                    showDialogNotification(
                      '🎉 Lisensi berhasil diaktifkan secara permanen!',
                      color: Colors.green.shade700,
                      icon: Icons.check_circle_rounded,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    showDialogNotification(
                      'Gagal aktivasi: $e',
                      color: Colors.red.shade700,
                      icon: Icons.error_outline_rounded,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

  Future<void> _showMigrationPreFlightDialog(BuildContext context, MigrationDirection direction) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool clearExistingOffline = false;
    bool isInspecting = true;
    MigrationInspectionResult? inspection;

    await showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (isInspecting && inspection == null) {
              DataMigrationService.instance.inspectDataSources().then((res) {
                if (ctx.mounted) {
                  setModalState(() {
                    inspection = res;
                    isInspecting = false;
                  });
                }
              });
            }

            final isUpload = direction == MigrationDirection.lifetimeToCloud;
            final title = isUpload
                ? 'Migrasi Data: Offline ➔ Cloud SaaS'
                : 'Sinkronisasi Data: Cloud SaaS ➔ Offline';
            final themeColor = isUpload ? Colors.indigo.shade700 : Colors.teal.shade700;

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isUpload ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded,
                      color: themeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: isInspecting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Memeriksa data lokal & akun cloud...', style: TextStyle(fontSize: 11.5)),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (inspection?.isCloudAuthenticated != true) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade700, width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Akun Cloud belum terhubung. Silakan login ke akun toko di Tab "Mode Server" terlebih dahulu.',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Target Akun Cloud:', style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                                      Text(
                                        'Store ID: ${inspection?.storeId.isNotEmpty == true ? inspection!.storeId : "-"}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Data Offline SQLite:', style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                                      Text(
                                        '${inspection?.localProductsCount ?? 0} Produk | ${inspection?.localTransactionsCount ?? 0} Trx',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Data Cloud SaaS:', style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                                      Text(
                                        '${inspection?.cloudProductsCount ?? 0} Produk | ${inspection?.cloudTransactionsCount ?? 0} Trx',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            isUpload
                                ? '• Seluruh katalog produk dan transaksi offline akan diunggah ke database Cloud toko Anda.\n• Database offline lokal tetap utuh dan tersimpan aman (non-destructive backup).\n• Produk dengan barcode/nama yang sama akan otomatis direkonsiliasi.'
                                : '• Data katalog produk dan riwayat transaksi dari akun Cloud akan diunduh dan disimpan ke database SQLite offline HP ini.',
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.4,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                          if (!isUpload && inspection?.isCloudAuthenticated == true) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: clearExistingOffline
                                    ? Colors.red.withValues(alpha: isDark ? 0.2 : 0.08)
                                    : (isDark ? AppColors.darkSurface : Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: clearExistingOffline ? Colors.redAccent : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                                ),
                              ),
                              child: CheckboxListTile(
                                value: clearExistingOffline,
                                dense: true,
                                activeColor: Colors.red.shade700,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(
                                  'Timpa Bersih Data Offline (Clean Slate)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: clearExistingOffline ? Colors.red.shade700 : (isDark ? AppColors.darkTextMain : AppColors.textMain),
                                  ),
                                ),
                                subtitle: Text(
                                  'Hapus seluruh produk & transaksi offline lama sebelum menyimpan data Cloud (Default: uncheck untuk gabung/upsert)',
                                  style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                ),
                                onChanged: (val) {
                                  setModalState(() {
                                    clearExistingOffline = val ?? false;
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                ),
                if (!isInspecting && inspection?.isCloudAuthenticated == true)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(isUpload ? Icons.upload_rounded : Icons.download_rounded, size: 16),
                    label: Text(isUpload ? 'Mulai Unggah ke Cloud' : 'Mulai Unduh ke Offline'),
                    onPressed: () {
                      Navigator.pop(dlgCtx);
                      _executeMigrationWithProgress(
                        context,
                        direction,
                        clearExistingOffline: clearExistingOffline,
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeMigrationWithProgress(
    BuildContext context,
    MigrationDirection direction, {
    bool clearExistingOffline = false,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUpload = direction == MigrationDirection.lifetimeToCloud;

    // Show Non-dismissible Progress Modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isUpload ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded,
                  color: isUpload ? Colors.indigo.shade700 : Colors.teal.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isUpload ? 'Mengunggah Data ke Cloud...' : 'Menyinkronkan Data Cloud...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
            content: ValueListenableBuilder<MigrationProgress>(
              valueListenable: DataMigrationService.instance.progress,
              builder: (ctx, prog, _) {
                final pctVal = prog.percentage.clamp(0.0, 1.0);
                final pctText = (pctVal * 100).toInt();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: pctVal,
                      backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isUpload ? Colors.indigo.shade700 : Colors.teal.shade700,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            prog.currentPhase,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$pctText%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isUpload ? Colors.indigo.shade700 : Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (prog.totalItems > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Item terproses: ${prog.processedItems} dari ${prog.totalItems}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    // Run migration
    MigrationSummaryResult result;
    if (direction == MigrationDirection.lifetimeToCloud) {
      result = await DataMigrationService.instance.migrateLifetimeToCloud();
    } else {
      result = await DataMigrationService.instance.migrateCloudToLifetime(
        clearExistingOffline: clearExistingOffline,
      );
    }

    // Dismiss progress dialog & refresh
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    try {
      final posProv = Provider.of<PosProvider>(context, listen: false);
      posProv.loadProducts();
      posProv.loadSummary();
      final aiProv = Provider.of<AiProvider>(context, listen: false);
      aiProv.loadAiData();
    } catch (_) {}

    showDialogNotification(
      result.message,
      color: result.success ? (isUpload ? Colors.indigo.shade700 : Colors.teal.shade700) : Colors.red.shade700,
      icon: result.success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _confirmResetTransactions(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

        showDialogNotification(
          backupPath != null
              ? '✅ Riwayat transaksi dibersihkan! Omset kembali Rp 0.\nCadangan aman: ${backupPath.split(Platform.isWindows ? '\\' : '/').last}'
              : '✅ Riwayat transaksi berhasil dibersihkan! Omset kembali ke Rp 0.',
          color: Colors.green.shade700,
          icon: Icons.check_circle_rounded,
        );
      } catch (e) {
        showDialogNotification(
          'Gagal reset transaksi: $e',
          color: Colors.red.shade700,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _confirmFactoryReset(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

        final msg = backupPath != null
            ? '✅ Database di-reset total! Salinan cadangan otomatis disimpan ke: $backupPath'
            : '✅ Database berhasil di-reset total! Produk & transaksi telah dikosongkan.';

        showDialogNotification(
          msg,
          color: Colors.red.shade700,
          icon: Icons.check_circle_rounded,
        );
      } catch (e) {
        showDialogNotification(
          'Gagal reset pabrik: $e',
          color: Colors.red.shade700,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final dialogWidth = (mediaQuery.size.width * (isMobile ? 0.96 : 0.88)).clamp(340.0, 620.0);
    final dialogHeight = (mediaQuery.size.height * (isMobile ? 0.82 : 0.72)).clamp(440.0, 680.0);

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Profil UMKM, mode server & backup data',
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
              Consumer<ThemeProvider>(
                builder: (context, themeProv, _) => IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: themeProv.isDarkMode ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
                  icon: Icon(
                    themeProv.isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    size: 20,
                    color: themeProv.isDarkMode ? Colors.amber : AppColors.primary,
                  ),
                  onPressed: () => themeProv.toggleTheme(),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close_rounded, size: 20, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(3),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded, size: 15),
                      SizedBox(width: 6),
                      Text('Profil UMKM'),
                    ],
                  ),
                ),
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.palette_rounded, size: 15),
                      SizedBox(width: 6),
                      Text('Tema / Tampilan'),
                    ],
                  ),
                ),
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dns_rounded, size: 15),
                      SizedBox(width: 6),
                      Text('Mode Server'),
                    ],
                  ),
                ),
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_sync_rounded, size: 15),
                      SizedBox(width: 6),
                      Text('Data & Backup'),
                    ],
                  ),
                ),
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 15),
                      SizedBox(width: 6),
                      Text('Lisensi'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_dialogNotificationMessage != null) ...[
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _dialogNotificationColor.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dialogNotificationColor.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(_dialogNotificationIcon, color: _dialogNotificationColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dialogNotificationMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _dialogNotificationTimer?.cancel();
                      setState(() => _dialogNotificationMessage = null);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildStoreProfileTab(),
            _buildThemeTab(),
            _buildNetworkTab(),
            _buildExportTab(),
            _buildLicenseTab(),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Tutup',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text(
                  'Simpan Pengaturan',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
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
                  if (_selectedMode != ConnectionMode.offline && _posController.text.trim().isNotEmpty) {
                    await ApiConstants.setUrls(
                      posUrl: _posController.text.trim(),
                      aiUrl: _aiController.text.trim().isNotEmpty
                          ? _aiController.text.trim()
                          : _posController.text.trim(),
                    );
                  }

                  if (!context.mounted) return;

                  // Refresh data in providers
                  final posProv = Provider.of<PosProvider>(context, listen: false);
                  posProv.updateBaseUrls();
                  posProv.loadProducts();
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
            ),
          ],
        ),
      ],
    );
  }
}
