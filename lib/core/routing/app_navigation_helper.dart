import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Centralized navigation helper for managing back navigation, route history,
/// dialog dismissal, and double-press to exit on root/dashboard screens.
class AppNavigationHelper {
  static final List<String> _history = ['/home'];
  static bool _isNavigatingBack = false;
  static DateTime? _lastBackPressTime;

  /// Main bottom navigation / dashboard routes.
  static const Set<String> dashboardRoutes = {
    '/home',
    '/discover',
    '/my-books',
    '/swaps',
    '/chat',
  };

  /// Returns true if the given route is one of the 5 primary dashboard tabs.
  static bool isDashboard(String route) {
    for (final d in dashboardRoutes) {
      if (route == d || route.startsWith('$d?')) return true;
    }
    return false;
  }

  /// Records a visited route into history.
  static void recordRoute(String route) {
    if (_isNavigatingBack) {
      _isNavigatingBack = false;
      return;
    }
    if (_history.isEmpty || _history.last != route) {
      _history.add(route);
      if (_history.length > 30) {
        _history.removeAt(0);
      }
    }
  }

  /// Handles back navigation consistently across Android system back button,
  /// predictive back gestures, and in-app back buttons.
  static Future<bool> handleBack(
    BuildContext context, {
    GlobalKey<ScaffoldState>? scaffoldKey,
  }) async {
    // 1. Close drawer if open
    if (scaffoldKey?.currentState?.isDrawerOpen == true) {
      scaffoldKey?.currentState?.closeDrawer();
      return true;
    }

    // 2. Close any open dialog or modal bottom sheet on the root navigator first
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop();
      return true;
    }

    // 3. Close any open modal or route on the nested/shell navigator
    final nav = Navigator.of(context, rootNavigator: false);
    if (nav.canPop()) {
      nav.pop();
      return true;
    }

    // 4. Navigate through history stack
    final current = GoRouterState.of(context).uri.toString();
    if (_history.isNotEmpty && _history.last == current) {
      _history.removeLast(); // drop current
    }

    while (_history.isNotEmpty && _history.last == current) {
      _history.removeLast();
    }

    if (_history.isNotEmpty) {
      final target = _history.removeLast();
      _isNavigatingBack = true;
      _history.add(target);
      context.go(target);
      return true;
    }

    // 5. If on non-home route and history is empty, go to /home
    if (current != '/home') {
      _isNavigatingBack = true;
      _history.clear();
      _history.add('/home');
      context.go('/home');
      return true;
    }

    // 6. On root /home: prompt double-press to exit app
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    // Second back press within 2 seconds exits app
    SystemNavigator.pop();
    return true;
  }
}
