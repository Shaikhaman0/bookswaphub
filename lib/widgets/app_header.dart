import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/data/providers/providers.dart';

class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;

  const AppHeader({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(AppDimensions.headerHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final me = ref.watch(myProfileProvider).asData?.value;
    final isDesktop = MediaQuery.of(context).size.width >= AppDimensions.tabletBreakpoint;
    final currentRoute = GoRouterState.of(context).uri.toString();

    return AppBar(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.surface,
      elevation: 2,
      shadowColor: Colors.black12,
      titleSpacing: AppDimensions.paddingLg,
      leading: !isDesktop && onMenuPressed != null
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuPressed,
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book, color: AppColors.primary),
          const SizedBox(width: AppDimensions.paddingSm),
          Text(
            'BookSwap Hub',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      actions: [
        if (isDesktop) ...[
          _NavItem(
            title: 'Home',
            route: '/home',
            currentRoute: currentRoute,
          ),
          _NavItem(title: 'Discover', route: '/discover', currentRoute: currentRoute),
          _NavItem(title: 'My Books', route: '/my-books', currentRoute: currentRoute),
          _NavItem(title: 'Swaps', route: '/swaps', currentRoute: currentRoute),
          _NavItem(title: 'Chat', route: '/chat', currentRoute: currentRoute),
          const SizedBox(width: AppDimensions.paddingMd),
        ],
        IconButton(
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          onPressed: () => context.go('/notifications'),
        ),
        if (isDesktop) ...[
          const SizedBox(width: AppDimensions.paddingSm),
          Padding(
            padding: const EdgeInsets.only(right: AppDimensions.paddingLg),
            child: InkWell(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: (me?.avatarUrl ?? '').isNotEmpty ? NetworkImage(me!.avatarUrl) : null,
                child: (me?.avatarUrl ?? '').isEmpty ? const Icon(Icons.person, color: AppColors.primary, size: 20) : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final String title;
  final String route;
  final String currentRoute;

  const _NavItem({
    required this.title,
    required this.route,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentRoute == route || (route != '/' && currentRoute.startsWith(route));
    final textColor = Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return InkWell(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppColors.primary : textColor,
          ),
        ),
      ),
    );
  }
}
