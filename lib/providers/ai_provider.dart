import 'package:flutter/material.dart';
import '../models/ai_insights_model.dart';
import '../services/api_service.dart';

class AiProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<StockoutPrediction> _stockouts = [];
  List<CustomerCluster> _clusters = [];
  bool _isLoading = false;
  String? _lastPromoStatus;

  List<StockoutPrediction> get stockouts => _stockouts;
  List<CustomerCluster> get clusters => _clusters;
  bool get isLoading => _isLoading;
  String? get lastPromoStatus => _lastPromoStatus;

  List<CustomerCluster> get loyalCustomers =>
      _clusters.where((c) => c.clusterLabel.toLowerCase().contains('loyal')).toList();

  List<CustomerCluster> get churnRiskCustomers =>
      _clusters.where((c) => c.clusterLabel.toLowerCase().contains('churn')).toList();

  AiProvider() {
    loadAiData();
  }

  Future<void> loadAiData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getAiStockoutPredictions(),
        _apiService.getAiCustomerClusters(),
      ]);

      _stockouts = results[0] as List<StockoutPrediction>;
      _clusters = results[1] as List<CustomerCluster>;
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> sendPromoBlast({
    required String clusterLabel,
    required String message,
  }) async {
    final success = await _apiService.sendAiPromo(
      clusterLabel: clusterLabel,
      message: message,
    );
    _lastPromoStatus = success
        ? 'Promo berhasil dijadwalkan ke pelanggan segmen $clusterLabel via WhatsApp!'
        : 'Gagal mengirim promo.';
    notifyListeners();
    return success;
  }
}
