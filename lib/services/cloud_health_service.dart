import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';

enum CloudHealthStatus { fast, stable, slow, disconnected }

class CloudHealthService extends ChangeNotifier {
  static final CloudHealthService instance = CloudHealthService._internal();
  CloudHealthService._internal();

  CloudHealthStatus _status = CloudHealthStatus.disconnected;
  int? _latencyMs;
  DateTime? _lastChecked;
  bool _isChecking = false;
  Timer? _timer;

  CloudHealthStatus get status => _status;
  int? get latencyMs => _latencyMs;
  DateTime? get lastChecked => _lastChecked;
  bool get isChecking => _isChecking;

  String get statusLabel {
    switch (_status) {
      case CloudHealthStatus.fast:
        return '🟢 Cepat (${_latencyMs}ms)';
      case CloudHealthStatus.stable:
        return '🟡 Stabil (${_latencyMs}ms)';
      case CloudHealthStatus.slow:
        return '🔴 Lambat (${_latencyMs}ms)';
      case CloudHealthStatus.disconnected:
        return '⚪ Terputus';
    }
  }

  Color get statusColor {
    switch (_status) {
      case CloudHealthStatus.fast:
        return Colors.green;
      case CloudHealthStatus.stable:
        return Colors.amber.shade700;
      case CloudHealthStatus.slow:
        return Colors.redAccent;
      case CloudHealthStatus.disconnected:
        return Colors.grey;
    }
  }

  Future<int?> checkHealth({String? url}) async {
    if (_isChecking) return _latencyMs;
    _isChecking = true;
    notifyListeners();

    final targetUrl = url ??
        (ApiConstants.currentMode == ConnectionMode.cloud
            ? ApiConstants.cloudPosBaseUrl
            : ApiConstants.posBaseUrl);

    if (targetUrl.startsWith('local://')) {
      _latencyMs = 1;
      _status = CloudHealthStatus.fast;
      _lastChecked = DateTime.now();
      _isChecking = false;
      notifyListeners();
      return _latencyMs;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final dio = Dio(BaseOptions(
        baseUrl: targetUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));

      // Attempt health probe endpoint or base URL
      final response = await dio.get('/api/v1/health').catchError((_) async {
        return await dio.get('/health').catchError((_) async {
          return await dio.get('/');
        });
      });

      stopwatch.stop();
      if (response.statusCode != null && response.statusCode! < 500) {
        _latencyMs = stopwatch.elapsedMilliseconds;
        if (_latencyMs! < 150) {
          _status = CloudHealthStatus.fast;
        } else if (_latencyMs! <= 400) {
          _status = CloudHealthStatus.stable;
        } else {
          _status = CloudHealthStatus.slow;
        }
      } else {
        _status = CloudHealthStatus.disconnected;
        _latencyMs = null;
      }
    } catch (_) {
      stopwatch.stop();
      _status = CloudHealthStatus.disconnected;
      _latencyMs = null;
    } finally {
      _lastChecked = DateTime.now();
      _isChecking = false;
      notifyListeners();
    }

    return _latencyMs;
  }

  void startPeriodicChecks({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    checkHealth();
    _timer = Timer.periodic(interval, (_) => checkHealth());
  }

  void stopPeriodicChecks() {
    _timer?.cancel();
    _timer = null;
  }
}
