import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import 'auth_service.dart';
import 'local_host_server_service.dart';

enum CloudHealthStatus { fast, stable, slow, disconnected }

class CloudHealthService extends ChangeNotifier {
  static final CloudHealthService instance = CloudHealthService._internal();
  CloudHealthService._internal();

  CloudHealthStatus _status = CloudHealthStatus.fast;
  int? _latencyMs = 1;
  DateTime? _lastChecked;
  bool _isChecking = false;
  Timer? _timer;
  int _consecutiveFailures = 0;

  final StreamController<void> _reconnectedController = StreamController<void>.broadcast();
  Stream<void> get onReconnected => _reconnectedController.stream;

  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionChanged => _connectionStateController.stream;

  CloudHealthStatus get status => _status;
  int? get latencyMs => _latencyMs;
  DateTime? get lastChecked => _lastChecked;
  bool get isChecking => _isChecking;
  bool get isConnected => _status != CloudHealthStatus.disconnected;
  bool get isDisconnected => _status == CloudHealthStatus.disconnected;

  String get targetHostLabel {
    if (ApiConstants.currentMode == ConnectionMode.wifi) {
      return ApiConstants.posBaseUrl.replaceAll('http://', '').replaceAll('https://', '');
    } else if (ApiConstants.currentMode == ConnectionMode.cloud) {
      return 'Cloud SaaS';
    }
    return 'Lokal (SQLite)';
  }

  String get statusLabel {
    switch (_status) {
      case CloudHealthStatus.fast:
        return '🟢 Cepat (${_latencyMs ?? 1}ms)';
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
        return Colors.red.shade700;
    }
  }

  void markDisconnected() {
    if (_status != CloudHealthStatus.disconnected) {
      _status = CloudHealthStatus.disconnected;
      _latencyMs = null;
      _consecutiveFailures = 2;
      notifyListeners();
      _connectionStateController.add(false);
    }
  }

  void markConnected(int latency) {
    final wasDisconnected = _status == CloudHealthStatus.disconnected;
    _latencyMs = latency;
    _consecutiveFailures = 0;
    if (latency < 150) {
      _status = CloudHealthStatus.fast;
    } else if (latency <= 400) {
      _status = CloudHealthStatus.stable;
    } else {
      _status = CloudHealthStatus.slow;
    }
    notifyListeners();
    if (wasDisconnected) {
      _reconnectedController.add(null);
      _connectionStateController.add(true);
    }
  }

  Future<int?> checkHealth({String? url, bool forceFailImmediately = false}) async {
    // 1. If this device is hosting the server or in offline mode, it is always healthy
    if (LocalHostServerService.instance.isRunning.value || ApiConstants.isOfflineMode) {
      _latencyMs = 1;
      _status = CloudHealthStatus.fast;
      _consecutiveFailures = 0;
      _lastChecked = DateTime.now();
      notifyListeners();
      return 1;
    }

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
      _consecutiveFailures = 0;
      _lastChecked = DateTime.now();
      _isChecking = false;
      notifyListeners();
      return 1;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final effectiveToken = AuthService.instance.lanClusterToken.isNotEmpty
          ? AuthService.instance.lanClusterToken
          : 'laris-lan-sec-key';

      final dio = Dio(BaseOptions(
        baseUrl: targetUrl,
        connectTimeout: const Duration(milliseconds: 2500),
        receiveTimeout: const Duration(milliseconds: 2500),
        headers: {
          if (ApiConstants.currentMode == ConnectionMode.wifi || ApiConstants.currentMode == ConnectionMode.usb)
            'x-cluster-auth': effectiveToken,
          if (ApiConstants.currentMode == ConnectionMode.wifi || ApiConstants.currentMode == ConnectionMode.usb)
            'Authorization': 'Bearer $effectiveToken',
        },
      ));

      final response = await dio.get('/api/v1/health').catchError((_) async {
        return await dio.get('/health').catchError((_) async {
          return await dio.get('/');
        });
      });

      stopwatch.stop();
      if (response.statusCode != null && response.statusCode! < 500) {
        final wasDisconnected = _status == CloudHealthStatus.disconnected;
        _latencyMs = stopwatch.elapsedMilliseconds;
        _consecutiveFailures = 0;

        if (_latencyMs! < 150) {
          _status = CloudHealthStatus.fast;
        } else if (_latencyMs! <= 400) {
          _status = CloudHealthStatus.stable;
        } else {
          _status = CloudHealthStatus.slow;
        }

        if (wasDisconnected) {
          _reconnectedController.add(null);
          _connectionStateController.add(true);
        }
      } else {
        _handleFailure(forceFailImmediately);
      }
    } catch (_) {
      stopwatch.stop();
      _handleFailure(forceFailImmediately);
    } finally {
      _lastChecked = DateTime.now();
      _isChecking = false;
      notifyListeners();
    }

    return _latencyMs;
  }

  void _handleFailure(bool forceImmediately) {
    _consecutiveFailures++;
    if (_consecutiveFailures >= 2 || forceImmediately) {
      final wasConnected = _status != CloudHealthStatus.disconnected;
      _status = CloudHealthStatus.disconnected;
      _latencyMs = null;
      if (wasConnected) {
        _connectionStateController.add(false);
      }
    }
  }

  void startPeriodicChecks({Duration interval = const Duration(seconds: 5)}) {
    _timer?.cancel();
    if (ApiConstants.isOfflineMode || LocalHostServerService.instance.isRunning.value) {
      _status = CloudHealthStatus.fast;
      _latencyMs = 1;
      _consecutiveFailures = 0;
      notifyListeners();
      return;
    }
    checkHealth();
    _timer = Timer.periodic(interval, (_) => checkHealth());
  }

  void stopPeriodicChecks() {
    _timer?.cancel();
    _timer = null;
  }

  void syncWithMode() {
    if (ApiConstants.isOfflineMode || LocalHostServerService.instance.isRunning.value) {
      stopPeriodicChecks();
      _status = CloudHealthStatus.fast;
      _latencyMs = 1;
      _consecutiveFailures = 0;
      notifyListeners();
    } else {
      startPeriodicChecks(interval: const Duration(seconds: 5));
    }
  }
}
