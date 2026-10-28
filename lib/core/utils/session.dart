import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/main.dart' show pushServiceProvider;

/// Logs out safely: stop push notifications for this device FIRST, then sign out.
/// The router redirect then sends the user to /login automatically.
Future<void> signOutUser(WidgetRef ref) async {
  try {
    await ref.read(pushServiceProvider).stop();
  } catch (_) {
    // Never block logout because of push cleanup.
  }
  await ref.read(authRepositoryProvider).signOut();
}
