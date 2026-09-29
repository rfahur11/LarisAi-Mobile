import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';

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
        case ConnectionMode.usb:
          _posController.text = ApiConstants.usbPosBaseUrl;
          _aiController.text = ApiConstants.usbAiBaseUrl;
          break;
        case ConnectionMode.wifi:
          _posController.text = ApiConstants.lanPosBaseUrl;
          _aiController.text = ApiConstants.lanAiBaseUrl;
          break;
        case ConnectionMode.cloud:
          _posController.text = ApiConstants.cloudPosBaseUrl;
          _aiController.text = ApiConstants.cloudAiBaseUrl;
          break;
      }
    });
  }

  Widget _buildModeCard({
    required ConnectionMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withOpacity(0.15) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? accentColor : Colors.grey.shade500, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accentColor : AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
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
            child: const Icon(Icons.dns_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Koneksi Backend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Pilih mode koneksi HP ke server', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode cards
            _buildModeCard(
              mode: ConnectionMode.usb,
              icon: Icons.usb_rounded,
              title: '🔌 Kabel USB',
              subtitle: 'Pakai adb reverse — HP terhubung kabel ke laptop',
              accentColor: Colors.blue.shade600,
            ),
            const SizedBox(height: 8),
            _buildModeCard(
              mode: ConnectionMode.wifi,
              icon: Icons.wifi,
              title: '📶 Wi-Fi LAN',
              subtitle: 'HP & laptop di jaringan Wi-Fi yang sama',
              accentColor: Colors.orange.shade700,
            ),
            const SizedBox(height: 8),
            _buildModeCard(
              mode: ConnectionMode.cloud,
              icon: Icons.cloud_outlined,
              title: '☁️ Cloud (HF Space)',
              subtitle: 'Tanpa laptop — koneksi langsung ke Hugging Face',
              accentColor: Colors.green.shade700,
            ),

            const SizedBox(height: 16),

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
                  Text(
                    'URL Kustom (Advanced)',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 12),
              const Text('POS Backend URL (Go):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
              const Text('AI Engine URL (FastAPI):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          icon: const Icon(Icons.save_alt_rounded, size: 16),
          label: const Text('Simpan'),
          onPressed: () async {
            // Set mode first, then apply custom URLs if advanced was used
            await ApiConstants.setMode(_selectedMode);
            if (_showAdvanced) {
              await ApiConstants.setUrls(
                posUrl: _posController.text.trim(),
                aiUrl: _aiController.text.trim(),
              );
            }
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Mode ${ApiConstants.modeLabel} aktif!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
