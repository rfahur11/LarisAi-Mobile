import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

class StoreProfileService extends ChangeNotifier {
  static final StoreProfileService instance = StoreProfileService._init();
  StoreProfileService._init();

  static const String _keyStoreName = 'laris_store_name';
  static const String _keyOwnerName = 'laris_owner_name';
  static const String _keyStoreAddress = 'laris_store_address';
  static const String _keyStorePhone = 'laris_store_phone';
  static const String _keyReceiptFooter = 'laris_receipt_footer';

  StoreProfile _profile = StoreProfile.defaultProfile;
  bool _isLoaded = false;

  StoreProfile get profile => _profile;
  bool get isLoaded => _isLoaded;

  Future<void> init() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _profile = StoreProfile(
      storeName: prefs.getString(_keyStoreName) ?? StoreProfile.defaultProfile.storeName,
      ownerName: prefs.getString(_keyOwnerName) ?? StoreProfile.defaultProfile.ownerName,
      storeAddress: prefs.getString(_keyStoreAddress) ?? StoreProfile.defaultProfile.storeAddress,
      storePhone: prefs.getString(_keyStorePhone) ?? StoreProfile.defaultProfile.storePhone,
      receiptFooter: prefs.getString(_keyReceiptFooter) ?? StoreProfile.defaultProfile.receiptFooter,
    );
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveProfile(StoreProfile newProfile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoreName, newProfile.storeName.trim());
    await prefs.setString(_keyOwnerName, newProfile.ownerName.trim());
    await prefs.setString(_keyStoreAddress, newProfile.storeAddress.trim());
    await prefs.setString(_keyStorePhone, newProfile.storePhone.trim());
    await prefs.setString(_keyReceiptFooter, newProfile.receiptFooter.trim());

    _profile = newProfile;
    notifyListeners();
  }
}
