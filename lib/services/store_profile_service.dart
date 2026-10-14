import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import 'local_host_server_service.dart';

class StoreProfile {
  final String storeName;
  final String ownerName;
  final String storeAddress;
  final String storePhone;
  final String receiptFooter;

  const StoreProfile({
    required this.storeName,
    required this.ownerName,
    required this.storeAddress,
    required this.storePhone,
    required this.receiptFooter,
  });

  static const StoreProfile defaultProfile = StoreProfile(
    storeName: 'TOKO LARIS UMKM',
    ownerName: 'Kasir 01',
    storeAddress: 'Jl. Pasar Ritel No. 88, Indonesia',
    storePhone: '0812-3456-7890',
    receiptFooter: 'Terima Kasih Atas Kunjungan Anda!',
  );

  StoreProfile copyWith({
    String? storeName,
    String? ownerName,
    String? storeAddress,
    String? storePhone,
    String? receiptFooter,
  }) {
    return StoreProfile(
      storeName: storeName ?? this.storeName,
      ownerName: ownerName ?? this.ownerName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      receiptFooter: receiptFooter ?? this.receiptFooter,
    );
  }

  Map<String, dynamic> toJson() => {
    'store_name': storeName,
    'owner_name': ownerName,
    'store_address': storeAddress,
    'store_phone': storePhone,
    'receipt_footer': receiptFooter,
  };

  factory StoreProfile.fromJson(Map<String, dynamic> json) {
    return StoreProfile(
      storeName: (json['store_name'] as String?)?.trim() ?? defaultProfile.storeName,
      ownerName: (json['owner_name'] as String?)?.trim() ?? defaultProfile.ownerName,
      storeAddress: (json['store_address'] as String?)?.trim() ?? '',
      storePhone: (json['store_phone'] as String?)?.trim() ?? '',
      receiptFooter: (json['receipt_footer'] as String?)?.trim() ?? defaultProfile.receiptFooter,
    );
  }
}

class StoreProfileService extends ChangeNotifier {
  static final StoreProfileService instance = StoreProfileService._init();
  StoreProfileService._init();

  // Legacy fallback keys
  static const String _legacyKeyStoreName = 'laris_store_name';
  static const String _legacyKeyOwnerName = 'laris_owner_name';
  static const String _legacyKeyStoreAddress = 'laris_store_address';
  static const String _legacyKeyStorePhone = 'laris_store_phone';
  static const String _legacyKeyReceiptFooter = 'laris_receipt_footer';

  ConnectionMode _activeMode = ConnectionMode.offline;
  StoreProfile _profile = StoreProfile.defaultProfile;
  bool _isLoaded = false;

  ConnectionMode get activeMode => _activeMode;
  StoreProfile get profile => _profile;
  bool get isLoaded => _isLoaded;

  String _getPrefix(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.offline:
        return 'laris_profile_offline_';
      case ConnectionMode.cloud:
        return 'laris_profile_saas_';
      case ConnectionMode.wifi:
        return 'laris_profile_lan_';
      case ConnectionMode.usb:
        return 'laris_profile_usb_';
    }
  }

  Future<void> init({ConnectionMode? initialMode}) async {
    _activeMode = initialMode ?? ApiConstants.currentMode;
    await _loadForMode(_activeMode);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> switchMode(ConnectionMode mode) async {
    if (_activeMode == mode && _isLoaded) return;
    _activeMode = mode;
    await _loadForMode(mode);
    notifyListeners();
  }

  Future<void> _loadForMode(ConnectionMode mode) async {
    _profile = await getProfileForMode(mode);
  }

  Future<StoreProfile> getProfileForMode(ConnectionMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final pfx = _getPrefix(mode);

    String? storeName = prefs.getString('${pfx}store_name');
    String? ownerName = prefs.getString('${pfx}owner_name');
    String? storeAddress = prefs.getString('${pfx}store_address');
    String? storePhone = prefs.getString('${pfx}store_phone');
    String? receiptFooter = prefs.getString('${pfx}receipt_footer');

    // Backward-compatibility: if offline has not been set, migrate from legacy keys
    if (mode == ConnectionMode.offline && storeName == null) {
      storeName = prefs.getString(_legacyKeyStoreName);
      ownerName = prefs.getString(_legacyKeyOwnerName);
      storeAddress = prefs.getString(_legacyKeyStoreAddress);
      storePhone = prefs.getString(_legacyKeyStorePhone);
      receiptFooter = prefs.getString(_legacyKeyReceiptFooter);
    }

    return StoreProfile(
      storeName: (storeName != null && storeName.isNotEmpty) ? storeName : StoreProfile.defaultProfile.storeName,
      ownerName: (ownerName != null && ownerName.isNotEmpty) ? ownerName : StoreProfile.defaultProfile.ownerName,
      storeAddress: storeAddress ?? StoreProfile.defaultProfile.storeAddress,
      storePhone: storePhone ?? StoreProfile.defaultProfile.storePhone,
      receiptFooter: (receiptFooter != null && receiptFooter.isNotEmpty) ? receiptFooter : StoreProfile.defaultProfile.receiptFooter,
    );
  }

  Future<void> saveProfile(StoreProfile newProfile, {ConnectionMode? targetMode}) async {
    final mode = targetMode ?? _activeMode;
    final prefs = await SharedPreferences.getInstance();
    final pfx = _getPrefix(mode);

    await prefs.setString('${pfx}store_name', newProfile.storeName.trim());
    await prefs.setString('${pfx}owner_name', newProfile.ownerName.trim());
    await prefs.setString('${pfx}store_address', newProfile.storeAddress.trim());
    await prefs.setString('${pfx}store_phone', newProfile.storePhone.trim());
    await prefs.setString('${pfx}receipt_footer', newProfile.receiptFooter.trim());

    if (mode == _activeMode) {
      _profile = newProfile;
      notifyListeners();
    }

    // If this device is acting as LAN Host Server, notify connected client devices
    try {
      if (LocalHostServerService.instance.isRunning.value) {
        LocalHostServerService.instance.notifyDataChanged('profile_updated');
      }
    } catch (_) {}
  }
}

