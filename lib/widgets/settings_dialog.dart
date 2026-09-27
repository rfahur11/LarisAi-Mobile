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

  @override
  void initState() {
    super.initState();
    _posController = TextEditingController(text: ApiConstants.posBaseUrl);
    _aiController = TextEditingController(text: ApiConstants.aiBaseUrl);
  }

  @override
  void dispose() {
    _posController.dispose();
    _aiController.dispose();
    super.dispose();
  }

  void _usePreset(String pos, String ai) {
    setState(() {
      _posController.text = pos;
      _aiController.text = ai;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.settings, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Pengaturan Server Backend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih mode koneksi HP ke backend:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _usePreset(ApiConstants.defaultPosBaseUrl, ApiConstants.defaultAiBaseUrl),
                    child: const Text('Kabel USB (adb)', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _usePreset(ApiConstants.lanPosBaseUrl, ApiConstants.lanAiBaseUrl),
                    child: const Text('Wi-Fi LAN', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('POS Backend URL (Go):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _posController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('AI Engine URL (FastAPI):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _aiController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            await ApiConstants.setUrls(
              posUrl: _posController.text.trim(),
              aiUrl: _aiController.text.trim(),
            );
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Konfigurasi URL Server berhasil disimpan!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
