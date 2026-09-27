class PaymentBreakdown {
  final String paymentType;
  final int totalAmount;
  final int count;
  final double percentage;

  PaymentBreakdown({
    required this.paymentType,
    required this.totalAmount,
    required this.count,
    required this.percentage,
  });

  factory PaymentBreakdown.fromJson(Map<String, dynamic> json) {
    return PaymentBreakdown(
      paymentType: json['payment_type']?.toString() ?? '',
      totalAmount: (json['total_amount'] is num) ? (json['total_amount'] as num).toInt() : 0,
      count: (json['count'] is num) ? (json['count'] as num).toInt() : 0,
      percentage: (json['percentage'] is num) ? (json['percentage'] as num).toDouble() : 0.0,
    );
  }
}

class DailySale {
  final String date;
  final int totalAmount;
  final int orderCount;

  DailySale({
    required this.date,
    required this.totalAmount,
    required this.orderCount,
  });

  factory DailySale.fromJson(Map<String, dynamic> json) {
    return DailySale(
      date: json['date']?.toString() ?? '',
      totalAmount: (json['total_amount'] is num) ? (json['total_amount'] as num).toInt() : 0,
      orderCount: (json['order_count'] is num) ? (json['order_count'] as num).toInt() : 0,
    );
  }
}

class AnalyticsSummary {
  final int totalRevenue;
  final int totalOrders;
  final int averageOrderValue;
  final List<PaymentBreakdown> paymentMethods;
  final List<DailySale> dailySales;

  AnalyticsSummary({
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.paymentMethods,
    required this.dailySales,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    var rawPayments = json['payment_methods'] as List<dynamic>? ?? [];
    var rawDaily = json['daily_sales'] as List<dynamic>? ?? [];

    return AnalyticsSummary(
      totalRevenue: (json['total_revenue'] is num) ? (json['total_revenue'] as num).toInt() : 0,
      totalOrders: (json['total_orders'] is num) ? (json['total_orders'] as num).toInt() : 0,
      averageOrderValue: (json['average_order_value'] is num) ? (json['average_order_value'] as num).toInt() : 0,
      paymentMethods: rawPayments.map((p) => PaymentBreakdown.fromJson(p as Map<String, dynamic>)).toList(),
      dailySales: rawDaily.map((d) => DailySale.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }
}
