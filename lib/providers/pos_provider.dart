import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/transaction_model.dart';
import '../models/analytics_model.dart';
import '../services/api_service.dart';

class PosProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  final List<CartItem> _cart = [];
  bool _isLoading = false;
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  AnalyticsSummary? _summary;

  List<Product> get products {
    if (_selectedCategory == 'Semua') {
      return _products;
    }
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  List<CartItem> get cart => _cart;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  AnalyticsSummary? get summary => _summary;

  int get totalRevenueToday => _summary?.totalRevenue ?? 0;
  int get totalOrdersToday => _summary?.totalOrders ?? 0;
  int get lowStockCount => _products.where((p) => p.stock > 0 && p.stock <= 5).length;
  int get outOfStockCount => _products.where((p) => p.stock == 0).length;

  int get totalAmount => _cart.fold(0, (sum, item) => sum + item.subtotal);
  int get totalItems => _cart.fold(0, (sum, item) => sum + item.quantity);

  List<String> get categories {
    final set = <String>{'Semua'};
    for (var p in _products) {
      if (p.category.isNotEmpty) set.add(p.category);
    }
    return set.toList();
  }

  PosProvider() {
    loadProducts();
    loadSummary();
  }

  Future<void> loadSummary() async {
    try {
      _summary = await _apiService.getAnalyticsSummary();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadProducts({String? search}) async {
    _isLoading = true;
    notifyListeners();
    _searchQuery = search ?? '';
    _products = await _apiService.getProducts(search: search);
    _isLoading = false;
    notifyListeners();
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
    }
    return transaction;
  }

  Future<bool> addNewProduct(Product product) async {
    final created = await _apiService.createProduct(product);
    _products.insert(0, created);
    notifyListeners();
    return true;
  }
}
