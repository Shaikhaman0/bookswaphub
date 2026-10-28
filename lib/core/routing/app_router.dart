import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bookswaphub/screens/main_layout.dart';

import 'package:bookswaphub/screens/splash/splash_screen.dart';
import 'package:bookswaphub/screens/auth/login_screen.dart';
import 'package:bookswaphub/screens/auth/register_screen.dart';

import 'package:bookswaphub/screens/home/home_screen.dart';
import 'package:bookswaphub/screens/discover/discover_screen.dart';
import 'package:bookswaphub/screens/book_details/book_details_screen.dart';
import 'package:bookswaphub/screens/my_books/my_books_screen.dart';
import 'package:bookswaphub/screens/add_book/add_book_screen.dart';
import 'package:bookswaphub/screens/edit_book/edit_book_screen.dart';
import 'package:bookswaphub/screens/swaps/swaps_screen.dart';
import 'package:bookswaphub/screens/chat/chat_screen.dart';
import 'package:bookswaphub/screens/notifications/notifications_screen.dart';
import 'package:bookswaphub/screens/wishlist/wishlist_screen.dart';
import 'package:bookswaphub/screens/profile/profile_screen.dart';
import 'package:bookswaphub/screens/settings/settings_screen.dart';
import 'package:bookswaphub/screens/ai_assistant/ai_assistant_screen.dart';
import 'package:bookswaphub/screens/auth/verify_email_screen.dart';
import 'package:bookswaphub/screens/admin/admin_screen.dart';
import 'package:bookswaphub/data/providers/providers.dart';

/// Routes anyone may open without being signed in.
const _publicRoutes = {'/', '/login', '/register'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run `redirect` whenever the sign-in state changes (login, logout, email verified, expiry).
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (previous, next) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;
      final loading = auth.isLoading;
      final user = auth.when(data: (u) => u, loading: () => null, error: (_, __) => null);

      // The splash screen always plays its animation, then navigates itself.
      if (loc == '/') return null;

      if (loading) {
        // Still checking the saved session: stay on public pages, hold protected ones at splash.
        return _publicRoutes.contains(loc) ? null : '/';
      }
      if (user == null) {
        // Signed out (or session expired): only public pages are allowed.
        return _publicRoutes.contains(loc) ? null : '/login';
      }
      if (!user.emailVerified) {
        return loc == '/verify-email' ? null : '/verify-email';
      }
      // Signed in and verified: keep them out of the auth pages.
      if (loc == '/login' || loc == '/register' || loc == '/verify-email') return '/home';
      return null;
    },

    routes: [
      // ============================================================
      // SPLASH
      // ============================================================

      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) {
          return const SplashScreen();
        },
      ),

      // ============================================================
      // AUTHENTICATION
      // ============================================================

      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          return const LoginScreen();
        },
      ),

      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) {
          return const RegisterScreen();
        },
      ),

      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          return const VerifyEmailScreen();
        },
      ),

      // ============================================================
      // MAIN APPLICATION
      // ============================================================

      ShellRoute(
        builder: (context, state, child) {
          return MainLayout(
            child: child,
          );
        },

        routes: [
          // HOME
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) {
              return const HomeScreen();
            },
          ),

          // DISCOVER
          GoRoute(
            path: '/discover',
            name: 'discover',
            builder: (context, state) {
              return DiscoverScreen(
                initialQuery: state.uri.queryParameters['q'] ?? '',
                initialCategory: state.uri.queryParameters['category'],
              );
            },
          ),

          // BOOK DETAILS
          GoRoute(
            path: '/book/:id',
            name: 'book-details',
            builder: (context, state) {
              final id = state.pathParameters['id']!;

              return BookDetailsScreen(
                bookId: id,
              );
            },
          ),

          // MY BOOKS
          GoRoute(
            path: '/my-books',
            name: 'my-books',
            builder: (context, state) {
              return const MyBooksScreen();
            },
          ),

          // ADD BOOK
          GoRoute(
            path: '/add-book',
            name: 'add-book',
            builder: (context, state) {
              return const AddBookScreen();
            },
          ),

          // EDIT BOOK
          GoRoute(
            path: '/edit-book/:id',
            name: 'edit-book',
            builder: (context, state) {
              final id = state.pathParameters['id']!;

              return EditBookScreen(
                bookId: id,
              );
            },
          ),

          // SWAPS
          GoRoute(
            path: '/swaps',
            name: 'swaps',
            builder: (context, state) {
              return const SwapsScreen();
            },
          ),

          // CHAT
          GoRoute(
            path: '/chat',
            name: 'chat',
            builder: (context, state) {
              // /chat?with=<userId> opens (or creates) the conversation with that person.
              return ChatScreen(initialUserId: state.uri.queryParameters['with']);
            },
          ),

          // NOTIFICATIONS
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) {
              return const NotificationsScreen();
            },
          ),

          // WISHLIST
          GoRoute(
            path: '/wishlist',
            name: 'wishlist',
            builder: (context, state) {
              return const WishlistScreen();
            },
          ),

          // PROFILE
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) {
              return const ProfileScreen();
            },
          ),
          GoRoute(
            path: '/profile/:uid',
            name: 'userProfile',
            builder: (context, state) {
              return ProfileScreen(uid: state.pathParameters['uid']);
            },
          ),

          // SETTINGS
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) {
              return const SettingsScreen();
            },
          ),

          // ADMIN (the screen AND every backend function re-check the admin claim)
          GoRoute(
            path: '/admin',
            name: 'admin',
            builder: (context, state) {
              return const AdminScreen();
            },
          ),

          // AI ASSISTANT
          GoRoute(
            path: '/assistant',
            name: 'assistant',
            builder: (context, state) {
              return const AiAssistantScreen();
            },
          ),
        ],
      ),
    ],
  );
});