import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/product_model.dart';
import 'image_storage_service.dart';
import 'local_db_service.dart';
import 'store_profile_service.dart';

/// Embedded HTTP Server for Windows Desktop (and local host machines).
/// Serves REST API endpoints on port 8080 reading & writing to local SQLite (`larisai_offline.db`),
/// allowing mobile cashier phones on the same Wi-Fi LAN to share the exact same database
/// without requiring Go or Docker installation!
class LocalHostServerService {
  static final LocalHostServerService instance = LocalHostServerService._init();
  LocalHostServerService._init();

  HttpServer? _server;
  int _port = 8080;
  String _localIp = '127.0.0.1';

  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);
  final ValueNotifier<String> serverUrlNotifier = ValueNotifier<String>('');

  /// Stream to notify Desktop UI whenever a mobile phone performs checkout or product updates
  final StreamController<String> _eventController = StreamController<String>.broadcast();
  Stream<String> get onDataChanged => _eventController.stream;

  int get port => _port;
  String get localIp => _localIp;
  String get serverUrl => 'http://$_localIp:$_port';

  /// Start embedded HTTP server
  Future<bool> startServer({int port = 8080}) async {
    if (_server != null) return true;
    _port = port;

    try {
      _localIp = await _findLocalIp();

      // Bind to all IPv4 interfaces (0.0.0.0) so LAN phones can connect
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(_handleRequest);

      isRunning.value = true;
      serverUrlNotifier.value = 'http://$_localIp:$_port';
      debugPrint('🚀 [LocalHostServer] Running at http://$_localIp:$_port');
      return true;
    } catch (e) {
      debugPrint('❌ [LocalHostServer] Failed to bind on port $_port: $e');
      // If port 8080 is taken, attempt fallback port 8088
      if (_port == 8080) {
        return await startServer(port: 8088);
      }
      isRunning.value = false;
      serverUrlNotifier.value = '';
      return false;
    }
  }

  /// Stop embedded HTTP server
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    isRunning.value = false;
    serverUrlNotifier.value = '';
    debugPrint('🛑 [LocalHostServer] Stopped');
  }

  /// Auto-detect Wi-Fi / LAN IP address
  Future<String> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Prioritize Wi-Fi or Ethernet interfaces with typical private IPv4 ranges
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            return ip;
          }
        }
      }

      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  /// Request Dispatcher
  Future<void> _handleRequest(HttpRequest request) async {
    final res = request.response;

    // Set CORS Headers for Mobile & Web clients
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.headers.set('Access-Control-Allow-Headers', 'Origin, Content-Type, Authorization, Accept');
    res.headers.set('Content-Type', 'application/json; charset=utf-8');

    // Handle Pre-flight OPTIONS
    if (request.method == 'OPTIONS') {
      res.statusCode = HttpStatus.ok;
      await res.close();
      return;
    }

    final path = request.uri.path;
    final method = request.method;
    final query = request.uri.queryParameters;

    try {
      // 1. Health Probe
      if (path == '/api/v1/health' || path == '/health') {
        final profile = StoreProfileService.instance.profile;
        _jsonResponse(res, HttpStatus.ok, {
          'status': 'ok',
          'mode': 'lan_host',
          'engine': 'sqlite_embedded',
          'store_name': profile.storeName,
          'host_ip': _localIp,
          'port': _port,
          'time': DateTime.now().toIso8601String(),
        });
        return;
      }

      // 2. Auth Login (Dummy pass-through for multi-device clients)
      if (path == '/api/v1/auth/login' && method == 'POST') {
        final profile = StoreProfileService.instance.profile;
        _jsonResponse(res, HttpStatus.ok, {
          'token': 'lan-host-token-${DateTime.now().millisecondsSinceEpoch}',
          'user': {
            'email': 'kasir@lan.local',
            'store_id': 'lan-store-01',
            'store_name': profile.storeName,
          },
        });
        return;
      }

      // 3. Products
      if (path == '/api/v1/products') {
        if (method == 'GET') {
          final search = query['search'];
          final products = await LocalDbService.instance.getProducts(search: search);
          _jsonResponse(res, HttpStatus.ok, products.map((p) => p.toJson()).toList());
          return;
        } else if (method == 'POST') {
          final body = await _readJsonBody(request);
          if (body != null) {
            final product = Product.fromJson(body);
            final saved = await LocalDbService.instance.insertProduct(product);
            _eventController.add('product_created');
            _jsonResponse(res, HttpStatus.created, saved.toJson());
            return;
          }
        }
      }

      // 3b. Product Barcode Scan: /api/v1/products/scan/:barcode
      if (path.startsWith('/api/v1/products/scan/') && method == 'GET') {
        final barcode = path.replaceFirst('/api/v1/products/scan/', '');
        final product = await LocalDbService.instance.getProductByBarcode(barcode);
        if (product != null) {
          _jsonResponse(res, HttpStatus.ok, product.toJson());
        } else {
          _jsonResponse(res, HttpStatus.notFound, {'error': 'Product not found'});
        }
        return;
      }

      // 3c. Product Update & Delete: /api/v1/products/:id
      if (path.startsWith('/api/v1/products/') && !path.contains('/scan/')) {
        final id = path.replaceFirst('/api/v1/products/', '');
        if (method == 'PUT') {
          final body = await _readJsonBody(request);
          if (body != null) {
            final product = Product.fromJson(body);
            final ok = await LocalDbService.instance.updateProduct(product);
            _eventController.add('product_updated');
            _jsonResponse(res, HttpStatus.ok, {'success': ok});
            return;
          }
        } else if (method == 'DELETE') {
          final ok = await LocalDbService.instance.deleteProduct(id);
          _eventController.add('product_deleted');
          _jsonResponse(res, HttpStatus.ok, {'success': ok});
          return;
        }
      }

      // 3b. Serve Images: GET /api/v1/images/:filename
      if (path.startsWith('/api/v1/images/') && method == 'GET') {
        final filename = path.replaceFirst('/api/v1/images/', '');
        final file = await ImageStorageService.instance.getLocalImageFile(filename);
        if (file != null && await file.exists()) {
          final ext = p.extension(file.path).toLowerCase();
          String contentType = 'image/jpeg';
          if (ext == '.png') contentType = 'image/png';
          if (ext == '.webp') contentType = 'image/webp';
          if (ext == '.gif') contentType = 'image/gif';

          res.headers.set('Content-Type', contentType);
          res.headers.set('Cache-Control', 'public, max-age=86400');
          res.statusCode = HttpStatus.ok;
          await res.addStream(file.openRead());
          await res.close();
          return;
        } else {
          _jsonResponse(res, HttpStatus.notFound, {'error': 'Image file not found'});
          return;
        }
      }

      // 4. Checkout: POST /api/v1/checkout
      if (path == '/api/v1/checkout' && method == 'POST') {
        final body = await _readJsonBody(request);
        if (body != null && body['items'] is List) {
          final items = (body['items'] as List).cast<Map<String, dynamic>>();
          final paymentType = body['payment_type']?.toString() ?? 'TUNAI';
          final customerId = body['customer_id']?.toString();

          final tx = await LocalDbService.instance.insertTransaction(
            items: items,
            paymentType: paymentType,
            customerId: customerId,
          );

          // Broadcast event so Desktop UI updates stock and revenue immediately!
          _eventController.add('checkout_completed');
          _jsonResponse(res, HttpStatus.created, tx.toJson());
          return;
        }
        _jsonResponse(res, HttpStatus.badRequest, {'error': 'Invalid checkout payload'});
        return;
      }

      // 5. Transactions: GET /api/v1/transactions
      if (path == '/api/v1/transactions' && method == 'GET') {
        final transactions = await LocalDbService.instance.getTransactions();
        _jsonResponse(res, HttpStatus.ok, transactions.map((t) => t.toJson()).toList());
        return;
      }

      // 5b. Void Transaction: POST /api/v1/transactions/void
      if (path == '/api/v1/transactions/void' && method == 'POST') {
        final body = await _readJsonBody(request);
        final invoiceNo = body?['invoice_no']?.toString();
        if (invoiceNo != null) {
          final ok = await LocalDbService.instance.voidTransaction(invoiceNo);
          _eventController.add('transaction_voided');
          _jsonResponse(res, HttpStatus.ok, {'success': ok});
          return;
        }
      }

      // 6. Analytics Summary: GET /api/v1/analytics/summary
      if (path == '/api/v1/analytics/summary' && method == 'GET') {
        final timeRange = query['time_range'] ?? 'SEMUA';
        final summary = await LocalDbService.instance.getAnalyticsSummary(timeRange: timeRange);
        _jsonResponse(res, HttpStatus.ok, summary.toJson());
        return;
      }

      // 404 Route Not Found
      _jsonResponse(res, HttpStatus.notFound, {
        'error': 'Endpoint not found on LAN Host Server',
        'path': path,
        'method': method,
      });
    } catch (e, stack) {
      debugPrint('❌ [LocalHostServer] Exception on $path: $e\n$stack');
      _jsonResponse(res, HttpStatus.internalServerError, {'error': e.toString()});
    }
  }

  /// Helper to parse JSON body
  Future<Map<String, dynamic>?> _readJsonBody(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      if (content.isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Helper to send JSON response
  void _jsonResponse(HttpResponse res, int statusCode, dynamic data) {
    res.statusCode = statusCode;
    res.write(jsonEncode(data));
    res.close();
  }
}
