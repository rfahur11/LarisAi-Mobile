import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import 'store_profile_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const String _prefToken = 'larisai_jwt_token';
  static const String _prefStoreId = 'larisai_store_id';
  static const String _prefStoreName = 'larisai_store_name';
  static const String _prefEmail = 'larisai_auth_email';
  static const String _prefPhone = 'larisai_auth_phone';
  static const String _prefPlanTier = 'larisai_plan_tier';
  static const String _prefSubscriptionStatus = 'larisai_subscription_status';
  static const String _prefExpiresAt = 'larisai_expires_at';
  static const String _prefTrialEndsAt = 'larisai_trial_ends_at';
  static const String _prefLanClusterToken = 'larisai_lan_cluster_token';
  static const String _prefLanPin = 'larisai_lan_pin';

  String? _token;
  String? _storeId;
  String? _storeName;
  String? _email;
  String? _phone;
  String _planTier = 'trial';
  String _subscriptionStatus = 'trial';
  DateTime? _expiresAt;
  DateTime? _trialEndsAt;
  bool _isLoading = false;
  String? _lastError;

  String _lanClusterToken = 'laris-lan-sec-key';
  String _lanPin = '1234';

  String? get token => _token;
  String get lanClusterToken => _lanClusterToken;
  String get lanPin => _lanPin;
  String? get storeId => _storeId;
  String get storeName => _storeName ?? 'Toko UMKM';
  String? get email => _email;
  String? get phone => _phone;
  String get planTier => _planTier;
  String get subscriptionStatus => _subscriptionStatus;
  DateTime? get expiresAt => _expiresAt;
  DateTime? get trialEndsAt => _trialEndsAt;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  int get remainingDays {
    final target = _expiresAt ?? _trialEndsAt;
    if (target == null) return 0;
    final diff = target.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  bool get isTrialActive => _subscriptionStatus == 'trial' && (_trialEndsAt == null || _trialEndsAt!.isAfter(DateTime.now()));
  bool get isSubscriptionActive => _subscriptionStatus == 'active' && (_expiresAt == null || _expiresAt!.isAfter(DateTime.now()));
  bool get isExpired => remainingDays <= 0 && _subscriptionStatus == 'expired';

  String get subscriptionBadgeText {
    if (_subscriptionStatus == 'trial') {
      return '🎉 Free Trial (Sisa $remainingDays Hari)';
    } else if (_subscriptionStatus == 'active') {
      final tierName = _planTier == 'subs_yearly' ? 'Tahunan' : (_planTier == 'lan_multidevice' ? 'LAN Resto' : 'Bulanan');
      return '✅ Paket $tierName Aktif (Sisa $remainingDays Hari)';
    } else if (_subscriptionStatus == 'grace_period') {
      return '⚠️ Masa Tenggang Grace Period ($remainingDays Hari)';
    } else {
      return '❌ Langganan Berakhir';
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefToken);
    _storeId = prefs.getString(_prefStoreId);
    _storeName = prefs.getString(_prefStoreName);
    _email = prefs.getString(_prefEmail);
    _phone = prefs.getString(_prefPhone);
    _planTier = prefs.getString(_prefPlanTier) ?? 'trial';
    _subscriptionStatus = prefs.getString(_prefSubscriptionStatus) ?? 'trial';

    final expStr = prefs.getString(_prefExpiresAt);
    if (expStr != null && expStr.isNotEmpty) {
      _expiresAt = DateTime.tryParse(expStr);
    }
    final trialStr = prefs.getString(_prefTrialEndsAt);
    if (trialStr != null && trialStr.isNotEmpty) {
      _trialEndsAt = DateTime.tryParse(trialStr);
    } else if (isLoggedIn && _expiresAt == null) {
      _trialEndsAt = DateTime.now().add(const Duration(days: 14));
    }

    _lanClusterToken = prefs.getString(_prefLanClusterToken) ?? 'laris-lan-sec-key';
    _lanPin = prefs.getString(_prefLanPin) ?? '1234';

    notifyListeners();
  }

  /// 🛡️ Menyimpan sesi autentikasi kluster LAN lokal (bebas registrasi/cloud)
  Future<void> setLanClusterSession({
    required String clusterToken,
    String pin = '1234',
    String? storeName,
    String? storeId,
  }) async {
    _lanClusterToken = clusterToken.trim().isNotEmpty ? clusterToken.trim() : 'laris-lan-sec-key';
    _lanPin = pin.trim().isNotEmpty ? pin.trim() : '1234';
    if (storeName != null && storeName.isNotEmpty) {
      _storeName = storeName;
    }
    if (storeId != null && storeId.isNotEmpty) {
      _storeId = storeId;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLanClusterToken, _lanClusterToken);
    await prefs.setString(_prefLanPin, _lanPin);
    if (_storeName != null) await prefs.setString(_prefStoreName, _storeName!);
    if (_storeId != null) await prefs.setString(_prefStoreId, _storeId!);
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_prefToken, _token!);
    if (_storeId != null) await prefs.setString(_prefStoreId, _storeId!);
    if (_storeName != null) await prefs.setString(_prefStoreName, _storeName!);
    if (_email != null) await prefs.setString(_prefEmail, _email!);
    if (_phone != null) await prefs.setString(_prefPhone, _phone!);
    await prefs.setString(_prefPlanTier, _planTier);
    await prefs.setString(_prefSubscriptionStatus, _subscriptionStatus);

    if (_expiresAt != null) {
      await prefs.setString(_prefExpiresAt, _expiresAt!.toIso8601String());
    } else {
      await prefs.remove(_prefExpiresAt);
    }

    if (_trialEndsAt != null) {
      await prefs.setString(_prefTrialEndsAt, _trialEndsAt!.toIso8601String());
    } else {
      await prefs.remove(_prefTrialEndsAt);
    }
  }

  Future<bool> login({required String email, required String password, String? baseUrl}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final effectiveUrl = (baseUrl != null && baseUrl.startsWith('http'))
          ? baseUrl
          : (ApiConstants.posBaseUrl.startsWith('http')
              ? ApiConstants.posBaseUrl
              : ApiConstants.cloudPosBaseUrl);

      final dio = Dio(BaseOptions(
        baseUrl: effectiveUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await dio.post(
        '/api/v1/auth/login',
        data: {'email': email.trim(), 'password': password.trim()},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        final token = data['token'] as String;
        final storeId = (data['store_id'] as String?) ?? 'STORE_DEFAULT';
        final storeName = (data['store_name'] as String?) ?? (data['user']?['name'] as String?) ?? 'Toko Laris UMKM';
        final userPhone = (data['phone'] as String?) ?? (data['user']?['phone'] as String?);

        _token = token;
        _storeId = storeId;
        _storeName = storeName;
        _email = email.trim();
        if (userPhone != null && userPhone.isNotEmpty) {
          _phone = userPhone;
        }

        // Parse subscription metadata if present
        if (data['subscription'] != null) {
          final sub = data['subscription'];
          _planTier = (sub['plan_tier'] as String?) ?? 'trial';
          _subscriptionStatus = (sub['status'] as String?) ?? 'trial';
          if (sub['expires_at'] != null) {
            _expiresAt = DateTime.tryParse(sub['expires_at'].toString());
          }
          if (sub['trial_ends_at'] != null) {
            _trialEndsAt = DateTime.tryParse(sub['trial_ends_at'].toString());
          }
        } else {
          // Default 14-day trial
          _planTier = 'trial';
          _subscriptionStatus = 'trial';
          _trialEndsAt ??= DateTime.now().add(const Duration(days: 14));
        }

        await _saveToPrefs();

        // Otomatis sinkronisasi identitas toko & profil UMKM
        try {
          final currentProfile = StoreProfileService.instance.profile;
          final ownerName = (data['user']?['name'] as String?) ?? (data['name'] as String?) ?? currentProfile.ownerName;
          await StoreProfileService.instance.saveProfile(
            currentProfile.copyWith(
              storeName: storeName,
              ownerName: ownerName,
              storePhone: userPhone ?? currentProfile.storePhone,
            ),
          );
        } catch (e) {
          debugPrint('StoreProfile auto-sync error on login: $e');
        }

        _isLoading = false;
        _lastError = null;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final resData = e.response?.data;
        if (resData is Map && resData['error'] != null) {
          final errObj = resData['error'];
          _lastError = errObj is Map && errObj['message'] != null ? errObj['message'].toString() : errObj.toString();
        } else if (resData is Map && resData['message'] != null) {
          _lastError = resData['message'].toString();
        } else if (e.response?.statusCode == 401) {
          _lastError = 'Email atau password salah.';
        } else {
          _lastError = 'Login gagal (Kode: ${e.response?.statusCode}).';
        }
      } else {
        _lastError = 'Tidak dapat menghubungi server: ${e.message ?? 'Koneksi terputus/timeout'}.';
      }
      debugPrint('AuthService login DioException: $_lastError');
    } catch (e) {
      _lastError = 'Terjadi kesalahan sistem: $e';
      debugPrint('AuthService login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> registerMerchant({
    required String name,
    required String storeName,
    required String email,
    required String password,
    required String phone,
    String? category,
    String? baseUrl,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final effectiveUrl = (baseUrl != null && baseUrl.startsWith('http'))
          ? baseUrl
          : (ApiConstants.posBaseUrl.startsWith('http')
              ? ApiConstants.posBaseUrl
              : ApiConstants.cloudPosBaseUrl);

      final dio = Dio(BaseOptions(
        baseUrl: effectiveUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await dio.post(
        '/api/v1/auth/register-merchant',
        data: {
          'name': name.trim(),
          'store_name': storeName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password.trim(),
          'phone': phone.trim(),
          'category': category?.trim() ?? 'Retail',
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final data = response.data['data'] ?? response.data;
        final token = data['token'] as String;
        final storeId = (data['store_id'] as String?) ?? 'STORE_${DateTime.now().millisecondsSinceEpoch}';
        final storeNameRes = (data['store_name'] as String?) ?? storeName.trim();

        _token = token;
        _storeId = storeId;
        _storeName = storeNameRes;
        _email = email.trim().toLowerCase();
        _phone = phone.trim();
        _planTier = 'trial';
        _subscriptionStatus = 'trial';
        _trialEndsAt = DateTime.now().add(const Duration(days: 14));
        _expiresAt = null;

        await _saveToPrefs();

        // Otomatis sinkronisasi identitas toko & profil UMKM
        try {
          final currentProfile = StoreProfileService.instance.profile;
          await StoreProfileService.instance.saveProfile(
            currentProfile.copyWith(
              storeName: storeNameRes,
              ownerName: name.trim(),
              storePhone: phone.trim(),
            ),
          );
        } catch (e) {
          debugPrint('StoreProfile auto-sync error on register: $e');
        }

        _isLoading = false;
        _lastError = null;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final resData = e.response?.data;
        if (resData is Map && resData['error'] != null) {
          final errObj = resData['error'];
          _lastError = errObj is Map && errObj['message'] != null ? errObj['message'].toString() : errObj.toString();
        } else if (resData is Map && resData['message'] != null) {
          _lastError = resData['message'].toString();
        } else if (e.response?.statusCode == 401) {
          _lastError = 'Akses ditolak (401): Endpoint server belum mengizinkan pendaftaran.';
        } else if (e.response?.statusCode == 409) {
          _lastError = 'Email ini sudah terdaftar. Silakan masuk atau gunakan email lain.';
        } else {
          _lastError = 'Gagal mendaftar (Kode: ${e.response?.statusCode}).';
        }
      } else {
        _lastError = 'Tidak dapat menghubungi server cloud: ${e.message ?? 'Koneksi timeout'}.';
      }
      debugPrint('AuthService registerMerchant DioException: $_lastError');
    } catch (e) {
      _lastError = 'Terjadi kesalahan sistem: $e';
      debugPrint('AuthService registerMerchant error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>?> fetchSubscriptionStatus({String? baseUrl}) async {
    if (!isLoggedIn) return null;
    try {
      final effectiveUrl = (baseUrl != null && baseUrl.startsWith('http'))
          ? baseUrl
          : (ApiConstants.posBaseUrl.startsWith('http')
              ? ApiConstants.posBaseUrl
              : ApiConstants.cloudPosBaseUrl);

      final dio = Dio(BaseOptions(
        baseUrl: effectiveUrl,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ));

      final response = await dio.get('/api/v1/subscription/status');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        _planTier = (data['plan_tier'] as String?) ?? _planTier;
        _subscriptionStatus = (data['status'] as String?) ?? _subscriptionStatus;
        if (data['expires_at'] != null) {
          _expiresAt = DateTime.tryParse(data['expires_at'].toString());
        }
        if (data['trial_ends_at'] != null) {
          _trialEndsAt = DateTime.tryParse(data['trial_ends_at'].toString());
        }
        await _saveToPrefs();
        notifyListeners();
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('fetchSubscriptionStatus error: $e');
    }
    return null;
  }

  Future<void> logout() async {
    _token = null;
    _storeId = null;
    _storeName = null;
    _email = null;
    _phone = null;
    _planTier = 'trial';
    _subscriptionStatus = 'trial';
    _expiresAt = null;
    _trialEndsAt = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefToken);
    await prefs.remove(_prefStoreId);
    await prefs.remove(_prefStoreName);
    await prefs.remove(_prefEmail);
    await prefs.remove(_prefPhone);
    await prefs.remove(_prefPlanTier);
    await prefs.remove(_prefSubscriptionStatus);
    await prefs.remove(_prefExpiresAt);
    await prefs.remove(_prefTrialEndsAt);

    notifyListeners();
  }
}
