import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:larisai_mobile/services/license_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('🛡️ Cryptographic License Guard & Fail-Closed Tests', () {
    test('1. Default state is 14-day trial when unactivated', () async {
      final info = await LicenseService.instance.getLicenseInfo();
      expect(info.type, LicenseType.trial);
      expect(info.isValid, true);
      expect(info.daysRemaining, greaterThan(0));
    });

    test('2. Rejects random string even if length >= 16', () async {
      expect(
        () async => await LicenseService.instance.activateLicense('RANDOM-STRING-1234567890'),
        throwsException,
      );
    });

    test('3. Rejects fake key with LRS-LIFE- prefix but invalid format or checksum', () async {
      expect(
        () async => await LicenseService.instance.activateLicense('LRS-LIFE-FAKE-KEY-1234'),
        throwsException,
      );

      expect(
        () async => await LicenseService.instance.activateLicense('LRS-LIFE-12345678-87654321'),
        throwsException,
      );
    });

    test('4. Rejects key belonging to another machine ID', () async {
      await LicenseService.instance.getMachineId();

      // Create a key for a different machine ID
      final otherMid = 'DIFFER99';
      final otherChecksum = LicenseService.generateLicenseChecksum(otherMid, 'lifetime');
      final keyForOtherMachine = 'LRS-LIFE-$otherMid-$otherChecksum';

      expect(
        () async => await LicenseService.instance.activateLicense(keyForOtherMachine),
        throwsA(predicate((e) => e.toString().contains('terikat untuk perangkat lain'))),
      );
    });

    test('5. Successfully activates valid hardware-bound cryptographic key', () async {
      final machineId = await LicenseService.instance.getMachineId();
      final currentCleanMid = LicenseService.sanitizeMachineId(machineId);
      final validChecksum = LicenseService.generateLicenseChecksum(currentCleanMid, 'lifetime');
      final validKey = 'LRS-LIFE-$currentCleanMid-$validChecksum';

      final success = await LicenseService.instance.activateLicense(validKey);
      expect(success, true);

      final info = await LicenseService.instance.getLicenseInfo();
      expect(info.type, LicenseType.lifetime);
      expect(info.isValid, true);
      expect(info.licenseKey, validKey);
    });

    test('6. Tampering with stored key invalidates license on next check', () async {
      final machineId = await LicenseService.instance.getMachineId();
      final currentCleanMid = LicenseService.sanitizeMachineId(machineId);
      final validChecksum = LicenseService.generateLicenseChecksum(currentCleanMid, 'lifetime');
      final validKey = 'LRS-LIFE-$currentCleanMid-$validChecksum';

      await LicenseService.instance.activateLicense(validKey);

      // Simulate malicious tampering of SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('larisai_license_key', 'LRS-LIFE-HACKED00-99999999');

      final info = await LicenseService.instance.getLicenseInfo();
      expect(info.isValid, false);
    });

    test('7. Machine ID is deterministic and identical across simulated uninstall (wiped SharedPreferences)', () async {
      // 1. First installation generates machineId A
      final machineId1 = await LicenseService.instance.getMachineId();
      expect(machineId1, startsWith('LRS-'));

      // 2. Simulate complete uninstall (wipe all SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. Reinstall app: getMachineId() MUST regenerate the EXACT SAME Machine ID!
      final machineId2 = await LicenseService.instance.getMachineId();
      expect(machineId2, equals(machineId1), reason: 'Machine ID must be deterministic across uninstalls');

      // 4. Verify serial key generated for machineId1 activates successfully on machineId2
      final cleanMid = LicenseService.sanitizeMachineId(machineId2);
      final validChecksum = LicenseService.generateLicenseChecksum(cleanMid, 'lifetime');
      final validKey = 'LRS-LIFE-$cleanMid-$validChecksum';

      final success = await LicenseService.instance.activateLicense(validKey);
      expect(success, true);
    });
  });
}
