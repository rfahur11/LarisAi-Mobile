import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LicenseType { trial, lifetime, subscription }

class LicenseInfo {
  final LicenseType type;
  final String licenseKey;
  final String machineId;
  final DateTime activatedAt;
  final DateTime? expiresAt;
  final bool isValid;

  LicenseInfo({
    required this.type,
    required this.licenseKey,
    required this.machineId,
    required this.activatedAt,
    this.expiresAt,
    required this.isValid,
  });

  String get typeDisplay {
    switch (type) {
      case LicenseType.lifetime:
        return 'Lifetime (Beli Sekali - Permanen)';
      case LicenseType.subscription:
        return 'SaaS Subscription (Bulanan/Tahunan)';
      case LicenseType.trial:
        return 'Trial Gratis (14 Hari)';
    }
  }

  int get daysRemaining {
    if (type == LicenseType.lifetime) return 9999;
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }
}

class LicenseService {
  static final LicenseService instance = LicenseService._init();
  LicenseService._init();

  static const String _prefMachineId = 'larisai_machine_id';
  static const String _prefLicenseKey = 'larisai_license_key';
  static const String _prefLicenseType = 'larisai_license_type';
  static const String _prefActivatedAt = 'larisai_activated_at';
  static const String _prefExpiresAt = 'larisai_expires_at';
  static const String _prefSignature = 'larisai_license_signature';

  static const String _secretSalt = 'LARISAI_VIBE_SECURE_SALT_2026';

  /// Sanitize Machine ID to 8-character hardware token
  static String sanitizeMachineId(String machineId) {
    final clean = machineId.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    if (clean.length >= 8) {
      return clean.substring(0, 8);
    }
    return clean.padRight(8, '0');
  }

  /// Cryptographic Checksum generator matching Weboz license generator
  static String generateLicenseChecksum(String cleanMid, String planType) {
    final payload = '$cleanMid:$planType:$_secretSalt';
    final keyBytes = utf8.encode(_secretSalt);
    final payloadBytes = utf8.encode(payload);
    final hmac = crypto.Hmac(crypto.sha256, keyBytes);
    final digest = hmac.convert(payloadBytes);
    return digest.toString().toUpperCase().substring(0, 8);
  }

  /// Get or Generate Unique Persistent Machine Identifier
  Future<String> getMachineId() async {
    final prefs = await SharedPreferences.getInstance();
    String? machineId = prefs.getString(_prefMachineId);

    if (machineId == null || machineId.isEmpty) {
      final hostName = Platform.localHostname;
      final os = Platform.operatingSystem;
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Hash combined info
      final raw = '$os-$hostName-$ts-$_secretSalt';
      final bytes = utf8.encode(raw);
      final hash = crypto.sha256.convert(bytes).toString().toUpperCase().substring(0, 16);
      
      // Format: LRS-XXXX-XXXX-XXXX
      machineId = 'LRS-${hash.substring(0, 4)}-${hash.substring(4, 8)}-${hash.substring(8, 12)}';
      await prefs.setString(_prefMachineId, machineId);
    }

    return machineId;
  }

  /// Get Current Active License Information
  Future<LicenseInfo> getLicenseInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final machineId = await getMachineId();

    final key = prefs.getString(_prefLicenseKey);
    final typeStr = prefs.getString(_prefLicenseType);
    final activatedStr = prefs.getString(_prefActivatedAt);
    final expiresStr = prefs.getString(_prefExpiresAt);
    final storedSig = prefs.getString(_prefSignature);

    if (key == null || typeStr == null || activatedStr == null) {
      // Default: 14-day Free Trial
      final trialStart = DateTime.now().subtract(const Duration(days: 1));
      final trialEnd = trialStart.add(const Duration(days: 14));
      return LicenseInfo(
        type: LicenseType.trial,
        licenseKey: 'TRIAL-14DAYS-FREE',
        machineId: machineId,
        activatedAt: trialStart,
        expiresAt: trialEnd,
        isValid: true,
      );
    }

    // Verify cryptographic signature and hardware-bound checksum
    final expectedSig = _generateSignature(machineId, key, typeStr, activatedStr);
    final currentCleanMid = sanitizeMachineId(machineId);

    final match = RegExp(r'^LRS-(LIFE|SUBS)-([A-Z0-9]{8})-([A-Z0-9]{8})$').firstMatch(key);
    bool isKeyChecksumValid = false;
    if (match != null) {
      final planPrefix = match.group(1)!;
      final keyMid = match.group(2)!;
      final keyChecksum = match.group(3)!;
      final planType = (planPrefix == 'LIFE') ? 'lifetime' : 'subscription';
      if (keyMid == currentCleanMid && keyChecksum == generateLicenseChecksum(currentCleanMid, planType)) {
        isKeyChecksumValid = true;
      }
    }

    final isTamperFree = (storedSig == expectedSig) && isKeyChecksumValid;

    LicenseType type = LicenseType.trial;
    if (typeStr == 'lifetime') type = LicenseType.lifetime;
    if (typeStr == 'subscription') type = LicenseType.subscription;

    DateTime activatedAt = DateTime.tryParse(activatedStr) ?? DateTime.now();
    DateTime? expiresAt = expiresStr != null ? DateTime.tryParse(expiresStr) : null;

    bool isValid = isTamperFree;
    if (type == LicenseType.subscription && expiresAt != null) {
      if (DateTime.now().isAfter(expiresAt)) {
        isValid = false;
      }
    }

    return LicenseInfo(
      type: type,
      licenseKey: key,
      machineId: machineId,
      activatedAt: activatedAt,
      expiresAt: expiresAt,
      isValid: isValid,
    );
  }

  /// Activate a new license key (Offline or SaaS) with Strict Hardware Binding
  Future<bool> activateLicense(String inputKey) async {
    final cleanKey = inputKey.trim().toUpperCase().replaceAll(' ', '');
    final machineId = await getMachineId();
    final currentCleanMid = sanitizeMachineId(machineId);
    final prefs = await SharedPreferences.getInstance();

    final match = RegExp(r'^LRS-(LIFE|SUBS)-([A-Z0-9]{8})-([A-Z0-9]{8})$').firstMatch(cleanKey);
    if (match == null) {
      throw Exception('Format Serial Key tidak valid. Format resmi: LRS-LIFE-XXXXXXXX-YYYYYYYY');
    }

    final planPrefix = match.group(1)!; // LIFE or SUBS
    final keyMid = match.group(2)!;
    final keyChecksum = match.group(3)!;

    if (keyMid != currentCleanMid) {
      throw Exception('Serial Key ini terikat untuk perangkat lain ($keyMid). Machine ID perangkat ini: $currentCleanMid.');
    }

    final planType = (planPrefix == 'LIFE') ? 'lifetime' : 'subscription';
    final expectedChecksum = generateLicenseChecksum(currentCleanMid, planType);
    if (keyChecksum != expectedChecksum) {
      throw Exception('Serial Key tidak valid (Checksum mismatch). Harap dapatkan serial key resmi dari Weboz.');
    }

    final type = (planType == 'lifetime') ? LicenseType.lifetime : LicenseType.subscription;
    final now = DateTime.now();
    final DateTime? expiresAt = (type == LicenseType.subscription)
        ? now.add(const Duration(days: 365))
        : null;

    final activatedStr = now.toIso8601String();
    final signature = _generateSignature(machineId, cleanKey, planType, activatedStr);

    await prefs.setString(_prefLicenseKey, cleanKey);
    await prefs.setString(_prefLicenseType, planType);
    await prefs.setString(_prefActivatedAt, activatedStr);
    if (expiresAt != null) {
      await prefs.setString(_prefExpiresAt, expiresAt.toIso8601String());
    } else {
      await prefs.remove(_prefExpiresAt);
    }
    await prefs.setString(_prefSignature, signature);

    return true;
  }

  /// 1-Tap Online Activation: Query Weboz API to verify and activate license automatically
  Future<Map<String, dynamic>> verifyOnlineFromWeboz() async {
    final machineId = await getMachineId();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));

      final url = 'https://weboz.my.id/api/licenses/verify?machine_id=$machineId';
      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['found'] == true && data['license'] != null) {
          final serialKey = data['license']['serial_key']?.toString();
          if (serialKey != null && serialKey.isNotEmpty) {
            await activateLicense(serialKey);
            return {
              'success': true,
              'message': '🎉 Lisensi resmi berhasil diverifikasi & diaktifkan otomatis dari Weboz!',
              'license': data['license'],
            };
          }
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Lisensi belum diaktifkan oleh Admin Weboz untuk Machine ID: $machineId',
        };
      }
      return {
        'success': false,
        'message': 'Respon server tidak valid (${response.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke Weboz. Pastikan perangkat terhubung ke internet: $e',
      };
    }
  }

  String _generateSignature(String machineId, String key, String type, String date) {
    final raw = '$machineId:$key:$type:$date:$_secretSalt';
    final bytes = utf8.encode(raw);
    return crypto.sha256.convert(bytes).toString();
  }
}
