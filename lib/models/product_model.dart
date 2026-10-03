class Product {
  final String id;
  final String barcode;
  final String name;
  final String category;
  final int price;
  final int stock;
  final bool isArchived;

  Product({
    required this.id,
    required this.barcode,
    required this.name,
    this.category = 'Umum',
    required this.price,
    required this.stock,
    this.isArchived = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Umum',
      price: (json['price'] is num) ? (json['price'] as num).toInt() : 0,
      stock: (json['stock'] is num) ? (json['stock'] as num).toInt() : 0,
      isArchived: json['is_archived'] == true || json['is_archived'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
    };
  }

  Product copyWith({
    String? id,
    String? barcode,
    String? name,
    String? category,
    int? price,
    int? stock,
    bool? isArchived,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
