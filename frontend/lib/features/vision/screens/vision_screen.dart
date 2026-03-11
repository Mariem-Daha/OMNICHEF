import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'cooking_companion_screen.dart';

/// Vision AI landing â€” launches the AI Sous Chef directly.
/// The live video session handles dish identification, ingredient scanning,
/// and real-time cooking guidance all in one.
class VisionScreen extends StatelessWidget {
  const VisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.warmGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Sous Chef',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            Text(
                              'Powered by Gemini Live',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textTertiaryLight,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Show Cuisinee your food â€” it sees, listens, and guides you like a real chef.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // â”€â”€ Hero card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // â”€â”€ Big launch card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CookingCompanionScreen(),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3949AB).withOpacity(0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF4A5568), Color(0xFF2D3748), Color(0xFF1A202C)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: icon + LIVE badge
                                  Row(
                                    children: [
                                      Container(
                                        width: 64, height: 64,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.warmGradient,
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: const Icon(Icons.videocam_rounded,
                                            color: Colors.white, size: 32),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('AI Sous Chef',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800)),
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.warmGradient,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text('LIVE',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.2)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  // Capabilities
                                  ..._Capability.all.map((c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34, height: 34,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(c.icon,
                                              color: AppColors.primary, size: 17),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(c.label,
                                              style: TextStyle(
                                                  color: Colors.white.withOpacity(0.85),
                                                  fontSize: 13.5,
                                                  height: 1.3)),
                                        ),
                                      ],
                                    ),
                                  )),
                                  const SizedBox(height: 22),
                                  // CTA
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.warmGradient,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.mic_rounded,
                                            color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text('Start Cooking with AI',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Decorative circle
                            Positioned(
                              right: -24, bottom: -24,
                              child: Container(
                                width: 110, height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // â”€â”€ Privacy note â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Camera and audio are processed live by Gemini AI and are never stored.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Capability items listed on the hero card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _Capability {
  const _Capability(this.icon, this.label);
  final IconData icon;
  final String   label;

  static const all = [
    _Capability(Icons.visibility_rounded,
        'Sees your camera â€” identifies dishes & ingredients in real time'),
    _Capability(Icons.mic_rounded,
        'Listens to your voice â€” ask questions, get instant answers'),
    _Capability(Icons.restaurant_menu_rounded,
        'Finds recipes â€” searches your personalised recipe library'),
    _Capability(Icons.timer_rounded,
        'Sets timers â€” just say "cook for 20 minutes"'),
    _Capability(Icons.favorite_rounded,
        'Health-aware â€” adapts advice to your conditions & allergies'),
  ];
}
