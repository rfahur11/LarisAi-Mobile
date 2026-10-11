import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../core/constants/api_constants.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../models/ai_insights_model.dart';
import '../models/analytics_model.dart';
import 'auth_service.dart';
import 'local_db_service.dart';

class CloudConnectionException implements Exception {
  final String message;
  final int? statusCode;
  CloudConnectionException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class LanConnectionException implements Exception {
  final String message;
  final int? statusCode;
  LanConnectionException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  late Dio _posDio;
  late Dio _aiDio;
  final LocalDbService _localDb = LocalDbService.instance;

  ApiService() {
    _posDio = Dio(BaseOptions(
      baseUrl: ApiConstants.posBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Content-Type': 'application/json'},
    ));

    _aiDio = Dio(BaseOptions(
      baseUrl: ApiConstants.aiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Content-Type': 'application/json'},
    ));

    final authInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = AuthService.instance.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // If 401 occurs in Cloud/LAN mode, do not auto-login with hardcoded admin demo credentials.
        // Forward error so calling code and UI can react appropriately.
        return handler.next(e);
      },
    );

    _posDio.interceptors.add(authInterceptor);
    _aiDio.interceptors.add(authInterceptor);
  }

  void updateBaseUrls() {
    if (!ApiConstants.isOfflineMode) {
      _posDio.options.baseUrl = ApiConstants.posBaseUrl;
      _aiDio.options.baseUrl = ApiConstants.aiBaseUrl;
    }
  }

  Future<Database?> _getTenantDbOrNull() async {
    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      final storeId = AuthService.instance.storeId;
      if (storeId != null && storeId.isNotEmpty) {
        return await _localDb.getTenantDatabase(storeId);
      }
    }
    return null;
  }

  // --- PRODUCTS ---
  Future<List<Product>> getProducts({String? search}) async {
    // 1. Lifetime Offline Mode -> Query local SQLite directly
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getProducts(search: search);
    }

    // 2. Cloud SaaS Mode -> Remote Cloud API with isolated tenant caching
    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      final tenantDb = await _getTenantDbOrNull();
      try {
        final response = await _posDio.get(
          '/api/v1/products',
          queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
        );
        if (response.statusCode == 200 && response.data is List) {
          final products = (response.data as List).map((p) => Product.fromJson(p)).toList();
          if (tenantDb != null) {
            for (var p in products) {
              await _localDb.insertProduct(p, customDb: tenantDb);
            }
          }
          return products;
        }
      } on DioException catch (e) {
        // If tenant has cached data from an earlier session, serve isolated tenant cache
        if (tenantDb != null) {
          final cached = await _localDb.getProducts(search: search, customDb: tenantDb);
          if (cached.isNotEmpty) {
            return cached;
          }
        }
        throw CloudConnectionException(
          'Koneksi Cloud Terputus: Tidak dapat menghubungi server (${e.response?.statusCode ?? 'Timeout'}). Periksa internet Anda.',
          statusCode: e.response?.statusCode,
        );
      } catch (e) {
        if (tenantDb != null) {
          final cached = await _localDb.getProducts(search: search, customDb: tenantDb);
          if (cached.isNotEmpty) return cached;
        }
        throw CloudConnectionException('Koneksi Cloud Terputus: $e');
      }
      throw CloudConnectionException('Gagal memuat produk dari server Cloud.');
    }

    // 3. Wi-Fi LAN / USB Mode -> Host PC API
    try {
      final response = await _posDio.get(
        '/api/v1/products',
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((p) => Product.fromJson(p)).toList();
      }
    } on DioException catch (e) {
      throw LanConnectionException(
        'Server Host LAN Terputus: Tidak dapat terhubung ke ${ApiConstants.posBaseUrl}. Pastikan Host PC aktif dan terhubung ke Wi-Fi yang sama.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw LanConnectionException('Server Host LAN Terputus: $e');
    }
    throw LanConnectionException('Gagal memuat produk dari Host LAN.');
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getProductByBarcode(barcode);
    }

    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      final tenantDb = await _getTenantDbOrNull();
      try {
        final response = await _posDio.get('/api/v1/products/scan/$barcode');
        if (response.statusCode == 200 && response.data != null) {
          final product = Product.fromJson(response.data);
          if (tenantDb != null) {
            await _localDb.insertProduct(product, customDb: tenantDb);
          }
          return product;
        }
      } on DioException catch (e) {
        if (tenantDb != null) {
          final cached = await _localDb.getProductByBarcode(barcode, customDb: tenantDb);
          if (cached != null) return cached;
        }
        throw CloudConnectionException('Koneksi Cloud Terputus: Barcode $barcode tidak ditemukan.', statusCode: e.response?.statusCode);
      }
      return null;
    }

    // LAN / USB
    try {
      final response = await _posDio.get('/api/v1/products/scan/$barcode');
      if (response.statusCode == 200 && response.data != null) {
        return Product.fromJson(response.data);
      }
    } on DioException catch (e) {
      throw LanConnectionException('Host LAN Terputus: Barcode $barcode tidak terdeteksi di server Host.', statusCode: e.response?.statusCode);
    }
    return null;
  }

  Future<Product> createProduct(Product product) async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.insertProduct(product);
    }

    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      try {
        final response = await _posDio.post(
          '/api/v1/products',
          data: product.toJson(),
        );
        if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
          final created = Product.fromJson(response.data);
          final tenantDb = await _getTenantDbOrNull();
          if (tenantDb != null) {
            await _localDb.insertProduct(created, customDb: tenantDb);
          }
          return created;
        }
      } on DioException catch (e) {
        throw CloudConnectionException(
          'Gagal menambah produk ke Cloud: ${e.response?.data?['message'] ?? e.message}',
          statusCode: e.response?.statusCode,
        );
      }
      throw CloudConnectionException('Gagal menambah produk ke Cloud.');
    }

    // LAN / USB
    try {
      final response = await _posDio.post('/api/v1/products', data: product.toJson());
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        return Product.fromJson(response.data);
      }
    } on DioException catch (e) {
      throw LanConnectionException('Gagal menambah produk ke Host LAN: ${e.message}');
    }
    throw LanConnectionException('Gagal menambah produk ke Host LAN.');
  }

  Future<bool> updateProduct(Product product) async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.updateProduct(product);
    }

    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      try {
        final response = await _posDio.put(
          '/api/v1/products/${product.id}',
          data: product.toJson(),
        );
        final tenantDb = await _getTenantDbOrNull();
        if (tenantDb != null) {
          await _localDb.updateProduct(product, customDb: tenantDb);
        }
        return response.statusCode == 200;
      } on DioException catch (e) {
        throw CloudConnectionException('Gagal memperbarui produk di Cloud: ${e.message}', statusCode: e.response?.statusCode);
      }
    }

    // LAN / USB
    try {
      final response = await _posDio.put('/api/v1/products/${product.id}', data: product.toJson());
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw LanConnectionException('Gagal memperbarui produk di Host LAN: ${e.message}');
    }
  }

  Future<bool> deleteProduct(String id) async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.deleteProduct(id);
    }

    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      try {
        final response = await _posDio.delete('/api/v1/products/$id');
        final tenantDb = await _getTenantDbOrNull();
        if (tenantDb != null) {
          await _localDb.deleteProduct(id, customDb: tenantDb);
        }
        return response.statusCode == 200;
      } on DioException catch (e) {
        throw CloudConnectionException('Gagal menghapus produk di Cloud: ${e.message}', statusCode: e.response?.statusCode);
      }
    }

    // LAN / USB
    try {
      final response = await _posDio.delete('/api/v1/products/$id');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw LanConnectionException('Gagal menghapus produk di Host LAN: ${e.message}');
    }
  }

  Future<bool> voidTransaction(String invoiceNo) async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.voidTransaction(invoiceNo);
    }

    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      try {
        final response = await _posDio.post('/api/v1/transactions/void', data: {'invoice_no': invoiceNo});
        final tenantDb = await _getTenantDbOrNull();
        if (tenantDb != null) {
          await _localDb.voidTransaction(invoiceNo, customDb: tenantDb);
        }
        return response.statusCode == 200;
      } on DioException catch (e) {
        throw CloudConnectionException('Gagal membatalkan transaksi di Cloud.', statusCode: e.response?.statusCode);
      }
    }

    // LAN / USB
    try {
      final response = await _posDio.post('/api/v1/transactions/void', data: {'invoice_no': invoiceNo});
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw LanConnectionException('Gagal membatalkan transaksi di Host LAN.');
    }
  }

  // --- CHECKOUT ---
  Future<Transaction?> checkout({
    required List<Map<String, dynamic>> items,
    required String paymentType,
    String? customerId,
  }) async {
    // 1. Offline Mode -> Local SQLite atomic transaction
    if (ApiConstants.isOfflineMode) {
      return await _localDb.insertTransaction(
        items: items,
        paymentType: paymentType,
        customerId: customerId,
      );
    }

    // 2. Cloud Mode -> Post to Cloud POS, cache to tenant DB on success
    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      try {
        final response = await _posDio.post(
          '/api/v1/checkout',
          data: {
            'items': items,
            'payment_type': paymentType,
            if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
          },
        );
        if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
          final tx = Transaction.fromJson(response.data);
          final tenantDb = await _getTenantDbOrNull();
          if (tenantDb != null) {
            await _localDb.insertTransaction(
              items: items,
              paymentType: paymentType,
              customerId: customerId,
              customDb: tenantDb,
            );
          }
          return tx;
        }
      } on DioException catch (e) {
        throw CloudConnectionException(
          'Transaksi Cloud Gagal: Server Cloud tidak merespon (${e.response?.statusCode ?? 'Offline'}). Transaksi TIDAK dicatat agar tidak terjadi inkonsistensi stok.',
          statusCode: e.response?.statusCode,
        );
      }
      throw CloudConnectionException('Transaksi Cloud gagal diproses.');
    }

    // 3. LAN Mode -> Post to Host PC
    try {
      final response = await _posDio.post(
        '/api/v1/checkout',
        data: {
          'items': items,
          'payment_type': paymentType,
          if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        return Transaction.fromJson(response.data);
      }
    } on DioException catch (e) {
      throw LanConnectionException(
        'Host LAN Terputus: Transaksi kasir gagal dikirim ke Host PC (${e.message}).',
        statusCode: e.response?.statusCode,
      );
    }
    throw LanConnectionException('Transaksi gagal dikirim ke Host LAN.');
  }

  // --- TRANSACTIONS ---
  Future<List<Transaction>> getTransactions() async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getTransactions();
    }

    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      try {
        final response = await _posDio.get('/api/v1/transactions');
        if (response.statusCode == 200 && response.data is List) {
          return (response.data as List).map((t) => Transaction.fromJson(t)).toList();
        }
      } on DioException catch (e) {
        final tenantDb = await _getTenantDbOrNull();
        if (tenantDb != null) {
          final cached = await _localDb.getTransactions(customDb: tenantDb);
          if (cached.isNotEmpty) return cached;
        }
        throw CloudConnectionException('Gagal memuat riwayat transaksi Cloud.', statusCode: e.response?.statusCode);
      }
      return [];
    }

    // LAN / USB
    try {
      final response = await _posDio.get('/api/v1/transactions');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((t) => Transaction.fromJson(t)).toList();
      }
    } on DioException catch (e) {
      throw LanConnectionException('Gagal memuat riwayat transaksi dari Host LAN.', statusCode: e.response?.statusCode);
    }
    return [];
  }

  // --- ANALYTICS ---
  Future<AnalyticsSummary> getAnalyticsSummary({String timeRange = 'SEMUA'}) async {
    if (ApiConstants.isOfflineMode) {
      return await _localDb.getAnalyticsSummary(timeRange: timeRange);
    }

    if (ApiConstants.currentMode == ConnectionMode.cloud) {
      try {
        final response = await _posDio.get(
          '/api/v1/analytics/summary',
          queryParameters: {'time_range': timeRange},
        );
        if (response.statusCode == 200 && response.data != null) {
          return AnalyticsSummary.fromJson(response.data);
        }
      } on DioException catch (e) {
        final tenantDb = await _getTenantDbOrNull();
        if (tenantDb != null) {
          return await _localDb.getAnalyticsSummary(timeRange: timeRange, customDb: tenantDb);
        }
        throw CloudConnectionException('Gagal memuat analitik Cloud.', statusCode: e.response?.statusCode);
      }
      return AnalyticsSummary(
        totalRevenue: 0,
        totalOrders: 0,
        averageOrderValue: 0,
        paymentMethods: [],
        dailySales: [],
      );
    }

    // LAN / USB
    try {
      final response = await _posDio.get(
        '/api/v1/analytics/summary',
        queryParameters: {'time_range': timeRange},
      );
      if (response.statusCode == 200 && response.data != null) {
        return AnalyticsSummary.fromJson(response.data);
      }
    } on DioException catch (e) {
      throw LanConnectionException('Gagal memuat analitik dari Host LAN.');
    }
    return AnalyticsSummary(
      totalRevenue: 0,
      totalOrders: 0,
      averageOrderValue: 0,
      paymentMethods: [],
      dailySales: [],
    );
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
      // In Cloud/LAN mode, do NOT silently fall back to offline database
      return [];
    }
    return [];
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
      return [];
    }
    return [];
  }

  Future<bool> sendAiPromo({required String clusterLabel, required String message}) async {
    if (ApiConstants.isOfflineMode) {
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
