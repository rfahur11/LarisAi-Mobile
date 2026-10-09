class TransactionItem {
  final String productId;
  final String name;
  final int price;
  final int quantity;
  final int subtotal;

  TransactionItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] is num) ? (json['price'] as num).toInt() : 0,
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1,
      subtotal: (json['subtotal'] is num) ? (json['subtotal'] as num).toInt() : 0,
    );
  }
}

class Transaction {
  final String id;
  final String invoiceNo;
  final String customerId;
  final int totalAmount;
  final String paymentType;
  final String status;
  final DateTime createdAt;
  final List<TransactionItem> items;

  bool get isVoid => status.toUpperCase() == 'VOID';

  Transaction({
    required this.id,
    required this.invoiceNo,
    this.customerId = '',
    required this.totalAmount,
    required this.paymentType,
    this.status = 'COMPLETED',
    required this.createdAt,
    required this.items,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    List<TransactionItem> items = rawItems
        .map((i) => TransactionItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return Transaction(
      id: json['id']?.toString() ?? '',
      invoiceNo: json['invoice_no']?.toString() ?? 'INV-${DateTime.now().millisecondsSinceEpoch}',
      customerId: json['customer_id']?.toString() ?? '',
      totalAmount: (json['total_amount'] is num) ? (json['total_amount'] as num).toInt() : 0,
      paymentType: json['payment_type']?.toString() ?? 'TUNAI',
      status: json['status']?.toString() ?? 'COMPLETED',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: items,
    );
  }
}
