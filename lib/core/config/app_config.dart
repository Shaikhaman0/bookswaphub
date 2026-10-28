/// Build-time configuration. Pass values with --dart-define (never hard-code secrets):
///   flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx
///   flutter run --dart-define=USE_EMULATORS=true
/// Only PUBLIC values belong here. Secret keys live in Cloud Functions secrets.
class AppConfig {
  static const String stripePublishableKey =
      String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  static const bool useEmulators = bool.fromEnvironment('USE_EMULATORS');

  /// Android emulator reaches your PC at 10.0.2.2; for iOS simulator/desktop/web use 127.0.0.1.
  static const String emulatorHost =
      String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

  /// Must start with pk_test_ and must not look like a live key.
  static bool isTestPublishableKey(String key) =>
      key.startsWith('pk_test_') && !key.toLowerCase().contains('_live_');

  static bool get hasLiveLookingStripeKey =>
      stripePublishableKey.toLowerCase().contains('_live_') ||
      stripePublishableKey.startsWith('pk_live');

  static bool get stripeConfigured => isTestPublishableKey(stripePublishableKey);

  /// Human-readable reason payments are off (null when payments can be used).
  static String? get paymentsDisabledReason {
    if (hasLiveLookingStripeKey) {
      return 'A LIVE Stripe key was detected. This app only accepts test keys (pk_test_...).';
    }
    if (stripePublishableKey.isEmpty) {
      return 'Stripe test key not set. Run with --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...';
    }
    if (!stripeConfigured) {
      return 'STRIPE_PUBLISHABLE_KEY must start with pk_test_.';
    }
    return null;
  }
}
