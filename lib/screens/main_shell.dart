import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'home_screen.dart';
import 'category_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _currentIndex = appState.currentNavIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit App', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final int rawIndex = appState.currentNavIndex;

    // Sync state: If current nav index is changed programmatically from outside (e.g. avatar tap), update PageView
    if (rawIndex != _currentIndex && rawIndex >= 0 && rawIndex < 4) {
      _currentIndex = rawIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(rawIndex);
        }
      });
    }

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          setState(() {
            _currentIndex = 0;
          });
          appState.setNavIndex(0);
          return false;
        } else {
          final shouldExit = await _showExitConfirmationDialog(context);
          if (shouldExit) {
            SystemNavigator.pop();
          }
          return false;
        }
      },
      child: Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (index != _currentIndex) {
            setState(() {
              _currentIndex = index;
            });
            appState.setNavIndex(index);
          }
        },
        children: const [
          HomeScreen(),
          CategoryScreen(),
          CartScreen(showBackButton: false), // Hide back button in shell tab
          ProfileScreen(showBackButton: false), // Hide back button in shell tab
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8), // Floating bottom dock safely above navigation gestures
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24), // Fully rounded corners
            border: Border.all(
              color: const Color(0xFFE8F5E9), // Light green border matching the theme
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B5E20).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, "Home"),
                _buildNavItem(1, Icons.grid_view_rounded, Icons.grid_view_outlined, "Categories"),
                _buildNavItem(2, Icons.shopping_cart_rounded, Icons.shopping_cart_outlined, "Cart"),
                _buildNavItem(3, Icons.person_rounded, Icons.person_outlined, "Profile"),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final bool isActive = _currentIndex == index;
    final appState = Provider.of<AppState>(context);
    final int cartCount = appState.cartCount;

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentIndex = index;
        });
        Provider.of<AppState>(context, listen: false).setNavIndex(index);
      },
      child: AnimatedScale(
        scale: isActive ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE8F5E9) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isActive
                ? Border.all(color: const Color(0xFF81C784).withOpacity(0.4), width: 1)
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? activeIcon : inactiveIcon,
                    color: isActive ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                    size: 22,
                  ),
                  if (index == 2 && cartCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE91E63),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Center(
                          child: Text(
                            '$cartCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 75),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
