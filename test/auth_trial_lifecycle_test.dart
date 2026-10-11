import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:larisai_mobile/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService & Free Trial Lifecycle Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial unauthenticated state defaults to trial without token', () async {
      final auth = AuthService.instance;
      await auth.init();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.planTier, 'trial');
    });

    test('Subscription badge text accurately reflects trial, active, and expired states', () async {
      final auth = AuthService.instance;
      SharedPreferences.setMockInitialValues({
        'larisai_jwt_token': 'dummy_jwt_token_123',
        'larisai_store_id': 'STORE_TEST_01',
        'larisai_store_name': 'Toko Berkah Uji',
        'larisai_auth_email': 'owner@berkah.com',
        'larisai_subscription_status': 'trial',
        'larisai_trial_ends_at': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      });

      await auth.init();
      expect(auth.isLoggedIn, isTrue);
      expect(auth.storeName, 'Toko Berkah Uji');
      expect(auth.isTrialActive, isTrue);
      expect(auth.remainingDays, greaterThanOrEqualTo(13));
      expect(auth.subscriptionBadgeText.contains('Free Trial'), isTrue);
    });

    test('Logout clears all tokens and resets subscription state', () async {
      final auth = AuthService.instance;
      SharedPreferences.setMockInitialValues({
        'larisai_jwt_token': 'dummy_jwt_token_123',
        'larisai_store_id': 'STORE_TEST_01',
        'larisai_store_name': 'Toko Berkah Uji',
        'larisai_auth_email': 'owner@berkah.com',
      });

      await auth.init();
      expect(auth.isLoggedIn, isTrue);

      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.token, isNull);
      expect(auth.storeId, isNull);
    });
  });
}
