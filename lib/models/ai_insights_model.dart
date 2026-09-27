class StockoutPrediction {
  final String productId;
  final String name;
  final int currentStock;
  final double dailyBurnRate;
  final int daysUntilStockout;

  StockoutPrediction({
    required this.productId,
    required this.name,
    required this.currentStock,
    required this.dailyBurnRate,
    required this.daysUntilStockout,
  });

  factory StockoutPrediction.fromJson(Map<String, dynamic> json) {
    return StockoutPrediction(
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      currentStock: (json['current_stock'] is num) ? (json['current_stock'] as num).toInt() : 0,
      dailyBurnRate: (json['daily_burn_rate'] is num) ? (json['daily_burn_rate'] as num).toDouble() : 0.0,
      daysUntilStockout: (json['days_until_stockout'] is num) ? (json['days_until_stockout'] as num).toInt() : 0,
    );
  }
}

class CustomerCluster {
  final String customerId;
  final String clusterLabel; // "Loyal", "Beresiko Churn", "Reguler"
  final int frequencyCount;
  final double monetaryValue;

  CustomerCluster({
    required this.customerId,
    required this.clusterLabel,
    required this.frequencyCount,
    required this.monetaryValue,
  });

  factory CustomerCluster.fromJson(Map<String, dynamic> json) {
    return CustomerCluster(
      customerId: json['customer_id']?.toString() ?? '',
      clusterLabel: json['cluster_label']?.toString() ?? 'Reguler',
      frequencyCount: (json['frequency_count'] is num) ? (json['frequency_count'] as num).toInt() : 0,
      monetaryValue: (json['monetary_value'] is num) ? (json['monetary_value'] as num).toDouble() : 0.0,
    );
  }
}
