import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/transaction_model.dart';
import '../models/analytics_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../services/local_host_server_service.dart';
import '../services/store_profile_service.dart';

class PosProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  final List<CartItem> _cart = [];
  bool _isLoading = false;
  String? _connectionError;
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  AnalyticsSummary? _summary;
  List<CustomerRecord> _customerHistory = [];

  // ⚡ Real-Time Bidirectional SSE & Host Data Sync
  HttpClient? _sseClient;
  StreamSubscription? _sseSub;
  StreamSubscription? _hostDataSub;
  Timer? _reconnectTimer;
  Timer? _cloudPollTimer;

  List<Product> get products {
    if (_selectedCategory == 'Semua') {
      return _products;
    }
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  List<CartItem> get cart => _cart;
  bool get isLoading => _isLoading;
  String? get connectionError => _connectionError;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  AnalyticsSummary? get summary => _summary;
  List<CustomerRecord> get customerHistory => _customerHistory;

  int get totalRevenueToday => _summary?.totalRevenue ?? 0;
  int get totalOrdersToday => _summary?.totalOrders ?? 0;
  int get lowStockCount => _products.where((p) => p.stock > 0 && p.stock <= 5).length;
  int get outOfStockCount => _products.where((p) => p.stock == 0).length;

  int get totalAmount => _cart.fold(0, (sum, item) => sum + item.subtotal);
  int get totalItems => _cart.fold(0, (sum, item) => sum + item.quantity);

  void clearConnectionError() {
    _connectionError = null;
    notifyListeners();
  }

  List<String> get categories {
    final set = <String>{'Semua'};
    for (var p in _products) {
      if (p.category.isNotEmpty) set.add(p.category);
    }
    return set.toList();
  }

  PosProvider() {
    WidgetsBinding.instance.addObserver(this);
    loadProducts();
    loadSummary();
    loadCustomerHistory();
    _initRealtimeSync();
  }

  void _initRealtimeSync() {
    // 1. Host Event Listener (Client ➔ Host instant refresh on Host screen)
    _hostDataSub?.cancel();
    _hostDataSub = LocalHostServerService.instance.onDataChanged.listen((event) {
      debugPrint('⚡ [PosProvider] Host onDataChanged received: $event');
      loadProducts(silent: true);
      loadSummary();
    });

    // 2. Client SSE Listener (Host ➔ All Clients real-time stream)
    _connectSseStream();

    // 3. Cloud Mode Background Polling (Multi-Kasir Cloud Real-Time Sync)
    _startCloudPolling();

    // 4. Initial store profile synchronization
    fetchAndSyncStoreProfile();
  }

  void _startCloudPolling() {
    _stopCloudPolling();
    if (ApiConstants.currentMode != ConnectionMode.cloud) return;

    _cloudPollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (ApiConstants.currentMode == ConnectionMode.cloud) {
        loadProducts(silent: true);
        loadSummary();
        fetchAndSyncStoreProfile();
      }
    });
  }

  void _stopCloudPolling() {
    _cloudPollTimer?.cancel();
    _cloudPollTimer = null;
  }

  /// 🔄 Synchronize store profile across devices (LAN Host to Client, and Cloud SaaS)
  Future<void> fetchAndSyncStoreProfile() async {
    final mode = ApiConstants.currentMode;
    if (mode == ConnectionMode.offline) return;

    // 1. Mode Cloud: synchronize with active Cloud SaaS backend
    if (mode == ConnectionMode.cloud) {
      if (AuthService.instance.isLoggedIn) {
        try {
          final cloudData = await AuthService.instance.fetchStoreProfile();
          if (cloudData != null) {
            final cloudStoreName = (cloudData['store_name'] as String?)?.trim();
            final cloudOwnerName = (cloudData['owner_name'] as String?)?.trim();
            final cloudPhone = (cloudData['phone'] as String?)?.trim();
            final currentProfile = StoreProfileService.instance.profile;
            if (cloudStoreName != null && cloudStoreName.isNotEmpty &&
                (currentProfile.storeName != cloudStoreName ||
                 (cloudOwnerName != null && cloudOwnerName.isNotEmpty && currentProfile.ownerName != cloudOwnerName) ||
                 (cloudPhone != null && cloudPhone.isNotEmpty && currentProfile.storePhone != cloudPhone))) {
              await StoreProfileService.instance.saveProfile(
                currentProfile.copyWith(
                  storeName: cloudStoreName,
                  ownerName: (cloudOwnerName != null && cloudOwnerName.isNotEmpty) ? cloudOwnerName : currentProfile.ownerName,
                  storePhone: (cloudPhone != null && cloudPhone.isNotEmpty) ? cloudPhone : currentProfile.storePhone,
                ),
                targetMode: ConnectionMode.cloud,
              );
              debugPrint('☁️ [PosProvider] Synced Cloud store profile from backend: $cloudStoreName');
            }
          }
        } catch (e) {
          debugPrint('☁️ [PosProvider] Cloud store profile sync error: $e');
        }
      }
      return;
    }

    // 2. Mode LAN / USB: Client fetches profile from Host embedded server
    if (LocalHostServerService.instance.isRunning.value) return; // Host maintains its own master profile

    final baseUrl = ApiConstants.posBaseUrl;
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) return;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      final lanToken = AuthService.instance.lanClusterToken;
      final effectiveToken = lanToken.isNotEmpty ? lanToken : 'laris-lan-sec-key';

      final res = await dio.get(
        '/api/v1/profile',
        options: Options(headers: {
          'x-cluster-auth': effectiveToken,
          'Authorization': 'Bearer $effectiveToken',
        }),
      );

      if (res.statusCode == 200 && res.data is Map) {
        final profileData = Map<String, dynamic>.from(res.data);
        final fetchedProfile = StoreProfile.fromJson(profileData);
        await StoreProfileService.instance.saveProfile(
          fetchedProfile,
          targetMode: mode,
        );
        debugPrint('📶 [PosProvider] Synced LAN profile from Host: ${fetchedProfile.storeName}');
      }
    } catch (e) {
      debugPrint('⚠️ [PosProvider] Could not sync store profile from Host: $e');
    }
  }

  void _connectSseStream() async {
    _disconnectSse();

    // Only connect if in wifi/usb mode and this device is NOT the host
    if (ApiConstants.currentMode != ConnectionMode.wifi && ApiConstants.currentMode != ConnectionMode.usb) {
      return;
    }
    if (LocalHostServerService.instance.isRunning.value) {
      return;
    }

    final baseUrl = ApiConstants.posBaseUrl;
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      return;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/events');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      _sseClient = client;

      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      final lanToken = AuthService.instance.lanClusterToken;
      final effectiveToken = lanToken.isNotEmpty ? lanToken : 'laris-lan-sec-key';
      request.headers.set('x-cluster-auth', effectiveToken);
      request.headers.set('Authorization', 'Bearer $effectiveToken');

      final response = await request.close();
      if (response.statusCode == 200) {
        // Fetch profile immediately upon establishing connection
        fetchAndSyncStoreProfile();

        _sseSub = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          if (line.startsWith('event: ')) {
            final event = line.substring(7).trim();
            debugPrint('⚡ [PosProvider] Client SSE event: $event');
            if (event == 'profile_updated') {
              fetchAndSyncStoreProfile();
            } else {
              loadProducts(silent: true);
              loadSummary();
            }
          }
        }, onError: (err) {
          _reconnectSseWithBackoff();
        }, onDone: () {
          _reconnectSseWithBackoff();
        });
      } else {
        _reconnectSseWithBackoff();
      }
    } catch (_) {
      _reconnectSseWithBackoff();
    }
  }

  void _reconnectSseWithBackoff() {
    _disconnectSse();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connectSseStream();
    });
  }

  void _disconnectSse() {
    _reconnectTimer?.cancel();
    _sseSub?.cancel();
    _sseSub = null;
    _sseClient?.close(force: true);
    _sseClient = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _disconnectSse();
      _stopCloudPolling();
    } else if (state == AppLifecycleState.resumed) {
      loadProducts(silent: true);
      loadSummary();
      _connectSseStream();
      _startCloudPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hostDataSub?.cancel();
    _disconnectSse();
    _stopCloudPolling();
    super.dispose();
  }

  Future<void> loadCustomerHistory() async {
    try {
      _customerHistory = await LocalDbService.instance.getCustomerHistory();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadSummary() async {
    try {
      _summary = await _apiService.getAnalyticsSummary();
      notifyListeners();
    } catch (_) {}
  }

  void updateBaseUrls() {
    _apiService.updateBaseUrls();
    _connectSseStream();
    _startCloudPolling();
    fetchAndSyncStoreProfile();
  }

  Future<void> loadProducts({String? search, bool silent = false}) async {
    _apiService.updateBaseUrls();
    if (!silent) {
      _isLoading = true;
      _connectionError = null;
      notifyListeners();
    }
    _searchQuery = search ?? '';
    try {
      _products = await _apiService.getProducts(search: search);
      _connectionError = null;
    } catch (e) {
      debugPrint('Error loading products: $e');
      _products = [];
      if (e is CloudConnectionException) {
        _connectionError = e.message;
      } else if (e is LanConnectionException) {
        _connectionError = e.message;
      } else {
        _connectionError = 'Gagal memuat produk: $e';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    loadSummary();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void addToCart(Product product) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      if (_cart[index].quantity < product.stock) {
        _cart[index].quantity++;
      }
    } else {
      if (product.stock > 0) {
        _cart.add(CartItem(product: product, quantity: 1));
      }
    }
    notifyListeners();
  }

  void decreaseQuantity(Product product) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeFromCart(Product product) {
    _cart.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<Product?> scanAndAddToCart(String barcode) async {
    // 1. Check existing in products list
    try {
      final existing = _products.firstWhere((p) => p.barcode == barcode);
      addToCart(existing);
      return existing;
    } catch (_) {}

    // 2. Fetch from backend API
    final fetched = await _apiService.getProductByBarcode(barcode);
    if (fetched != null) {
      _products.insert(0, fetched);
      addToCart(fetched);
      notifyListeners();
      return fetched;
    }
    return null;
  }

  Future<Transaction?> processCheckout({
    required String paymentType,
    String? customerId,
  }) async {
    if (_cart.isEmpty) return null;

    final checkoutItems = _cart.map((i) => i.toCheckoutJson()).toList();
    final transaction = await _apiService.checkout(
      items: checkoutItems,
      paymentType: paymentType,
      customerId: customerId,
    );

    if (transaction != null) {
      // Reduce local stock for reactive UI
      for (var item in _cart) {
        final pIndex = _products.indexWhere((p) => p.id == item.product.id);
        if (pIndex >= 0) {
          final updatedStock = (_products[pIndex].stock - item.quantity).clamp(0, 99999);
          _products[pIndex] = _products[pIndex].copyWith(stock: updatedStock);
        }
      }
      clearCart();
      loadSummary();

      // Save customer to CRM database if present
      if (customerId != null && customerId.trim().isNotEmpty) {
        final raw = customerId.trim();
        final match = RegExp(r'^(.*?)\s*[\(\-•]\s*(08\d{8,13}|\+?62\d{8,13})\)?$').firstMatch(raw);
        final name = match != null ? (match.group(1)?.trim() ?? raw) : raw;
        final phone = match != null ? (match.group(2)?.trim() ?? '') : '';
        await LocalDbService.instance.saveCustomer(name: name, phone: phone);
        await loadCustomerHistory();
      }
    }
    return transaction;
  }

  Future<bool> addNewProduct(Product product) async {
    final created = await _apiService.createProduct(product);
    _products.insert(0, created);
    notifyListeners();
    return true;
  }

  Future<bool> updateProduct(Product product) async {
    final success = await _apiService.updateProduct(product);
    if (success) {
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        _products[index] = product;
      }
      final cartIndex = _cart.indexWhere((item) => item.product.id == product.id);
      if (cartIndex >= 0) {
        final currentQty = _cart[cartIndex].quantity;
        _cart[cartIndex] = CartItem(
          product: product,
          quantity: currentQty.clamp(1, product.stock > 0 ? product.stock : 1),
        );
      }
      notifyListeners();
    }
    return success;
  }

  Future<bool> deleteProduct(String id) async {
    final success = await _apiService.deleteProduct(id);
    if (success) {
      _products.removeWhere((p) => p.id == id);
      _cart.removeWhere((item) => item.product.id == id);
      notifyListeners();
    }
    return success;
  }

  Future<bool> voidTransaction(String invoiceNo) async {
    final success = await _apiService.voidTransaction(invoiceNo);
    if (success) {
      await loadProducts();
      await loadSummary();
      await loadCustomerHistory();
      notifyListeners();
    }
    return success;
  }

  // --- PURGE & RESET ACTIONS ---
  Future<void> clearTransactions() async {
    await LocalDbService.instance.clearTransactionsOnly();
    clearCart();
    await loadProducts();
    await loadSummary();
    notifyListeners();
  }

  Future<void> factoryResetDatabase({bool reseedStarterProducts = false}) async {
    await LocalDbService.instance.factoryResetDatabase(reseedStarterProducts: reseedStarterProducts);
    clearCart();
    await loadProducts();
    await loadSummary();
    notifyListeners();
  }
}
