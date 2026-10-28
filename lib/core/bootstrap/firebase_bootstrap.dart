import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:bookswaphub/core/config/app_config.dart';
import 'package:bookswaphub/data/services/push_service.dart';
import 'package:bookswaphub/firebase_options.dart';

class BootstrapResult {
  final bool ok;
  final String? error;
  const BootstrapResult.ok() : ok = true, error = null;
  const BootstrapResult.failed(this.error) : ok = false;
}

class FirebaseBootstrap {
  /// Starts Firebase (and Stripe in TEST mode). Returns a clear error instead of crashing
  /// when the project has not been configured yet.
  static Future<BootstrapResult> initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      return BootstrapResult.failed(
        'Firebase is not configured yet.\n\nRun `flutterfire configure` in the project folder '
        '(see docs/FIREBASE_SETUP.md).\n\nDetails: $e',
      );
    }

    if (AppConfig.useEmulators) {
      final host = AppConfig.emulatorHost;
      await fb.FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    }

    // App Check: stops other apps/scripts from abusing your backend. Needs console setup (docs).
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    } catch (e) {
      debugPrint('App Check not activated: $e');
    }

    if (PushService.supported) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    await _initStripeTestOnly();
    return const BootstrapResult.ok();
  }

  /// Stripe is started only with a pk_test_ key. A live-looking key disables payments entirely.
  static Future<void> _initStripeTestOnly() async {
    if (AppConfig.paymentsDisabledReason != null) {
      debugPrint('Payments disabled: ${AppConfig.paymentsDisabledReason}');
      return;
    }
    if (kIsWeb) return; // flutter_stripe web needs extra setup; payments are mobile-only here
    try {
      Stripe.publishableKey = AppConfig.stripePublishableKey;
      await Stripe.instance.applySettings();
    } catch (e) {
      debugPrint('Stripe init failed: $e');
    }
  }
}
