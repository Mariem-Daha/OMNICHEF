import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/preferences_service.dart';
import 'preference_quiz_screen.dart';
import '../../navigation/main_navigation.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _onEnterKitchen(BuildContext context) async {
    final bool setupDone = await PreferencesService().hasCompletedSetup();
    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => setupDone
            ? const MainNavigation()
            : const PreferenceQuizScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Hero background image ──────────────────────────────
          Image.asset(
            'assets/images/welcome_hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          // ── 2. Gradient overlay (transparent top → dark bottom) ───
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.45, 1.0],
                colors: [
                  Color(0x00000000), // fully transparent
                  Color(0x55000000), // subtle mid fade
                  Color(0xDD000000), // ~87 % opaque at bottom
                ],
              ),
            ),
          ),

          // ── 3. Safe-area content ──────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top-left logo / wordmark
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/gemini_logo.png',
                        height: 48,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'OMNICHEF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 800.ms, delay: 200.ms),

                const Spacer(),

                // Bottom content area
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gemini badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.6),
                              width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Powered by Gemini AI',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ).animate()
                          .fade(duration: 700.ms, delay: 400.ms)
                          .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                      const SizedBox(height: 20),

                      // Headline
                      const Text(
                        'Your Intelligent\nCulinary Assistant.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ).animate()
                          .fade(duration: 700.ms, delay: 550.ms)
                          .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),

                      const SizedBox(height: 16),

                      // Sub-headline
                      Text(
                        'Master health-aligned eating, minimize food waste, and discover recipes tailored specifically to your tastes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 15,
                          height: 1.55,
                          fontWeight: FontWeight.w400,
                        ),
                      ).animate()
                          .fade(duration: 700.ms, delay: 700.ms)
                          .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

                      const SizedBox(height: 40),

                      // CTA button
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: () => _onEnterKitchen(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Enter Kitchen',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate()
                          .fade(duration: 700.ms, delay: 850.ms)
                          .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
