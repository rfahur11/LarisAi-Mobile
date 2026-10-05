import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../models/ai_insights_model.dart';
import '../models/analytics_model.dart';
import 'local_db_service.dart';

class ApiService {
  late Dio _posDio;
  late Dio _aiDio;
  final LocalDbService _localDb = LocalDbService.instance;

  ApiService() {
    _posDio = Dio(BaseOptions(
      baseUrl: ApiConstants.posBaseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {'Content-Type': 'application/json'},
    ));

    _aiDio = Dio(BaseOptions(
      baseUrl: ApiConstants.aiBaseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  void updateBaseUrls() {
    if (!ApiConstants.isOfflineMode) {
      _posDio.options.baseUrl = ApiConstants.posBaseUrl;
      _aiDio.options.baseUrl = ApiConstants.aiBaseUrl;
    }
  }

  // --- PRODUCTS ---
  Future<List<Product>> getProducts({String? search}) async {
    // If in Offline Lifetime Mode, query local SQLite directly
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getProducts(search: search);
    }

    try {
      final response = await _posDio.get(
        '/api/v1/products',
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
      );
      if (response.statusCode == 200 && response.data is List) {
        final products = (response.data as List).map((p) => Product.fromJson(p)).toList();
        // Sync to local cache in background
        for (var p in products) {
          _localDb.insertProduct(p);
        }
        return products;
      }
    } catch (_) {
      // Seamless offline fallback to Local SQLite
      return await _localDb.getProducts(search: search);
    }
    return await _localDb.getProducts(search: search);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getProductByBarcode(barcode);
    }

    try {
      final response = await _posDio.get('/api/v1/products/scan/$barcode');
      if (response.statusCode == 200 && response.data != null) {
        final product = Product.fromJson(response.data);
        _localDb.insertProduct(product);
        return product;
      }
    } catch (_) {
      return await _localDb.getProductByBarcode(barcode);
    }
    return await _localDb.getProductByBarcode(barcode);
  }

  Future<Product> createProduct(Product product) async {
    // Always store to local SQLite first
    final savedLocal = await _localDb.insertProduct(product);

    if (ApiConstants.isOfflineMode) {
      return savedLocal;
    }

    try {
      final response = await _posDio.post(
        '/api/v1/products',
        data: product.toJson(),
      );
      if (response.statusCode == 201 && response.data != null) {
        return Product.fromJson(response.data);
      }
    } catch (_) {}
    return savedLocal;
  }

  // --- CHECKOUT ---
  Future<Transaction?> checkout({
    required List<Map<String, dynamic>> items,
    required String paymentType,
    String? customerId,
  }) async {
    // If offline lifetime mode, execute atomic SQLite transaction
    if (ApiConstants.isOfflineMode) {
      return await _localDb.insertTransaction(
        items: items,
        paymentType: paymentType,
        customerId: customerId,
      );
    }

    try {
      final response = await _posDio.post(
        '/api/v1/checkout',
        data: {
          'items': items,
          'payment_type': paymentType,
          if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
        },
      );
      if (response.statusCode == 201 && response.data != null) {
        final tx = Transaction.fromJson(response.data);
        // Also save to local DB
        _localDb.insertTransaction(
          items: items,
          paymentType: paymentType,
          customerId: customerId,
        );
        return tx;
      }
    } catch (_) {
      // Offline fallback: save locally
      return await _localDb.insertTransaction(
        items: items,
        paymentType: paymentType,
        customerId: customerId,
      );
    }
    return null;
  }

  // --- TRANSACTIONS ---
  Future<List<Transaction>> getTransactions() async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getTransactions();
    }

    try {
      final response = await _posDio.get('/api/v1/transactions');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((t) => Transaction.fromJson(t)).toList();
      }
    } catch (_) {
      return await _localDb.getTransactions();
    }
    return await _localDb.getTransactions();
  }

  // --- ANALYTICS ---
  Future<AnalyticsSummary> getAnalyticsSummary({String timeRange = 'SEMUA'}) async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getAnalyticsSummary(timeRange: timeRange);
    }

    try {
      final response = await _posDio.get(
        '/api/v1/analytics/summary',
        queryParameters: {'time_range': timeRange},
      );
      if (response.statusCode == 200 && response.data != null) {
        return AnalyticsSummary.fromJson(response.data);
      }
    } catch (_) {
      return await _localDb.getAnalyticsSummary(timeRange: timeRange);
    }
    return await _localDb.getAnalyticsSummary(timeRange: timeRange);
  }

  // --- AI ENGINE (Stockout & Clustering) ---
  Future<List<StockoutPrediction>> getAiStockoutPredictions() async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getAiStockoutPredictions();
    }

    try {
      final response = await _aiDio.get('/api/v1/ai/forecasting/stockouts');
      if (response.statusCode == 200 && response.data != null) {
        var raw = response.data['predictions'] as List<dynamic>? ?? [];
        return raw.map((p) => StockoutPrediction.fromJson(p)).toList();
      }
    } catch (_) {
      return await _localDb.getAiStockoutPredictions();
    }
    return await _localDb.getAiStockoutPredictions();
  }

  Future<List<CustomerCluster>> getAiCustomerClusters() async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getAiCustomerClusters();
    }

    try {
      final response = await _aiDio.get('/api/v1/ai/clustering/customers');
      if (response.statusCode == 200 && response.data != null) {
        var raw = response.data['clusters'] as List<dynamic>? ?? [];
        return raw.map((c) => CustomerCluster.fromJson(c)).toList();
      }
    } catch (_) {
      return await _localDb.getAiCustomerClusters();
    }
    return await _localDb.getAiCustomerClusters();
  }

  Future<bool> sendAiPromo({required String clusterLabel, required String message}) async {
    if (ApiConstants.isOfflineMode) {
      // In offline lifetime mode, simulate sending / open WhatsApp URI
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    try {
      final response = await _aiDio.post(
        '/api/v1/ai/promo/send',
        data: {
          'cluster_label': clusterLabel,
          'message': message,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return true;
    }
  }
}
