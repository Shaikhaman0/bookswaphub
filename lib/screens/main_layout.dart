
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:bookswaphub/core/routing/app_navigation_helper.dart';
import 'package:bookswaphub/widgets/app_header.dart';
import 'package:bookswaphub/widgets/app_sidebar.dart';

class MainLayout extends StatelessWidget {
final Widget child;

const MainLayout({
super.key,
required this.child,
});

int _calculateSelectedIndex(BuildContext context) {
final location = GoRouterState.of(context).uri.toString();

if (location.startsWith('/home')) {
return 0;
}

if (location.startsWith('/discover')) {
return 1;
}

if (location.startsWith('/my-books')) {
return 2;
}

if (location.startsWith('/swaps')) {
return 3;
}

if (location.startsWith('/chat')) {
return 4;
}

return 0;
}

void _onItemTapped(int index, BuildContext context) {
switch (index) {
case 0:
context.go('/home');
break;

case 1:
context.go('/discover');
break;

case 2:
context.go('/my-books');
break;

case 3:
context.go('/swaps');
break;

case 4:
context.go('/chat');
break;
}
}

@override
Widget build(BuildContext context) {
final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return _MobileLayout(
        selectedIndex: _calculateSelectedIndex(context),
        onItemTapped: (index) {
          _onItemTapped(index, context);
        },
        child: child,
      );
    }

return _DesktopLayout(
child: child,
);
}
}


// ============================================================
// MOBILE LAYOUT
// ============================================================

class _MobileLayout extends StatefulWidget {
final Widget child;
final int selectedIndex;
final ValueChanged<int> onItemTapped;

const _MobileLayout({
required this.child,
required this.selectedIndex,
required this.onItemTapped,
});

@override
State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    AppNavigationHelper.recordRoute(currentRoute);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        AppNavigationHelper.handleBack(context, scaffoldKey: _scaffoldKey);
      },
      child: Scaffold(
        key: _scaffoldKey,

        // Header
        appBar: AppHeader(
          onMenuPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),

        // Side drawer
        drawer: const AppSidebar(),

        // Current page
        body: widget.child,

        // Bottom navigation
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: widget.selectedIndex,
          onTap: widget.onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'My Books',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.swap_horiz_outlined),
              activeIcon: Icon(Icons.swap_horiz),
              label: 'Swaps',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_outlined),
              activeIcon: Icon(Icons.chat),
              label: 'Chat',
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// DESKTOP LAYOUT
// ============================================================

class _DesktopLayout extends StatelessWidget {
  final Widget child;

  const _DesktopLayout({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    AppNavigationHelper.recordRoute(currentRoute);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        AppNavigationHelper.handleBack(context);
      },
      child: Scaffold(
        body: Column(
          children: [
            // Top header
            const AppHeader(),

            // Sidebar + page content
            Expanded(
              child: Row(
                children: [
                  const AppSidebar(),

                  Expanded(
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
