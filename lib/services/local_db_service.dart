import 'dart:async' show Completer;
import 'dart:io' show Platform, Directory;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:path/path.dart' as p;
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../models/ai_insights_model.dart';
import '../models/analytics_model.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._init();
  static Database? _database;
  static Completer<Database>? _dbOpenCompleter;

  LocalDbService._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    if (_dbOpenCompleter != null) return _dbOpenCompleter!.future;

    _dbOpenCompleter = Completer<Database>();
    try {
      _database = await _initDB('larisai_offline.db');
      _dbOpenCompleter!.complete(_database!);
      return _database!;
    } catch (e, stack) {
      _dbOpenCompleter!.completeError(e, stack);
      _dbOpenCompleter = null;
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    String dbDirectoryPath;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // On Windows Desktop, store database inside AppData/Roaming to guarantee write permissions
      final appSupportDir = await getApplicationSupportDirectory();
      dbDirectoryPath = appSupportDir.path;
      final dir = Directory(dbDirectoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      dbDirectoryPath = await getDatabasesPath();
    }

    final path = p.join(dbDirectoryPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL
          )
        ''');
        try {
          await db.execute("ALTER TABLE transactions ADD COLUMN status TEXT NOT NULL DEFAULT 'COMPLETED'");
        } catch (_) {}
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 0. Customers Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // 1. Products Table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        barcode TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price INTEGER NOT NULL,
        stock INTEGER NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        invoice_no TEXT NOT NULL,
        customer_id TEXT NOT NULL DEFAULT '',
        total_amount INTEGER NOT NULL,
        payment_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        created_at TEXT NOT NULL
      )
    ''');

    // 3. Transaction Items Table
    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // Seed starter products
    await _seedStarterProducts(db);
  }

  Future<void> _seedStarterProducts(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    final starterProducts = [
      {'id': '1', 'barcode': '8992753112234', 'name': 'Indomie Goreng Original', 'category': 'Makanan', 'price': 3500, 'stock': 48, 'is_archived': 0, 'created_at': now, 'updated_at': now},
      {'id': '2', 'barcode': '8998866100124', 'name': 'Kopi Kapal Api Special Mix', 'category': 'Minuman', 'price': 2000, 'stock': 75, 'is_archived': 0, 'created_at': now, 'updated_at': now},
      {'id': '3', 'barcode': '8999999002133', 'name': 'Teh Botol Sosro 450ml', 'category': 'Minuman', 'price': 5000, 'stock': 18, 'is_archived': 0, 'created_at': now, 'updated_at': now},
      {'id': '4', 'barcode': '8991002103321', 'name': 'Minyak Goreng Sania 2L', 'category': 'Sembako', 'price': 36000, 'stock': 4, 'is_archived': 0, 'created_at': now, 'updated_at': now},
      {'id': '5', 'barcode': '8993175538012', 'name': 'Beras Ramos Super 5kg', 'category': 'Sembako', 'price': 74000, 'stock': 6, 'is_archived': 0, 'created_at': now, 'updated_at': now},
      {'id': '6', 'barcode': '8996001301014', 'name': 'Gula Pasir Gulaku 1kg', 'category': 'Sembako', 'price': 18500, 'stock': 8, 'is_archived': 0, 'created_at': now, 'updated_at': now},
      {'id': '7', 'barcode': '8992772111029', 'name': 'Aqua Air Mineral 600ml', 'category': 'Minuman', 'price': 3500, 'stock': 32, 'is_archived': 0, 'created_at': now, 'updated_at': now},
      {'id': '8', 'barcode': '8991001223019', 'name': 'Susu Ultra Milk Cokelat 250ml', 'category': 'Minuman', 'price': 6500, 'stock': 15, 'is_archived': 0, 'created_at': now, 'updated_at': now},
    ];

    final batch = db.batch();
    for (var p in starterProducts) {
      batch.insert('products', p);
    }
    await batch.commit(noResult: true);
  }

  // --- RESET & PURGE OPERATIONS ---
  Future<int> clearTransactionsOnly() async {
    final db = await database;
    int deletedCount = 0;
    await db.transaction((txn) async {
      await txn.delete('transaction_items');
      deletedCount = await txn.delete('transactions');
    });
    return deletedCount;
  }

  Future<void> factoryResetDatabase({bool reseedStarterProducts = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transaction_items');
      await txn.delete('transactions');
      await txn.delete('products');
      if (reseedStarterProducts) {
        await _seedStarterProducts(txn);
      }
    });
  }

  // --- PRODUCT OPERATIONS ---
  Future<List<Product>> getProducts({String? search}) async {
    final db = await database;
    String whereClause = 'is_archived = 0';
    List<dynamic> whereArgs = [];

    if (search != null && search.trim().isNotEmpty) {
      whereClause += ' AND (name LIKE ? OR barcode LIKE ?)';
      whereArgs.add('%${search.trim()}%');
      whereArgs.add('%${search.trim()}%');
    }

    final maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return maps.map((m) => Product.fromJson(m)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'barcode = ? AND is_archived = 0',
      whereArgs: [barcode],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Product.fromJson(maps.first);
    }
    return null;
  }

  Future<Product> insertProduct(Product product) async {
    final db = await database;
    final id = product.id.isNotEmpty ? product.id : 'loc_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    final newProduct = product.copyWith(id: id);
    await db.insert('products', {
      'id': newProduct.id,
      'barcode': newProduct.barcode,
      'name': newProduct.name,
      'category': newProduct.category,
      'price': newProduct.price,
      'stock': newProduct.stock,
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return newProduct;
  }

  Future<bool> updateProduct(Product product) async {
    final db = await database;
    final count = await db.update(
      'products',
      {
        'barcode': product.barcode,
        'name': product.name,
        'category': product.category,
        'price': product.price,
        'stock': product.stock,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [product.id],
    );
    return count > 0;
  }

  Future<bool> deleteProduct(String id) async {
    final db = await database;
    final count = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<bool> reduceStock(String productId, int quantity) async {
    final db = await database;
    final res = await db.rawUpdate(
      'UPDATE products SET stock = MAX(0, stock - ?), updated_at = ? WHERE id = ?',
      [quantity, DateTime.now().toIso8601String(), productId],
    );
    return res > 0;
  }

  // --- CHECKOUT & TRANSACTION OPERATIONS ---
  Future<Transaction> insertTransaction({
    required List<Map<String, dynamic>> items,
    required String paymentType,
    String? customerId,
  }) async {
    final db = await database;
    final txId = 'tx_loc_${DateTime.now().millisecondsSinceEpoch}';
    final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final now = DateTime.now();

    int totalAmount = 0;
    List<TransactionItem> txItems = [];

    // Calculate total amount & build item objects
    for (var i in items) {
      final pId = i['product_id']?.toString() ?? '';
      final qty = (i['quantity'] is num) ? (i['quantity'] as num).toInt() : 1;
      
      // Fetch product name and price
      final prodMap = await db.query('products', where: 'id = ?', whereArgs: [pId], limit: 1);
      final name = prodMap.isNotEmpty ? prodMap.first['name'].toString() : 'Produk Kasir';
      final price = prodMap.isNotEmpty ? (prodMap.first['price'] as int) : 10000;
      final subtotal = price * qty;
      totalAmount += subtotal;

      txItems.add(TransactionItem(
        productId: pId,
        name: name,
        price: price,
        quantity: qty,
        subtotal: subtotal,
      ));
    }

    // Execute in transaction
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': txId,
        'invoice_no': invoiceNo,
        'customer_id': customerId ?? '',
        'total_amount': totalAmount,
        'payment_type': paymentType,
        'status': 'COMPLETED',
        'created_at': now.toIso8601String(),
      });

      for (var item in txItems) {
        await txn.insert('transaction_items', {
          'transaction_id': txId,
          'product_id': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'subtotal': item.subtotal,
        });

        // Reduce stock
        await txn.rawUpdate(
          'UPDATE products SET stock = MAX(0, stock - ?), updated_at = ? WHERE id = ?',
          [item.quantity, now.toIso8601String(), item.productId],
        );
      }
    });

    return Transaction(
      id: txId,
      invoiceNo: invoiceNo,
      customerId: customerId ?? '',
      totalAmount: totalAmount,
      paymentType: paymentType,
      status: 'COMPLETED',
      createdAt: now,
      items: txItems,
    );
  }

  Future<List<Transaction>> getTransactions({int limit = 50}) async {
    final db = await database;
    final txMaps = await db.query('transactions', orderBy: 'created_at DESC', limit: limit);
    
    List<Transaction> result = [];
    for (var tx in txMaps) {
      final txId = tx['id'] as String;
      final itemMaps = await db.query('transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
      final items = itemMaps.map((i) => TransactionItem.fromJson(i)).toList();

      result.add(Transaction(
        id: txId,
        invoiceNo: tx['invoice_no'] as String,
        customerId: tx['customer_id'] as String? ?? '',
        totalAmount: tx['total_amount'] as int,
        paymentType: tx['payment_type'] as String,
        status: tx['status'] as String? ?? 'COMPLETED',
        createdAt: DateTime.tryParse(tx['created_at'].toString()) ?? DateTime.now(),
        items: items,
      ));
    }
    return result;
  }

  Future<bool> voidTransaction(String invoiceNo) async {
    final db = await database;
    final txMaps = await db.query('transactions', where: 'invoice_no = ?', whereArgs: [invoiceNo]);
    if (txMaps.isEmpty) return false;

    final tx = txMaps.first;
    if ((tx['status'] as String? ?? '').toUpperCase() == 'VOID') {
      return false; // Already voided
    }

    final txId = tx['id'] as String;

    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'status': 'VOID'},
        where: 'id = ?',
        whereArgs: [txId],
      );

      final items = await txn.query('transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
      for (var item in items) {
        final pId = item['product_id'] as String;
        final qty = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : 0;
        if (qty > 0) {
          await txn.rawUpdate(
            'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?',
            [qty, DateTime.now().toIso8601String(), pId],
          );
        }
      }
    });

    return true;
  }

  // --- ANALYTICS ENGINE (Offline SQLite Queries) ---
  Future<AnalyticsSummary> getAnalyticsSummary({String timeRange = 'SEMUA'}) async {
    final db = await database;

    String whereClause = "WHERE (status IS NULL OR status != 'VOID')";
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final monthStr = now.toIso8601String().substring(0, 7);
    final sevenDaysAgoStr = now.subtract(const Duration(days: 6)).toIso8601String().substring(0, 10);

    if (timeRange == 'HARI_INI') {
      whereClause += " AND substr(created_at, 1, 10) = '$todayStr'";
    } else if (timeRange == '7_HARI') {
      whereClause += " AND substr(created_at, 1, 10) >= '$sevenDaysAgoStr'";
    } else if (timeRange == 'BULAN_INI') {
      whereClause += " AND substr(created_at, 1, 7) = '$monthStr'";
    }
    
    // Total Revenue & Orders
    final totalResult = await db.rawQuery('SELECT SUM(total_amount) as rev, COUNT(*) as count FROM transactions $whereClause');
    final totalRevenue = (totalResult.first['rev'] is num) ? (totalResult.first['rev'] as num).toInt() : 0;
    final totalOrders = (totalResult.first['count'] is num) ? (totalResult.first['count'] as num).toInt() : 0;
    final avgOrder = totalOrders > 0 ? (totalRevenue / totalOrders).round() : 0;

    // Payment Breakdown
    final payResult = await db.rawQuery('''
      SELECT payment_type, SUM(total_amount) as sum_amt, COUNT(*) as count 
      FROM transactions 
      $whereClause
      GROUP BY payment_type
    ''');

    List<PaymentBreakdown> payments = [];
    for (var r in payResult) {
      final amt = (r['sum_amt'] is num) ? (r['sum_amt'] as num).toInt() : 0;
      final count = (r['count'] is num) ? (r['count'] as num).toInt() : 0;
      final percentage = totalRevenue > 0 ? (amt / totalRevenue) * 100 : 0.0;
      payments.add(PaymentBreakdown(
        paymentType: r['payment_type']?.toString() ?? 'TUNAI',
        totalAmount: amt,
        count: count,
        percentage: double.parse(percentage.toStringAsFixed(1)),
      ));
    }

    if (payments.isEmpty && totalOrders > 0) {
      payments = [
        PaymentBreakdown(paymentType: 'TUNAI', totalAmount: totalRevenue, count: totalOrders, percentage: 100.0),
      ];
    }

    // Daily Sales (Most recent 7 days in chronological order)
    final dailyResult = await db.rawQuery('''
      SELECT day, sum_amt, count FROM (
        SELECT substr(created_at, 1, 10) as day, SUM(total_amount) as sum_amt, COUNT(*) as count
        FROM transactions
        WHERE (status IS NULL OR status != 'VOID')
        GROUP BY substr(created_at, 1, 10)
        ORDER BY day DESC
        LIMIT 7
      ) ORDER BY day ASC
    ''');

    List<DailySale> dailySales = dailyResult.map((d) {
      return DailySale(
        date: d['day']?.toString() ?? '',
        totalAmount: (d['sum_amt'] is num) ? (d['sum_amt'] as num).toInt() : 0,
        orderCount: (d['count'] is num) ? (d['count'] as num).toInt() : 0,
      );
    }).toList();

    return AnalyticsSummary(
      totalRevenue: totalRevenue,
      totalOrders: totalOrders,
      averageOrderValue: avgOrder,
      paymentMethods: payments,
      dailySales: dailySales,
    );
  }

  // --- LOCAL AI RADAR & RFM ENGINE (Offline Heuristics) ---
  Future<List<StockoutPrediction>> getAiStockoutPredictions() async {
    final db = await database;
    // Find products with low stock (<= 15)
    final maps = await db.query(
      'products',
      where: 'is_archived = 0 AND stock <= 15',
      orderBy: 'stock ASC',
      limit: 10,
    );

    List<StockoutPrediction> predictions = [];
    for (var m in maps) {
      final stock = (m['stock'] is num) ? (m['stock'] as num).toInt() : 0;
      final burnRate = 2.5; // Average local daily burn rate estimate
      final days = burnRate > 0 ? (stock / burnRate).floor() : 999;

      predictions.add(StockoutPrediction(
        productId: m['id'].toString(),
        name: m['name'].toString(),
        currentStock: stock,
        dailyBurnRate: burnRate,
        daysUntilStockout: days.clamp(0, 999),
      ));
    }
    return predictions;
  }

  // --- CUSTOMER MANAGEMENT & CRM ---

  Future<void> saveCustomer({required String name, required String phone}) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanName.isEmpty) return;

    final db = await database;
    final id = cleanPhone.isNotEmpty ? cleanPhone : cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    await db.insert(
      'customers',
      {
        'id': id,
        'name': cleanName,
        'phone': cleanPhone,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> updateCustomer({required String id, required String name, required String phone}) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanName.isEmpty) return false;

    final db = await database;
    final count = await db.update(
      'customers',
      {
        'name': cleanName,
        'phone': cleanPhone,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<bool> deleteCustomer(String id) async {
    final db = await database;
    final count = await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  Future<List<CustomerRecord>> getCustomerHistory() async {
    final db = await database;
    final Map<String, CustomerRecord> map = {};

    try {
      // 1. Fetch from customers table
      final customerRows = await db.query('customers', orderBy: 'created_at DESC');
      for (var r in customerRows) {
        final name = r['name'] as String? ?? '';
        final phone = r['phone'] as String? ?? '';
        final id = r['id'] as String? ?? '';
        if (name.isNotEmpty) {
          map[name.toLowerCase()] = CustomerRecord(id: id, name: name, phone: phone);
        }
      }
    } catch (_) {}

    // 2. Fetch distinct customers from transactions table (backward compatibility)
    try {
      final txRows = await db.rawQuery('''
        SELECT customer_id, COUNT(*) as freq
        FROM transactions
        WHERE customer_id != '' 
          AND customer_id NOT LIKE 'Transfer%' 
          AND customer_id NOT LIKE 'E-Wallet%' 
          AND customer_id NOT LIKE 'Kartu Debit%'
        GROUP BY customer_id
        ORDER BY freq DESC, created_at DESC
        LIMIT 100
      ''');

      for (var r in txRows) {
        final rawId = r['customer_id'] as String? ?? '';
        final freq = (r['freq'] as num?)?.toInt() ?? 1;
        if (rawId.isEmpty) continue;

        // Check if rawId has format "Name (Phone)"
        final match = RegExp(r'^(.*?)\s*[\(\-•]\s*(08\d{8,13}|\+?62\d{8,13})\)?$').firstMatch(rawId);
        String name = rawId;
        String phone = '';
        if (match != null) {
          name = match.group(1)?.trim() ?? rawId;
          phone = match.group(2)?.trim() ?? '';
        }

        final key = name.toLowerCase();
        if (map.containsKey(key)) {
          map[key] = CustomerRecord(
            id: map[key]!.id,
            name: map[key]!.name,
            phone: map[key]!.phone.isNotEmpty ? map[key]!.phone : phone,
            totalOrders: freq,
          );
        } else {
          map[key] = CustomerRecord(
            id: rawId,
            name: name,
            phone: phone,
            totalOrders: freq,
          );
        }
      }
    } catch (_) {}

    final list = map.values.toList();
    list.sort((a, b) => b.totalOrders.compareTo(a.totalOrders));
    return list;
  }

  Future<List<CustomerCluster>> getAiCustomerClusters() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT customer_id, SUM(total_amount) as total_spent, COUNT(*) as freq
      FROM transactions
      WHERE customer_id != ''
        AND customer_id NOT LIKE 'Transfer%' 
        AND customer_id NOT LIKE 'E-Wallet%' 
        AND customer_id NOT LIKE 'Kartu Debit%'
      GROUP BY customer_id
    ''');

    if (rows.isEmpty) {
      return [];
    }

    return rows.map((r) {
      final total = (r['total_spent'] is num) ? (r['total_spent'] as num).toInt() : 0;
      final freq = (r['freq'] is num) ? (r['freq'] as num).toInt() : 1;
      
      String label = 'Reguler';
      if (total >= 500000 && freq >= 3) {
        label = 'Loyal';
      } else if (freq <= 1 && total <= 50000) {
        label = 'Beresiko Churn';
      }

      return CustomerCluster(
        customerId: r['customer_id'].toString(),
        clusterLabel: label,
        frequencyCount: freq,
        monetaryValue: total.toDouble(),
      );
    }).toList();
  }
}

class CustomerRecord {
  final String id;
  final String name;
  final String phone;
  final int totalOrders;

  const CustomerRecord({
    required this.id,
    required this.name,
    required this.phone,
    this.totalOrders = 0,
  });

  String get displayName => phone.isNotEmpty ? '$name ($phone)' : name;
}

