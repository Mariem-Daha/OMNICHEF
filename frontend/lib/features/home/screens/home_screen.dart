import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/recipe_cards.dart';
import '../../../core/widgets/skeleton_loaders.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/section_header.dart';
import '../../chat/screens/voice_assistant_mode.dart';
import '../../recipes/screens/recipe_detail_screen.dart';
import '../../recipes/screens/recipe_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late PageController _recoPageController;
  int _recoPage = 0;
  bool _isLoading = true;
  int _currentTipIndex = 0;

  // Dynamic AI-generated tips
  final List<Map<String, dynamic>> _aiTips = [
    {'tip': 'Add lemon at the end for brightness.', 'icon': '🍋'},
    {'tip': 'Rinsing rice removes extra starch.', 'icon': '🍚'},
    {'tip': 'Rest meat for 5 minutes before slicing.', 'icon': '🥩'},
    {'tip': 'Toast spices before grinding for more aroma.', 'icon': '🌶️'},
    {'tip': 'Use room temperature eggs for fluffier baking.', 'icon': '🥚'},
    {'tip': 'Salt pasta water like the sea for best flavor.', 'icon': '🧂'},
    {'tip': 'Bloom garlic in cold oil for mellow flavor.', 'icon': '🧄'},
    {'tip': 'Deglaze pans with wine for instant sauce.', 'icon': '🍷'},
    {'tip': 'Freeze ginger for easier grating.', 'icon': '🫚'},
    {'tip': 'Pat proteins dry for better browning.', 'icon': '🍳'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _recoPageController = PageController(viewportFraction: 0.92);
    
    // Rotate tips every 8 seconds
    _startTipRotation();
    
    // Load initial data then recommendations
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _isLoading = false);
            _animationController.forward();
            _loadRecommendations();
          }
        });
      }
    });
  }

  void _loadRecommendations() {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    final prefs = [
      ...user.healthFilters,
      ...user.tastePreferences,
    ];

    context.read<RecipeProvider>().loadRecommendations(
      preferences: prefs,
      allergies: user.allergies,
      disliked: user.dislikedIngredients,
    );
  }

  void _startTipRotation() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentTipIndex = (_currentTipIndex + 1) % _aiTips.length;
            });
            _startTipRotation();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recoPageController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Map<String, dynamic> _getDailyTip() {
    return _aiTips[_currentTipIndex];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipeProvider = context.watch<RecipeProvider>();
    final userProvider = context.watch<UserProvider>();
    final userName = userProvider.user?.name.split(' ').first ?? 'Chef';
    final isMobile = Responsive.isMobile(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Reduced Header with greeting
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 10 : 12, horizontalPadding, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            width: isMobile ? 55 : 68,
                            height: isMobile ? 55 : 68,
                            margin: EdgeInsets.only(right: isMobile ? 12 : 16),
                            child: Image.asset(
                              'assets/images/gemini_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.restaurant_menu_rounded,
                                  size: 28,
                                  color: AppColors.primary,
                                );
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getGreeting()}, $userName 👋',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: isDark 
                                      ? AppColors.textSecondaryDark 
                                      : AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w500,
                                  fontSize: isMobile ? 12 : 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'What should we cook?',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  fontSize: isMobile ? 18 : 22,
                                ),
                              ),

                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Theme toggle
                            GestureDetector(
                              onTap: () {
                                context.read<ThemeProvider>().toggleTheme();
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.surfaceDark
                                      : AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: AppColors.softShadow,
                                ),
                                child: Icon(
                                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Profile avatar
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: AppColors.warmGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  userName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Personalised Recommendations ────────────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 24 : 32, horizontalPadding, 0),
                        child: SectionHeader(
                          title: 'For You',
                          subtitle: recipeProvider.recommendedRecipes.isEmpty
                              ? 'Top-rated picks'
                              : 'Based on your taste',
                        ),
                      ),
                      SizedBox(height: isMobile ? 14 : 18),

                      // ── Loading skeleton ────────────────────────────────────
                      if (_isLoading || recipeProvider.isLoadingRecommendations)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: const RecipeCardSkeleton(isHorizontal: true),
                        )

                      // ── Swipeable hero cards (top 3) ────────────────────────
                      else if (recipeProvider.recommendedRecipes.isNotEmpty) ...[
                        SizedBox(
                          height: isMobile ? 310 : 360,
                          child: PageView.builder(
                            controller: _recoPageController,
                            itemCount: recipeProvider.recommendedRecipes.length.clamp(0, 5),
                            onPageChanged: (i) => setState(() => _recoPage = i),
                            itemBuilder: (context, index) {
                              final recipe = recipeProvider.recommendedRecipes[index];
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding * 0.5,
                                ),
                                child: _buildHeroRecoCard(context, recipe),
                              );
                            },
                          ),
                        ),

                        // ── Dot indicator ─────────────────────────────────────
                        if (recipeProvider.recommendedRecipes.length > 1) ...[
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              recipeProvider.recommendedRecipes.length.clamp(0, 5),
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _recoPage == i ? 22 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: _recoPage == i
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.25),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // ── More picks (landscape cards) ──────────────────────
                        if (recipeProvider.recommendedRecipes.length > 5) ...[
                          SizedBox(height: isMobile ? 22 : 26),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            child: Text(
                              'More picks',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              itemCount: recipeProvider.recommendedRecipes.length - 5,
                              itemBuilder: (context, index) {
                                final recipe = recipeProvider.recommendedRecipes[index + 5];
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RecipeDetailScreen(recipe: recipe),
                                    ),
                                  ),
                                  child: _buildCompactLandscapeCard(context, recipe, isDark),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
            
                // MENA Recipes
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 20 : 28, horizontalPadding, isMobile ? 10 : 14),
                    child: SectionHeader(
                      title: 'MENA Favorites',
                      subtitle: 'Recipes from the region',
                      onViewAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecipeLibraryScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
            
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: isMobile ? 280 : 320,
                    child: (_isLoading || recipeProvider.isLoadingMena)
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            itemCount: 3,
                            itemBuilder: (context, index) {
                              return const RecipeCardSkeleton(isHorizontal: true);
                            },
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            itemCount: recipeProvider.menaRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = recipeProvider.menaRecipes[index];
                              return Container(
                                width: isMobile ? 180 : 220,
                                margin: const EdgeInsets.only(right: 16),
                                child: RecipeCard(
                                  recipe: recipe,
                                  isHorizontal: false,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RecipeDetailScreen(recipe: recipe),
                                    ),
                                  ),
                                  onSave: () => recipeProvider.toggleSaveRecipe(recipe),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: isMobile ? 130 : 150)),
              ],
            ),
          ],
        ),
      ),
    );
  }  
  
  // ── Swipeable full-width hero recommendation card ─────────────────────────
  Widget _buildHeroRecoCard(BuildContext context, recipe) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(recipe: recipe),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background image ────────────────────────────────────────
              Image.network(
                recipe.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceDark,
                  child: Icon(
                    Icons.restaurant_rounded,
                    size: 64,
                    color: AppColors.primary.withOpacity(0.4),
                  ),
                ),
              ),

              // ── Bottom gradient ──────────────────────────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.38, 1.0],
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.transparent,
                        Colors.black.withOpacity(0.88),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Top row: cuisine badge + rating ──────────────────────────
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    _buildRecoGlassBadge(recipe.cuisine),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.93),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFED6C02)),
                          const SizedBox(width: 4),
                          Text(
                            recipe.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF121212),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom: title + meta + CTA ───────────────────────────────
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.2,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 10),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 6),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildRecoInfoPill(Icons.schedule_rounded, '${recipe.totalTime} min'),
                        const SizedBox(width: 8),
                        _buildRecoInfoPill(Icons.local_fire_department_rounded, '${recipe.calories} cal'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: AppColors.warmGradient,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Cook Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecoGlassBadge(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecoInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Compact landscape card (more picks row) ──────────────────────────────
  Widget _buildCompactLandscapeCard(BuildContext context, recipe, bool isDark) {
    return Container(
      width: 280,
      height: 110,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            child: SizedBox(
              width: 100,
              height: double.infinity,
              child: Image.network(
                recipe.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.dividerLight,
                  child: const Icon(Icons.restaurant_rounded, size: 28),
                ),
              ),
            ),
          ),
          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    recipe.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFED6C02)),
                      const SizedBox(width: 3),
                      Text(
                        recipe.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.schedule_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.totalTime} min',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiHeroCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.secondary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark ? AppColors.elevatedShadow : AppColors.cardShadow,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.warmGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Gemini Companion',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your real-time AI sous-chef',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Point your camera at the ingredients in your fridge, and I will guide you step-by-step.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => 
                          VoiceAssistantMode(
                            onClose: () => Navigator.pop(context),
                            startWithCamera: true,
                          ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_rounded, color: AppColors.secondaryDark),
                  label: const Text(
                    'Point Camera',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, // Premium Gold
                    foregroundColor: AppColors.secondaryDark, // Dark text
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => 
                          VoiceAssistantMode(
                            onClose: () => Navigator.pop(context),
                            startWithCamera: false,
                          ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  icon: const Icon(Icons.mic_rounded, color: Colors.white),
                  label: const Text(
                    'Voice Only',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
