import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:bookswaphub/data/repositories/user_repository.dart';

/// Must be a top-level function. Background/terminated messages are shown by the OS
/// (they carry a `notification` payload), so there is nothing to do here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push notifications (FCM). Works on Android/iOS only; web/desktop need extra setup (see docs).
class PushService {
  final UserRepository _users;
  PushService(this._users);

  String? _uid;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// [onForeground] shows an in-app banner; [onOpen] navigates when a notification is tapped.
  Future<void> start(
    String uid, {
    required void Function(String title, String body, String route) onForeground,
    required void Function(String route) onOpen,
  }) async {
    if (!supported) return;
    _uid = uid;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    _token = await messaging.getToken();
    if (_token != null) await _users.saveDeviceToken(uid, _token!, defaultTargetPlatform.name);

    await _refreshSub?.cancel();
    _refreshSub = messaging.onTokenRefresh.listen((t) async {
      final u = _uid;
      if (u == null) return;
      _token = t;
      await _users.saveDeviceToken(u, t, defaultTargetPlatform.name);
    });

    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null) onForeground(n.title ?? '', n.body ?? '', (m.data['route'] ?? '/notifications').toString());
    });

    await _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((m) {
      onOpen((m.data['route'] ?? '/notifications').toString());
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) onOpen((initial.data['route'] ?? '/notifications').toString());
  }

  /// Call BEFORE signing out so this device stops receiving the old user's notifications.
  Future<void> stop() async {
    final uid = _uid;
    final token = _token;
    _uid = null;
    await _refreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    if (uid != null && token != null) {
      try {
        await _users.removeDeviceToken(uid, token);
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    _token = null;
  }
}
