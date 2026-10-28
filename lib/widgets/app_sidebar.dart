import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/utils/session.dart';
import 'package:bookswaphub/data/providers/providers.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).asData?.value;
    final email = ref.watch(currentEmailProvider);
    final isAdmin = ref.watch(isAdminProvider).asData?.value ?? false;
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : AppColors.primaryLight,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.primary,
              backgroundImage: (me?.avatarUrl ?? '').isNotEmpty ? NetworkImage(me!.avatarUrl) : null,
              child: (me?.avatarUrl ?? '').isEmpty ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
            ),
            accountName: Text(
              me?.name ?? 'Reader',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            accountEmail: Text(
              email,
              style: GoogleFonts.inter(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(icon: Icons.home_outlined, title: 'Home', route: '/home', currentRoute: currentRoute),
                _DrawerItem(icon: Icons.search, title: 'Discover', route: '/discover', currentRoute: currentRoute),
                _DrawerItem(icon: Icons.library_books_outlined, title: 'My Books', route: '/my-books', currentRoute: currentRoute),
                _DrawerItem(icon: Icons.swap_horiz, title: 'Swaps', route: '/swaps', currentRoute: currentRoute),
                _DrawerItem(icon: Icons.chat_bubble_outline, title: 'Chat', route: '/chat', currentRoute: currentRoute),
                _DrawerItem(icon: Icons.notifications_none, title: 'Notifications', route: '/notifications', currentRoute: currentRoute),
                _DrawerItem(icon: Icons.favorite_border, title: 'Wishlist', route: '/wishlist', currentRoute: currentRoute),
                const Divider(),
                _DrawerItem(icon: Icons.person_outline, title: 'Profile', route: '/profile', currentRoute: currentRoute),
                _DrawerItem(icon: Icons.settings_outlined, title: 'Settings', route: '/settings', currentRoute: currentRoute),
                _DrawerItem(icon: Icons.smart_toy_outlined, title: 'AI Assistant', route: '/assistant', currentRoute: currentRoute),
                if (isAdmin)
                  _DrawerItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin Console',
                    route: '/admin',
                    currentRoute: currentRoute,
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: Text('Logout', style: GoogleFonts.inter(color: AppColors.error)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              signOutUser(ref);
            },
          ),
          const SizedBox(height: AppDimensions.paddingMd),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final String currentRoute;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.route,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentRoute == route || (route != '/' && currentRoute.startsWith(route));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive 
              ? AppColors.primary 
              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        ),
      ),
      selected: isActive,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
