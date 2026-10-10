import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const String _prefToken = 'larisai_jwt_token';
  static const String _prefStoreId = 'larisai_store_id';
  static const String _prefStoreName = 'larisai_store_name';
  static const String _prefEmail = 'larisai_auth_email';

  String? _token;
  String? _storeId;
  String? _storeName;
  String? _email;
  bool _isLoading = false;

  String? get token => _token;
  String? get storeId => _storeId;
  String get storeName => _storeName ?? 'Toko UMKM';
  String? get email => _email;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefToken);
    _storeId = prefs.getString(_prefStoreId);
    _storeName = prefs.getString(_prefStoreName);
    _email = prefs.getString(_prefEmail);
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.posBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await dio.post(
        '/api/v1/auth/login',
        data: {'email': email.trim(), 'password': password.trim()},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        final token = data['token'] as String;
        final storeId = (data['store_id'] as String?) ?? 'STORE_DEFAULT';
        final storeName = (data['store_name'] as String?) ?? (data['user']?['name'] as String?) ?? 'Toko Laris UMKM';

        _token = token;
        _storeId = storeId;
        _storeName = storeName;
        _email = email.trim();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefToken, token);
        await prefs.setString(_prefStoreId, storeId);
        await prefs.setString(_prefStoreName, storeName);
        await prefs.setString(_prefEmail, email.trim());

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('AuthService login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _storeId = null;
    _storeName = null;
    _email = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefToken);
    await prefs.remove(_prefStoreId);
    await prefs.remove(_prefStoreName);
    await prefs.remove(_prefEmail);

    notifyListeners();
  }
}
