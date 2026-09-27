import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String keyPosBaseUrl = 'pos_base_url';
  static const String keyAiBaseUrl = 'ai_base_url';

  // Default values: localhost (works directly via USB cable with 'adb reverse')
  static const String defaultPosBaseUrl = 'http://localhost:8080';
  static const String defaultAiBaseUrl = 'http://localhost:8001';

  // Wi-Fi LAN fallbacks if testing wirelessly
  static const String lanPosBaseUrl = 'http://192.168.1.3:8080';
  static const String lanAiBaseUrl = 'http://192.168.1.3:8001';

  static String posBaseUrl = defaultPosBaseUrl;
  static String aiBaseUrl = defaultAiBaseUrl;

  static Future<void> loadSavedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    posBaseUrl = prefs.getString(keyPosBaseUrl) ?? defaultPosBaseUrl;
    aiBaseUrl = prefs.getString(keyAiBaseUrl) ?? defaultAiBaseUrl;
  }

  static Future<void> setUrls({required String posUrl, required String aiUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    posBaseUrl = posUrl;
    aiBaseUrl = aiUrl;
    await prefs.setString(keyPosBaseUrl, posUrl);
    await prefs.setString(keyAiBaseUrl, aiUrl);
  }
}
