import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionMode { offline, cloud, usb, wifi }

class ApiConstants {
  static const String keyPosBaseUrl = 'pos_base_url';
  static const String keyAiBaseUrl = 'ai_base_url';
  static const String keyConnectionMode = 'connection_mode';

  // Mode 1: Offline Lifetime (Local SQLite on Device)
  static const String offlineLabel = '📦 Lifetime (Offline SQLite)';

  // Mode 2: Cloud SaaS (Hugging Face Spaces + MongoDB Atlas)
  static const String cloudBaseUrl = 'https://rfahrur6045-sentimentanalysist.hf.space';
  static const String cloudPosBaseUrl = cloudBaseUrl;
  static const String cloudAiBaseUrl = cloudBaseUrl;

  // Mode 3: USB (adb reverse)
  static const String usbPosBaseUrl = 'http://localhost:8080';
  static const String usbAiBaseUrl = 'http://localhost:8001';

  // Mode 4: Wi-Fi LAN
  static const String lanPosBaseUrl = 'http://192.168.1.3:8080';
  static const String lanAiBaseUrl = 'http://192.168.1.3:8001';

  static String posBaseUrl = usbPosBaseUrl;
  static String aiBaseUrl = usbAiBaseUrl;
  static ConnectionMode currentMode = ConnectionMode.offline;

  static bool get isOfflineMode => currentMode == ConnectionMode.offline;

  static Future<void> loadSavedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(keyConnectionMode) ?? 'offline';
    currentMode = ConnectionMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => ConnectionMode.offline,
    );
    _applyMode(currentMode);

    // Override with custom URLs if manually set
    posBaseUrl = prefs.getString(keyPosBaseUrl) ?? posBaseUrl;
    aiBaseUrl = prefs.getString(keyAiBaseUrl) ?? aiBaseUrl;
  }

  static void _applyMode(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.offline:
        posBaseUrl = 'local://sqlite';
        aiBaseUrl = 'local://sqlite';
        break;
      case ConnectionMode.cloud:
        posBaseUrl = cloudBaseUrl;
        aiBaseUrl = cloudBaseUrl;
        break;
      case ConnectionMode.usb:
        posBaseUrl = usbPosBaseUrl;
        aiBaseUrl = usbAiBaseUrl;
        break;
      case ConnectionMode.wifi:
        posBaseUrl = lanPosBaseUrl;
        aiBaseUrl = lanAiBaseUrl;
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
      case ConnectionMode.offline:
        return '📦 Lifetime (SQLite Lokal)';
      case ConnectionMode.cloud:
        return '☁️ Cloud (SaaS HF Space)';
      case ConnectionMode.usb:
        return '🔌 USB (adb reverse)';
      case ConnectionMode.wifi:
        return '📶 Wi-Fi LAN';
    }
  }
}
