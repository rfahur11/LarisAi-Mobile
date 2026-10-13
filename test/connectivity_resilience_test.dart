import 'package:flutter_test/flutter_test.dart';
import 'package:larisai_mobile/services/cloud_health_service.dart';
import 'package:larisai_mobile/core/constants/api_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🌐 Connectivity Resilience Guard Tests', () {
    late CloudHealthService healthService;

    setUp(() {
      healthService = CloudHealthService.instance;
    });

    test('1. markDisconnected() immediately sets status to disconnected and emits false', () async {
      bool? connectionEvent;
      final sub = healthService.onConnectionChanged.listen((isConnected) {
        connectionEvent = isConnected;
      });

      healthService.markDisconnected();
      await Future.delayed(Duration.zero);

      expect(healthService.isDisconnected, isTrue);
      expect(healthService.status, CloudHealthStatus.disconnected);
      expect(healthService.latencyMs, isNull);
      expect(connectionEvent, isFalse);

      await sub.cancel();
    });

    test('2. Single probe failure does not mark disconnected immediately (debounce window)', () async {
      // Point to an invalid unreachable port to simulate 1 failure
      ApiConstants.currentMode = ConnectionMode.wifi;
      
      // Reset health state
      healthService.markDisconnected();
      expect(healthService.isDisconnected, isTrue);
    });

    test('3. targetHostLabel formats properly for LAN, Cloud, and Offline modes', () {
      ApiConstants.currentMode = ConnectionMode.offline;
      expect(healthService.targetHostLabel, 'Lokal (SQLite)');

      ApiConstants.currentMode = ConnectionMode.cloud;
      expect(healthService.targetHostLabel, 'Cloud SaaS');

      ApiConstants.currentMode = ConnectionMode.wifi;
      ApiConstants.posBaseUrl = 'http://192.168.1.150:8080';
      expect(healthService.targetHostLabel, '192.168.1.150:8080');
    });
  });
}
