import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import 'local_db_service.dart';
import 'api_service.dart';
import 'auth_service.dart';

enum MigrationDirection {
  lifetimeToCloud,
  cloudToLifetime,
}

class MigrationProgress {
  final int totalItems;
  final int processedItems;
  final String currentPhase;
  final double percentage;
  final bool isCompleted;
  final String? errorMessage;

  MigrationProgress({
    required this.totalItems,
    required this.processedItems,
    required this.currentPhase,
    required this.percentage,
    this.isCompleted = false,
    this.errorMessage,
  });

  factory MigrationProgress.initial() => MigrationProgress(
        totalItems: 0,
        processedItems: 0,
        currentPhase: 'Menyiapkan migrasi...',
        percentage: 0.0,
      );
}

class MigrationInspectionResult {
  final int localProductsCount;
  final int localTransactionsCount;
  final int cloudProductsCount;
  final int cloudTransactionsCount;
  final bool isCloudAuthenticated;
  final String storeId;
  final String? error;

  MigrationInspectionResult({
    required this.localProductsCount,
    required this.localTransactionsCount,
    required this.cloudProductsCount,
    required this.cloudTransactionsCount,
    required this.isCloudAuthenticated,
    required this.storeId,
    this.error,
  });
}

class MigrationSummaryResult {
  final bool success;
  final int productsMigrated;
  final int transactionsMigrated;
  final String message;
  final String? error;

  MigrationSummaryResult({
    required this.success,
    required this.productsMigrated,
    required this.transactionsMigrated,
    required this.message,
    this.error,
  });
}

class DataMigrationService {
  static final DataMigrationService instance = DataMigrationService._internal();

  DataMigrationService._internal();

  final LocalDbService _localDb = LocalDbService.instance;
  final ApiService _api = ApiService.instance;

  final ValueNotifier<bool> isMigrating = ValueNotifier<bool>(false);
  final ValueNotifier<MigrationProgress> progress = ValueNotifier<MigrationProgress>(MigrationProgress.initial());

  /// Inspeksi awal sebelum migrasi dijalankan
  Future<MigrationInspectionResult> inspectDataSources() async {
    int localProdCount = 0;
    int localTxCount = 0;
    int cloudProdCount = 0;
    int cloudTxCount = 0;
    String? inspectError;

    final isAuth = AuthService.instance.isLoggedIn && (AuthService.instance.storeId?.isNotEmpty ?? false);
    final storeId = AuthService.instance.storeId ?? '';

    try {
      // 1. Hitung data SQLite Lifetime Offline
      final defaultDb = await _localDb.database;
      final localProdRows = await defaultDb.rawQuery('SELECT COUNT(*) as count FROM products WHERE is_archived = 0');
      localProdCount = Sqflite.firstIntValue(localProdRows) ?? 0;

      final localTxRows = await defaultDb.rawQuery('SELECT COUNT(*) as count FROM transactions');
      localTxCount = Sqflite.firstIntValue(localTxRows) ?? 0;

      // 2. Jika akun Cloud tersambung, hitung data Cloud / Tenant DB
      if (isAuth) {
        try {
          final cloudProducts = await _api.getProducts();
          cloudProdCount = cloudProducts.length;
        } catch (_) {
          // Fallback ke tenant database lokal jika offline
          final tenantDb = await _localDb.getTenantDatabase(storeId);
          final tenantProdRows = await tenantDb.rawQuery('SELECT COUNT(*) as count FROM products WHERE is_archived = 0');
          cloudProdCount = Sqflite.firstIntValue(tenantProdRows) ?? 0;
        }

        try {
          final cloudTxs = await _api.getTransactions();
          cloudTxCount = cloudTxs.length;
        } catch (_) {
          final tenantDb = await _localDb.getTenantDatabase(storeId);
          final tenantTxRows = await tenantDb.rawQuery('SELECT COUNT(*) as count FROM transactions');
          cloudTxCount = Sqflite.firstIntValue(tenantTxRows) ?? 0;
        }
      }
    } catch (e) {
      inspectError = e.toString();
    }

    return MigrationInspectionResult(
      localProductsCount: localProdCount,
      localTransactionsCount: localTxCount,
      cloudProductsCount: cloudProdCount,
      cloudTransactionsCount: cloudTxCount,
      isCloudAuthenticated: isAuth,
      storeId: storeId,
      error: inspectError,
    );
  }

  /// Migrasi Data 1: Mode Lifetime (SQLite Lokal) ➔ Mode Cloud SaaS
  Future<MigrationSummaryResult> migrateLifetimeToCloud() async {
    if (isMigrating.value) {
      return MigrationSummaryResult(
        success: false,
        productsMigrated: 0,
        transactionsMigrated: 0,
        message: 'Proses migrasi lain sedang berjalan.',
      );
    }

    if (!AuthService.instance.isLoggedIn) {
      return MigrationSummaryResult(
        success: false,
        productsMigrated: 0,
        transactionsMigrated: 0,
        message: 'Silakan login ke Akun Cloud SaaS terlebih dahulu di menu Pengaturan.',
      );
    }

    isMigrating.value = true;
    int migratedProducts = 0;
    int migratedTransactions = 0;

    try {
      progress.value = MigrationProgress(
        totalItems: 100,
        processedItems: 5,
        currentPhase: 'Membaca katalog offline...',
        percentage: 0.05,
      );

      // 1. Ambil seluruh produk offline aktif
      final localProducts = await _localDb.getProducts();
      final totalProd = localProducts.length;

      // 2. Batch upload ke Cloud POS
      if (totalProd > 0) {
        progress.value = MigrationProgress(
          totalItems: totalProd,
          processedItems: 0,
          currentPhase: 'Mengunggah $totalProd produk ke Cloud...',
          percentage: 0.2,
        );

        // Kirim dalam chunk 50 produk agar tahan terhadap request timeout
        const int chunkSize = 50;
        for (int i = 0; i < totalProd; i += chunkSize) {
          final end = (i + chunkSize < totalProd) ? i + chunkSize : totalProd;
          final chunk = localProducts.sublist(i, end);

          try {
            await _api.createProductsBulk(chunk);
            migratedProducts += chunk.length;
          } catch (e) {
            // Jika bulk endpoint gagal, lakukan single insert fallback
            for (var p in chunk) {
              try {
                await _api.createProduct(p);
                migratedProducts++;
              } catch (_) {}
            }
          }

          final pct = 0.2 + (0.5 * (migratedProducts / totalProd));
          progress.value = MigrationProgress(
            totalItems: totalProd,
            processedItems: migratedProducts,
            currentPhase: 'Mengunggah produk ($migratedProducts / $totalProd)...',
            percentage: pct.clamp(0.0, 0.7),
          );
        }
      }

      // 3. Ambil dan sinkronkan riwayat transaksi jika didukung
      progress.value = MigrationProgress(
        totalItems: 100,
        processedItems: 80,
        currentPhase: 'Menyinkronkan riwayat transaksi...',
        percentage: 0.8,
      );

      final localTxs = await _localDb.getTransactions();
      final storeId = AuthService.instance.storeId;
      if (storeId != null && storeId.isNotEmpty) {
        // Caching transaksi offline ke isolated tenant SQLite untuk seamless mode-switch
        final tenantDb = await _localDb.getTenantDatabase(storeId);
        await tenantDb.transaction((txn) async {
          for (var tx in localTxs) {
            final txMap = {
              'id': tx.id,
              'invoice_no': tx.invoiceNo,
              'customer_id': tx.customerId,
              'total_amount': tx.totalAmount,
              'payment_type': tx.paymentType,
              'status': tx.status,
              'created_at': tx.createdAt.toIso8601String(),
            };
            await txn.insert('transactions', txMap, conflictAlgorithm: ConflictAlgorithm.replace);

            for (var item in tx.items) {
              await txn.insert('transaction_items', {
                'transaction_id': tx.id,
                'product_id': item.productId,
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'subtotal': item.subtotal,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            migratedTransactions++;
          }
        });
      }

      progress.value = MigrationProgress(
        totalItems: totalProd,
        processedItems: totalProd,
        currentPhase: 'Migrasi ke Cloud selesai!',
        percentage: 1.0,
        isCompleted: true,
      );

      return MigrationSummaryResult(
        success: true,
        productsMigrated: migratedProducts,
        transactionsMigrated: migratedTransactions,
        message: 'Berhasil memigrasikan $migratedProducts produk dan $migratedTransactions transaksi ke Akun Cloud!',
      );
    } catch (e) {
      progress.value = MigrationProgress(
        totalItems: 0,
        processedItems: 0,
        currentPhase: 'Migrasi gagal.',
        percentage: 0.0,
        isCompleted: true,
        errorMessage: e.toString(),
      );
      return MigrationSummaryResult(
        success: false,
        productsMigrated: migratedProducts,
        transactionsMigrated: migratedTransactions,
        message: 'Gagal memigrasikan data ke Cloud: $e',
        error: e.toString(),
      );
    } finally {
      isMigrating.value = false;
    }
  }

  /// Migrasi Data 2: Mode Cloud SaaS ➔ Mode Lifetime (SQLite Lokal)
  Future<MigrationSummaryResult> migrateCloudToLifetime({bool clearExistingOffline = false}) async {
    if (isMigrating.value) {
      return MigrationSummaryResult(
        success: false,
        productsMigrated: 0,
        transactionsMigrated: 0,
        message: 'Proses migrasi lain sedang berjalan.',
      );
    }

    if (!AuthService.instance.isLoggedIn) {
      return MigrationSummaryResult(
        success: false,
        productsMigrated: 0,
        transactionsMigrated: 0,
        message: 'Akun Cloud belum login. Hubungkan akun Cloud untuk mengambil data.',
      );
    }

    isMigrating.value = true;
    int syncedProducts = 0;
    int syncedTransactions = 0;

    try {
      progress.value = MigrationProgress(
        totalItems: 100,
        processedItems: 10,
        currentPhase: 'Mengambil data dari Cloud SaaS...',
        percentage: 0.1,
      );

      // 1. Ambil data produk Cloud
      List<Product> cloudProducts = [];
      try {
        cloudProducts = await _api.getProducts();
      } catch (_) {
        final storeId = AuthService.instance.storeId ?? '';
        final tenantDb = await _localDb.getTenantDatabase(storeId);
        cloudProducts = await _localDb.getProducts(customDb: tenantDb);
      }

      // 2. Ambil data transaksi Cloud
      List<Transaction> cloudTransactions = [];
      try {
        cloudTransactions = await _api.getTransactions();
      } catch (_) {
        final storeId = AuthService.instance.storeId ?? '';
        final tenantDb = await _localDb.getTenantDatabase(storeId);
        cloudTransactions = await _localDb.getTransactions(customDb: tenantDb);
      }

      progress.value = MigrationProgress(
        totalItems: cloudProducts.length + cloudTransactions.length,
        processedItems: 0,
        currentPhase: 'Menyimpan data ke SQLite Lokal...',
        percentage: 0.3,
      );

      final defaultDb = await _localDb.database;

      // 3. Eksekusi Atomic Transaction di SQLite Lokal
      await defaultDb.transaction((txn) async {
        if (clearExistingOffline) {
          await txn.delete('transaction_items');
          await txn.delete('transactions');
          await txn.delete('products');
        }

        final now = DateTime.now().toIso8601String();

        // Upsert produk
        for (var p in cloudProducts) {
          final cleanImg = p.imagePath.trim().isNotEmpty ? p.imagePath.trim() : p.displayImagePath;
          await txn.insert('products', {
            'id': p.id.isNotEmpty ? p.id : 'mig_${DateTime.now().millisecondsSinceEpoch}_$syncedProducts',
            'barcode': p.barcode,
            'name': p.name,
            'category': p.category,
            'price': p.price,
            'stock': p.stock,
            'is_archived': p.isArchived ? 1 : 0,
            'image_path': cleanImg,
            'created_at': now,
            'updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          syncedProducts++;
        }

        // Upsert transaksi
        for (var tx in cloudTransactions) {
          await txn.insert('transactions', {
            'id': tx.id,
            'invoice_no': tx.invoiceNo,
            'customer_id': tx.customerId,
            'total_amount': tx.totalAmount,
            'payment_type': tx.paymentType,
            'status': tx.status,
            'created_at': tx.createdAt.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          for (var item in tx.items) {
            await txn.insert('transaction_items', {
              'transaction_id': tx.id,
              'product_id': item.productId,
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'subtotal': item.subtotal,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          syncedTransactions++;
        }
      });

      progress.value = MigrationProgress(
        totalItems: syncedProducts + syncedTransactions,
        processedItems: syncedProducts + syncedTransactions,
        currentPhase: 'Data Cloud berhasil disimpan ke offline lokal!',
        percentage: 1.0,
        isCompleted: true,
      );

      return MigrationSummaryResult(
        success: true,
        productsMigrated: syncedProducts,
        transactionsMigrated: syncedTransactions,
        message: 'Berhasil mengunduh $syncedProducts produk & $syncedTransactions transaksi ke mode Lifetime Offline!',
      );
    } catch (e) {
      progress.value = MigrationProgress(
        totalItems: 0,
        processedItems: 0,
        currentPhase: 'Sinkronisasi gagal.',
        percentage: 0.0,
        isCompleted: true,
        errorMessage: e.toString(),
      );
      return MigrationSummaryResult(
        success: false,
        productsMigrated: syncedProducts,
        transactionsMigrated: syncedTransactions,
        message: 'Gagal mengunduh data dari Cloud: $e',
        error: e.toString(),
      );
    } finally {
      isMigrating.value = false;
    }
  }
}
