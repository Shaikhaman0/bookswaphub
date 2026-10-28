import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswaphub/core/bootstrap/firebase_bootstrap.dart';
import 'package:bookswaphub/core/routing/app_router.dart';
import 'package:bookswaphub/core/theme/app_theme.dart';
import 'package:bookswaphub/core/theme/theme_provider.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/data/services/push_service.dart';
import 'package:bookswaphub/screens/setup_required_screen.dart';

// ...


final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final result = await FirebaseBootstrap.initialize();
  if (!result.ok) {
    runApp(SetupRequiredApp(message: result.error ?? 'Unknown setup error'));
    return;
  }
  runApp(const ProviderScope(child: BookSwapHubApp()));
}

class BookSwapHubApp extends ConsumerWidget {
  const BookSwapHubApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    // Start/stop push notifications when someone signs in/out.
    ref.listen<String?>(currentUidProvider, (previous, next) {
      final push = ref.read(pushServiceProvider);
      if (next != null) {
        push.start(
          next,
          onForeground: (title, body, route) {
            messengerKey.currentState?.showSnackBar(SnackBar(
              content: Text(title.isEmpty ? body : '$title — $body'),
              action: SnackBarAction(label: 'Open', onPressed: () => router.go(route)),
            ));
          },
          onOpen: (route) => router.go(route),
        );
      }
    });

    return MaterialApp.router(
      title: 'Book Swap Hub',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref.watch(userRepositoryProvider)));
