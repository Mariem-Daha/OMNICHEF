import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../home/screens/home_screen.dart';
import '../chat/screens/chat_screen.dart';
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
      extendBody: true, // Key for floating effect
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_rounded, 'Home', isDark),
                  _buildNavItem(1, Icons.menu_book_rounded, 'Recipes', isDark),
                  _buildNavItem(2, Icons.auto_awesome_rounded, 'AI Chef', isDark, isSpecial: true),
                  _buildNavItem(3, Icons.person_rounded, 'Profile', isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark, {bool isSpecial = false}) {
    final isSelected = _currentIndex == index;
    final selectedColor = isSpecial ? Colors.white : AppColors.primary;
    final unselectedColor = (isDark ? Colors.white : Colors.black).withOpacity(0.5);

    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12, 
          vertical: 8
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
              size: 24,
            ).animate(target: isSelected ? 1 : 0)
             .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 200.ms),
            
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selectedColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.2, end: 0)
            ]
          ],
        ),
      ),
    );
  }
}
