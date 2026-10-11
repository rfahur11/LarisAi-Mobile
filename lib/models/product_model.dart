class Product {
  final String id;
  final String barcode;
  final String name;
  final String category;
  final int price;
  final int stock;
  final bool isArchived;
  final String imagePath;

  Product({
    required this.id,
    required this.barcode,
    required this.name,
    this.category = 'Umum',
    required this.price,
    required this.stock,
    this.isArchived = false,
    this.imagePath = '',
  });

  /// Returns the explicit image path if set, or auto-resolves to bundled starter assets for known products
  String get displayImagePath {
    final clean = imagePath.trim();
    if (clean.isNotEmpty) return clean;
    final lower = name.toLowerCase();
    if (barcode == '8992772111029' || lower.contains('aqua')) return 'aqua_600ml.jpg';
    if (barcode == '8992753112234' || lower.contains('indomie')) return 'indomie_goreng.jpg';
    if (barcode == '8999999002133' || lower.contains('teh botol')) return 'teh_botol.jpg';
    if (barcode == '8998866100124' || lower.contains('kapal api') || lower.contains('kopi')) return 'kopi_kapal_api.jpg';
    return '';
  }

  bool get hasDisplayImage => displayImagePath.isNotEmpty;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Umum',
      price: (json['price'] is num) ? (json['price'] as num).toInt() : 0,
      stock: (json['stock'] is num) ? (json['stock'] as num).toInt() : 0,
      isArchived: json['is_archived'] == true || json['is_archived'] == 1,
      imagePath: json['image_path']?.toString() ?? json['image_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'barcode': barcode,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'is_archived': isArchived,
      'image_path': imagePath,
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
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      isArchived: isArchived ?? this.isArchived,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
