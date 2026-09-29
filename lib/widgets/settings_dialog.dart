import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../providers/pos_provider.dart';
import '../providers/ai_provider.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _posController;
  late TextEditingController _aiController;
  late ConnectionMode _selectedMode;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = ApiConstants.currentMode;
    _posController = TextEditingController(text: ApiConstants.posBaseUrl);
    _aiController = TextEditingController(text: ApiConstants.aiBaseUrl);
  }

  @override
  void dispose() {
    _posController.dispose();
    _aiController.dispose();
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
              width: 42,
              height: 42,
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
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: accentColor, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode Operasional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Pilih arsitektur database & sinkronisasi', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode 1: Lifetime Offline SQLite
            _buildModeCard(
              mode: ConnectionMode.offline,
              icon: Icons.offline_bolt_rounded,
              title: '📦 Lifetime Mode',
              subtitle: '100% Offline — Database tersimpan di SQLite HP tanpa server',
              badgeText: 'LIFETIME',
              badgeColor: Colors.teal.shade700,
              accentColor: Colors.teal.shade700,
            ),
            const SizedBox(height: 8),

            // Mode 2: Subscription Cloud SaaS
            _buildModeCard(
              mode: ConnectionMode.cloud,
              icon: Icons.cloud_done_rounded,
              title: '☁️ Subscription SaaS',
              subtitle: 'Cloud Atlas — Sinkron multi-device & AI realtime',
              badgeText: 'SUBSCRIPTION',
              badgeColor: Colors.indigo.shade700,
              accentColor: Colors.indigo.shade700,
            ),
            const SizedBox(height: 8),

            // Mode 3: Local Dev (USB)
            _buildModeCard(
              mode: ConnectionMode.usb,
              icon: Icons.usb_rounded,
              title: '🔌 Dev: Kabel USB',
              subtitle: 'adb reverse — Terhubung ke backend laptop',
              badgeText: 'DEV',
              badgeColor: Colors.blue.shade700,
              accentColor: Colors.blue.shade700,
            ),
            const SizedBox(height: 8),

            // Mode 4: Local Dev (Wi-Fi)
            _buildModeCard(
              mode: ConnectionMode.wifi,
              icon: Icons.wifi_rounded,
              title: '📶 Dev: Wi-Fi LAN',
              subtitle: 'Jaringan Wi-Fi lokal kantor / toko',
              badgeText: 'LAN',
              badgeColor: Colors.orange.shade800,
              accentColor: Colors.orange.shade800,
            ),

            const SizedBox(height: 14),

            // Advanced toggle
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Row(
                children: [
                  Icon(
                    _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Kustomisasi Endpoint (Advanced)',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 10),
              const Text('POS Backend URL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _posController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              const Text('AI Engine URL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _aiController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Terapkan Mode'),
          onPressed: () async {
            await ApiConstants.setMode(_selectedMode);
            if (_showAdvanced) {
              await ApiConstants.setUrls(
                posUrl: _posController.text.trim(),
                aiUrl: _aiController.text.trim(),
              );
            }

            if (!context.mounted) return;

            // Refresh data in providers reactively
            Provider.of<PosProvider>(context, listen: false).loadProducts();
            Provider.of<AiProvider>(context, listen: false).loadAiData();

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Mode ${ApiConstants.modeLabel} berhasil diaktifkan!'),
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
