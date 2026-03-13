import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../home/screens/home_screen.dart';
import '../chat/screens/chat_screen.dart';
import '../chat/screens/voice_assistant_mode.dart';
import '../recipes/screens/recipe_library_screen.dart';
import '../profile/screens/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const RecipeLibraryScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : null,
      body: Stack(
        children: [
          // Dark mode full-screen logo watermark
          if (isDark)
            Positioned.fill(
              child: Opacity(
                opacity: 0.06,
                child: Image.asset(
                  'assets/images/app_bg_logo.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 72,
        width: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFA67C00)], // App gold gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.6),
              blurRadius: 18,
              spreadRadius: 3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    VoiceAssistantMode(
                      onClose: () => Navigator.pop(context),
                    ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                fullscreenDialog: true,
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: Image.asset(
            'assets/images/gemini_logo.png',
            width: 50,
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              // Match app background color (0xFF0A0A0A) with glass opacity
              color: const Color(0xFF0A0A0A).withOpacity(0.82),
              border: Border(
                top: BorderSide(
                  // Subtle gold-tinted separator line
                  color: AppColors.primary.withOpacity(0.18),
                  width: 0.6,
                ),
              ),
            ),
            child: BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 12.0,
              color: Colors.transparent, // Let parent Container control the color
              elevation: 0,
              padding: EdgeInsets.zero, // Remove default padding — we handle it manually
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  // Inset items from edges for breathing room
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                        _buildNavItem(1, Icons.menu_book_rounded, Icons.menu_book_outlined, 'Recipes'),
                        const SizedBox(width: 52), // Space for FAB notch
                        _buildNavItem(2, Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Chat'),
                        _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    final selectedColor = AppColors.primary;
    final unselectedColor = Colors.white.withOpacity(0.45);

    // Detect mobile vs tablet/desktop for label visibility
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.0 : 12.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          // Gold pill background only for selected item
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: isSelected
              ? Border.all(
                  color: AppColors.primary.withOpacity(0.25),
                  width: 0.8,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 22,
            ),
            // Show label only when selected AND not mobile
            if (isSelected && !isMobile) ...[
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selectedColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}