import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswaphub/core/routing/app_navigation_helper.dart';

void main() {
  group('AppNavigationHelper Tests', () {
    test('isDashboard correctly identifies dashboard routes vs subroutes', () {
      expect(AppNavigationHelper.isDashboard('/home'), isTrue);
      expect(AppNavigationHelper.isDashboard('/discover'), isTrue);
      expect(AppNavigationHelper.isDashboard('/discover?q=flutter'), isTrue);
      expect(AppNavigationHelper.isDashboard('/my-books'), isTrue);
      expect(AppNavigationHelper.isDashboard('/swaps'), isTrue);
      expect(AppNavigationHelper.isDashboard('/chat'), isTrue);

      expect(AppNavigationHelper.isDashboard('/book/123'), isFalse);
      expect(AppNavigationHelper.isDashboard('/add-book'), isFalse);
      expect(AppNavigationHelper.isDashboard('/edit-book/123'), isFalse);
      expect(AppNavigationHelper.isDashboard('/notifications'), isFalse);
      expect(AppNavigationHelper.isDashboard('/settings'), isFalse);
      expect(AppNavigationHelper.isDashboard('/admin'), isFalse);
      expect(AppNavigationHelper.isDashboard('/profile'), isFalse);
      expect(AppNavigationHelper.isDashboard('/profile/user1'), isFalse);
    });

    testWidgets('handleBack closes open dialog before navigating away', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) {
              AppNavigationHelper.recordRoute('/home');
              return Scaffold(
                body: Builder(
                  builder: (innerCtx) => ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: innerCtx,
                        useRootNavigator: true,
                        builder: (_) => const AlertDialog(title: Text('Test Dialog')),
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Test Dialog'), findsOneWidget);

      // System back should dismiss the dialog
      final BuildContext dialogContext = tester.element(find.text('Test Dialog'));
      final handled = await AppNavigationHelper.handleBack(dialogContext);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      // Dialog is gone, still on /home
      expect(find.text('Test Dialog'), findsNothing);
      expect(find.text('Open Dialog'), findsOneWidget);
    });

    testWidgets('handleBack navigates backwards through route history', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) {
              AppNavigationHelper.recordRoute('/home');
              return const Scaffold(body: Text('Home Screen'));
            },
          ),
          GoRoute(
            path: '/discover',
            builder: (ctx, state) {
              AppNavigationHelper.recordRoute('/discover');
              return const Scaffold(body: Text('Discover Screen'));
            },
          ),
          GoRoute(
            path: '/book/1',
            builder: (ctx, state) {
              AppNavigationHelper.recordRoute('/book/1');
              return const Scaffold(body: Text('Book 1 Details'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Home Screen'), findsOneWidget);

      // Navigate to discover
      router.go('/discover');
      await tester.pumpAndSettle();
      expect(find.text('Discover Screen'), findsOneWidget);

      // Navigate to book details
      router.go('/book/1');
      await tester.pumpAndSettle();
      expect(find.text('Book 1 Details'), findsOneWidget);

      // Press back -> should return to discover
      final BuildContext bookContext = tester.element(find.text('Book 1 Details'));
      await AppNavigationHelper.handleBack(bookContext);
      await tester.pumpAndSettle();
      expect(find.text('Discover Screen'), findsOneWidget);

      // Press back -> should return to home
      final BuildContext discoverContext = tester.element(find.text('Discover Screen'));
      await AppNavigationHelper.handleBack(discoverContext);
      await tester.pumpAndSettle();
      expect(find.text('Home Screen'), findsOneWidget);
    });
  });
}
