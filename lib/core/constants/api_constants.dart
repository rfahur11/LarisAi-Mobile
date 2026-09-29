import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionMode { usb, wifi, cloud }

class ApiConstants {
  static const String keyPosBaseUrl = 'pos_base_url';
  static const String keyAiBaseUrl = 'ai_base_url';
  static const String keyConnectionMode = 'connection_mode';

  // Mode 1: USB (adb reverse) — HP terhubung via kabel USB ke laptop
  static const String usbPosBaseUrl = 'http://localhost:8080';
  static const String usbAiBaseUrl = 'http://localhost:8001';

  // Mode 2: Wi-Fi LAN — HP & laptop di jaringan yang sama
  static const String lanPosBaseUrl = 'http://192.168.1.3:8080';
  static const String lanAiBaseUrl = 'http://192.168.1.3:8001';

  // Mode 3: Cloud (Hugging Face Spaces) — Tanpa laptop/backend lokal
  static const String cloudBaseUrl = 'https://rfahrur6045-sentimentanalysist.hf.space';
  static const String cloudPosBaseUrl = cloudBaseUrl; // Nginx proxy routes /api/v1/* → POS
  static const String cloudAiBaseUrl = cloudBaseUrl;  // Nginx proxy routes /api/v1/ai/* → AI

  static String posBaseUrl = usbPosBaseUrl;
  static String aiBaseUrl = usbAiBaseUrl;
  static ConnectionMode currentMode = ConnectionMode.usb;

  static Future<void> loadSavedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(keyConnectionMode) ?? 'usb';
    currentMode = ConnectionMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => ConnectionMode.usb,
    );
    _applyMode(currentMode);

    // Override with custom URLs if manually set
    posBaseUrl = prefs.getString(keyPosBaseUrl) ?? posBaseUrl;
    aiBaseUrl = prefs.getString(keyAiBaseUrl) ?? aiBaseUrl;
  }

  static void _applyMode(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.usb:
        posBaseUrl = usbPosBaseUrl;
        aiBaseUrl = usbAiBaseUrl;
        break;
      case ConnectionMode.wifi:
        posBaseUrl = lanPosBaseUrl;
        aiBaseUrl = lanAiBaseUrl;
        break;
      case ConnectionMode.cloud:
        posBaseUrl = cloudBaseUrl;
        aiBaseUrl = cloudBaseUrl;
        break;
    }
  }

  static Future<void> setMode(ConnectionMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    currentMode = mode;
    _applyMode(mode);
    await prefs.setString(keyConnectionMode, mode.name);
    await prefs.setString(keyPosBaseUrl, posBaseUrl);
    await prefs.setString(keyAiBaseUrl, aiBaseUrl);
  }

  static Future<void> setUrls({required String posUrl, required String aiUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    posBaseUrl = posUrl;
    aiBaseUrl = aiUrl;
    await prefs.setString(keyPosBaseUrl, posUrl);
    await prefs.setString(keyAiBaseUrl, aiUrl);
  }

  static String get modeLabel {
    switch (currentMode) {
      case ConnectionMode.usb:
        return '🔌 USB (adb reverse)';
      case ConnectionMode.wifi:
        return '📶 Wi-Fi LAN';
      case ConnectionMode.cloud:
        return '☁️ Cloud (HF Space)';
    }
  }
}

