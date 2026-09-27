import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../models/ai_insights_model.dart';
import '../models/analytics_model.dart';

class ApiService {
  late Dio _posDio;
  late Dio _aiDio;

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
    _posDio.options.baseUrl = ApiConstants.posBaseUrl;
    _aiDio.options.baseUrl = ApiConstants.aiBaseUrl;
  }

  // --- PRODUCTS ---
  Future<List<Product>> getProducts({String? search}) async {
    try {
      final response = await _posDio.get(
        '/api/v1/products',
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((p) => Product.fromJson(p)).toList();
      }
    } catch (_) {
      // Fallback local mockup for initial testing if backend not running
      return _getMockProducts(search);
    }
    return _getMockProducts(search);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final response = await _posDio.get('/api/v1/products/scan/$barcode');
      if (response.statusCode == 200 && response.data != null) {
        return Product.fromJson(response.data);
      }
    } catch (_) {
      final mocks = _getMockProducts(null);
      try {
        return mocks.firstWhere((p) => p.barcode == barcode);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<Product> createProduct(Product product) async {
    try {
      final response = await _posDio.post(
        '/api/v1/products',
        data: product.toJson(),
      );
      if (response.statusCode == 201 && response.data != null) {
        return Product.fromJson(response.data);
      }
    } catch (_) {
      // Return simulated created product
      return product.copyWith(id: 'prod_${DateTime.now().millisecondsSinceEpoch}');
    }
    return product;
  }

  // --- CHECKOUT ---
  Future<Transaction?> checkout({
    required List<Map<String, dynamic>> items,
    required String paymentType,
    String? customerId,
  }) async {
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
        return Transaction.fromJson(response.data);
      }
    } catch (_) {
      // Offline fallback transaction response
      return Transaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        invoiceNo: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        totalAmount: items.fold<int>(0, (sum, item) => sum + ((item['quantity'] as int) * 15000)),
        paymentType: paymentType,
        createdAt: DateTime.now(),
        items: items.map((i) => TransactionItem(
          productId: i['product_id'] ?? '',
          name: 'Produk Kasir',
          price: 15000,
          quantity: i['quantity'] ?? 1,
          subtotal: (i['quantity'] ?? 1) * 15000,
        )).toList(),
      );
    }
    return null;
  }

  // --- TRANSACTIONS ---
  Future<List<Transaction>> getTransactions() async {
    try {
      final response = await _posDio.get('/api/v1/transactions');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((t) => Transaction.fromJson(t)).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- ANALYTICS ---
  Future<AnalyticsSummary> getAnalyticsSummary() async {
    try {
      final response = await _posDio.get('/api/v1/analytics/summary');
      if (response.statusCode == 200 && response.data != null) {
        return AnalyticsSummary.fromJson(response.data);
      }
    } catch (_) {}
    return AnalyticsSummary(
      totalRevenue: 2850000,
      totalOrders: 42,
      averageOrderValue: 67800,
      paymentMethods: [
        PaymentBreakdown(paymentType: 'QRIS', totalAmount: 1450000, count: 22, percentage: 50.8),
        PaymentBreakdown(paymentType: 'TUNAI', totalAmount: 1100000, count: 16, percentage: 38.6),
        PaymentBreakdown(paymentType: 'DEBIT', totalAmount: 300000, count: 4, percentage: 10.6),
      ],
      dailySales: [
        DailySale(date: '2026-09-23', totalAmount: 450000, orderCount: 7),
        DailySale(date: '2026-09-24', totalAmount: 620000, orderCount: 10),
        DailySale(date: '2026-09-25', totalAmount: 510000, orderCount: 8),
        DailySale(date: '2026-09-26', totalAmount: 780000, orderCount: 12),
        DailySale(date: '2026-09-27', totalAmount: 490000, orderCount: 5),
      ],
    );
  }

  // --- AI ENGINE (Stockout & Clustering) ---
  Future<List<StockoutPrediction>> getAiStockoutPredictions() async {
    try {
      final response = await _aiDio.get('/api/v1/ai/forecasting/stockouts');
      if (response.statusCode == 200 && response.data != null) {
        var raw = response.data['predictions'] as List<dynamic>? ?? [];
        return raw.map((p) => StockoutPrediction.fromJson(p)).toList();
      }
    } catch (_) {}
    // Simulated realistic predictions
    return [
      StockoutPrediction(
        productId: '1',
        name: 'Minyak Goreng Sania 2L',
        currentStock: 4,
        dailyBurnRate: 2.5,
        daysUntilStockout: 1,
      ),
      StockoutPrediction(
        productId: '2',
        name: 'Beras Ramos 5kg',
        currentStock: 6,
        dailyBurnRate: 3.0,
        daysUntilStockout: 2,
      ),
      StockoutPrediction(
        productId: '3',
        name: 'Gula Pasir Gulaku 1kg',
        currentStock: 8,
        dailyBurnRate: 2.0,
        daysUntilStockout: 4,
      ),
    ];
  }

  Future<List<CustomerCluster>> getAiCustomerClusters() async {
    try {
      final response = await _aiDio.get('/api/v1/ai/clustering/customers');
      if (response.statusCode == 200 && response.data != null) {
        var raw = response.data['clusters'] as List<dynamic>? ?? [];
        return raw.map((c) => CustomerCluster.fromJson(c)).toList();
      }
    } catch (_) {}
    return [
      CustomerCluster(customerId: 'CUST-Budi', clusterLabel: 'Loyal', frequencyCount: 14, monetaryValue: 1350000),
      CustomerCluster(customerId: 'CUST-Siti', clusterLabel: 'Beresiko Churn', frequencyCount: 1, monetaryValue: 35000),
      CustomerCluster(customerId: 'CUST-Agus', clusterLabel: 'Loyal', frequencyCount: 9, monetaryValue: 840000),
      CustomerCluster(customerId: 'CUST-Rina', clusterLabel: 'Beresiko Churn', frequencyCount: 2, monetaryValue: 50000),
      CustomerCluster(customerId: 'CUST-Dewi', clusterLabel: 'Reguler', frequencyCount: 5, monetaryValue: 310000),
    ];
  }

  Future<bool> sendAiPromo({required String clusterLabel, required String message}) async {
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
      // Simulate success response for demo
      return true;
    }
  }

  // Helper mock products
  List<Product> _getMockProducts(String? search) {
    final list = [
      Product(id: '1', barcode: '8992753112234', name: 'Indomie Goreng Original', category: 'Makanan', price: 3500, stock: 48),
      Product(id: '2', barcode: '8998866100124', name: 'Kopi Kapal Api Special Mix', category: 'Minuman', price: 2000, stock: 75),
      Product(id: '3', barcode: '8999999002133', name: 'Teh Botol Sosro 450ml', category: 'Minuman', price: 5000, stock: 18),
      Product(id: '4', barcode: '8991002103321', name: 'Minyak Goreng Sania 2L', category: 'Sembako', price: 36000, stock: 4),
      Product(id: '5', barcode: '8993175538012', name: 'Beras Ramos Super 5kg', category: 'Sembako', price: 74000, stock: 6),
      Product(id: '6', barcode: '8996001301014', name: 'Gula Pasir Gulaku 1kg', category: 'Sembako', price: 18500, stock: 8),
      Product(id: '7', barcode: '8992772111029', name: 'Aqua Air Mineral 600ml', category: 'Minuman', price: 3500, stock: 32),
      Product(id: '8', barcode: '8991001223019', name: 'Susu Ultra Milk Cokelat 250ml', category: 'Minuman', price: 6500, stock: 15),
    ];

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return list.where((p) => p.name.toLowerCase().contains(q) || p.barcode.contains(q)).toList();
    }
    return list;
  }
}
