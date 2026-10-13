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
      price: (json['price'] is num)
          ? (json['price'] as num).toInt()
          : int.tryParse(json['price']?.toString() ?? '0') ?? 0,
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toInt()
          : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      subtotal: (json['subtotal'] is num)
          ? (json['subtotal'] as num).toInt()
          : int.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
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
    final items = <TransactionItem>[];
    for (var i in rawItems) {
      if (i is Map) {
        items.add(TransactionItem.fromJson(Map<String, dynamic>.from(i)));
      }
    }

    return Transaction(
      id: json['id']?.toString() ?? '',
      invoiceNo: json['invoice_no']?.toString() ?? 'INV-${DateTime.now().millisecondsSinceEpoch}',
      customerId: json['customer_id']?.toString() ?? '',
      totalAmount: (json['total_amount'] is num)
          ? (json['total_amount'] as num).toInt()
          : int.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      paymentType: json['payment_type']?.toString() ?? 'TUNAI',
      status: json['status']?.toString() ?? 'COMPLETED',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_no': invoiceNo,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'payment_type': paymentType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
