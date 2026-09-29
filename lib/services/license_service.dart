import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
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

    // Verify cryptographic signature
    final expectedSig = _generateSignature(machineId, key, typeStr, activatedStr);
    final isTamperFree = (storedSig == expectedSig);

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

  /// Activate a new license key (Offline or SaaS)
  Future<bool> activateLicense(String inputKey) async {
    final cleanKey = inputKey.trim().toUpperCase();
    final machineId = await getMachineId();
    final prefs = await SharedPreferences.getInstance();

    LicenseType type;
    DateTime? expiresAt;
    final now = DateTime.now();

    if (cleanKey.startsWith('LRS-LIFE-') || cleanKey.contains('LIFETIME')) {
      type = LicenseType.lifetime;
      expiresAt = null; // Never expires
    } else if (cleanKey.startsWith('LRS-SUBS-') || cleanKey.contains('SUBS')) {
      type = LicenseType.subscription;
      expiresAt = now.add(const Duration(days: 365)); // 1 year subscription
    } else {
      // Simple format check (Must be at least 16 chars)
      if (cleanKey.length >= 16) {
        type = LicenseType.lifetime;
        expiresAt = null;
      } else {
        throw Exception('Format Serial Key tidak valid. Contoh: LRS-LIFE-ABCD-1234');
      }
    }

    final typeStr = (type == LicenseType.lifetime) ? 'lifetime' : 'subscription';
    final activatedStr = now.toIso8601String();
    final signature = _generateSignature(machineId, cleanKey, typeStr, activatedStr);

    await prefs.setString(_prefLicenseKey, cleanKey);
    await prefs.setString(_prefLicenseType, typeStr);
    await prefs.setString(_prefActivatedAt, activatedStr);
    if (expiresAt != null) {
      await prefs.setString(_prefExpiresAt, expiresAt.toIso8601String());
    } else {
      await prefs.remove(_prefExpiresAt);
    }
    await prefs.setString(_prefSignature, signature);

    return true;
  }

  String _generateSignature(String machineId, String key, String type, String date) {
    final raw = '$machineId:$key:$type:$date:$_secretSalt';
    final bytes = utf8.encode(raw);
    return crypto.sha256.convert(bytes).toString();
  }
}
