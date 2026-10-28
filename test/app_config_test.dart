import 'package:flutter_test/flutter_test.dart';
import 'package:bookswaphub/core/config/app_config.dart';

void main() {
  test('only pk_test_ keys are accepted', () {
    expect(AppConfig.isTestPublishableKey('pk_test_abc123'), isTrue);
    expect(AppConfig.isTestPublishableKey('pk_live_abc123'), isFalse);
    expect(AppConfig.isTestPublishableKey(''), isFalse);
    expect(AppConfig.isTestPublishableKey('sk_test_abc'), isFalse);
  });

  test('keys containing _live_ are rejected even with a test prefix', () {
    expect(AppConfig.isTestPublishableKey('pk_test_live_abc'), isFalse);
  });

  test('payments are disabled by default (no key defined at build time)', () {
    // Tests run without --dart-define, so the key is empty.
    expect(AppConfig.paymentsDisabledReason, isNotNull);
    expect(AppConfig.stripeConfigured, isFalse);
  });
}
