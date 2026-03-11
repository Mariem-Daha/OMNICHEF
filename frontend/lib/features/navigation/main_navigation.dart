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
        margin: const EdgeInsets.only(top: 20),
        height: 80,
        width: 80,
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
          child: Image.asset(
            'assets/images/gemini_logo.png',
            width: 58,
            height: 58,
            fit: BoxFit.contain,
          ),
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.only(top: 12, bottom: 20, left: 16, right: 16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
              border: Border(
                top: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home', isDark),
                _buildNavItem(1, Icons.menu_book_rounded, 'Recipes', isDark),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(2, Icons.chat_bubble_rounded, 'Chat', isDark),
                _buildNavItem(3, Icons.person_rounded, 'Profile', isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark,
      {bool isSpecial = false}) {
    final isSelected = _currentIndex == index;
    final selectedColor = isSpecial ? Colors.white : AppColors.primary;
    final unselectedColor =
        (isDark ? Colors.white : Colors.black).withOpacity(0.5);

    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: isSpecial && isSelected
            ? BoxDecoration(
                gradient: AppColors.warmGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: isSelected ? 26 : 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selectedColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}