import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/recipe_cards.dart';
import '../../../core/widgets/text_fields.dart';
import '../../../core/widgets/skeleton_loaders.dart';
import '../../../core/utils/responsive.dart';
import '../../recipes/screens/recipe_detail_screen.dart';
import '../../leftover/screens/leftover_screen.dart';
import '../../health_filters/screens/health_filters_screen.dart';
import '../../recipes/screens/saved_recipes_screen.dart';
import '../../recipes/screens/recipe_library_screen.dart';
import '../../scanner/screens/ingredient_scanner_screen.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/section_header.dart';
import '../../chat/screens/voice_assistant_mode.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
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
    
    // Rotate tips every 8 seconds
    _startTipRotation();
    
    // Simulate loading
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    });
  }

  void _startTipRotation() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _aiTips.length;
        });
        _startTipRotation();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // Move above nav bar
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => 
                  VoiceAssistantMode(onClose: () => Navigator.pop(context)),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                fullscreenDialog: true,
              ),
            );
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.mic_rounded, color: Colors.white),
          label: const Text('Ask AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                              'assets/images/logo.png',
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
                              const SizedBox(height: 6),
                              // Dynamic AI tip with animation
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: Container(
                                  key: ValueKey(_currentTipIndex),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.secondary.withOpacity(isDark ? 0.15 : 0.2),
                                        AppColors.primary.withOpacity(isDark ? 0.1 : 0.15),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.secondary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getDailyTip()['icon'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _getDailyTip()['tip'],
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: isDark 
                                                ? AppColors.secondaryLight 
                                                : AppColors.secondaryDark,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 11,
                                        color: AppColors.secondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            // Theme toggle
                            GestureDetector(
                              onTap: () {
                                context.read<ThemeProvider>().toggleTheme();
                              },
                              child: Container(
                                width: isMobile ? 32 : 36,
                                height: isMobile ? 32 : 36,
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
                                  size: isMobile ? 16 : 18,
                                ),
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            // Profile avatar
                            Container(
                              width: isMobile ? 36 : 42,
                              height: isMobile ? 36 : 42,
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
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2, end: 0),
                ),
            
                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 10 : 14, horizontalPadding, isMobile ? 10 : 14),
                    child: SearchTextField(
                      hint: 'Search recipes, ingredients...',
                      onFilterTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HealthFiltersScreen(),
                          ),
                        );
                      },
                    ),
                  ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
                ),

                // Quick Actions - Responsive Grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: isMobile 
                        ? _buildMobileQuickActions(recipeProvider)
                        : _buildDesktopQuickActions(recipeProvider),
                  ).animate().fade(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0),
                ),
            
                // Daily Suggestion
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 24 : 32, horizontalPadding, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:  [
                        const SectionHeader(
                          title: "Today's Recommendation",
                          subtitle: 'Personalized for you',
                        ),
                        SizedBox(height: isMobile ? 14 : 20),
                        if (_isLoading)
                          const RecipeCardSkeleton(isHorizontal: true)
                        else if (recipeProvider.dailySuggestion != null)
                          DailySuggestionCard(
                            recipe: recipeProvider.dailySuggestion!,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(
                                  recipe: recipeProvider.dailySuggestion!,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2, end: 0),
                ),
            
                // Mauritanian Recipes
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 28 : 36, horizontalPadding, isMobile ? 10 : 14),
                    child: SectionHeader(
                      title: 'Mauritanian Classics',
                      subtitle: 'Traditional recipes from home',
                      onViewAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecipeLibraryScreen(),
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 400.ms, delay: 500.ms).slideX(begin: -0.1, end: 0),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: isMobile ? 280 : 320,
                    child: _isLoading
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            itemCount: 3,
                            itemBuilder: (context, index) {
                              return const RecipeCardSkeleton(isHorizontal: false);
                            },
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            itemCount: recipeProvider.mauritanianRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = recipeProvider.mauritanianRecipes[index];
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
                                ).animate().fade(duration: 400.ms, delay: (500 + (index * 50)).ms).slideX(begin: 0.2, end: 0),
                              );
                            },
                          ),
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
                  ).animate().fade(duration: 400.ms, delay: 600.ms).slideX(begin: -0.1, end: 0),
                ),
            
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: isMobile ? 280 : 320,
                    child: _isLoading
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            itemCount: 3,
                            itemBuilder: (context, index) {
                              return const RecipeCardSkeleton(isHorizontal: false);
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
                                ).animate().fade(duration: 400.ms, delay: (600 + (index * 50)).ms).slideX(begin: 0.2, end: 0),
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
  
  // Mobile: 2x2 grid of cards
  Widget _buildMobileQuickActions(RecipeProvider recipeProvider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                icon: Icons.healing_rounded,
                label: 'Health',
                subtitle: 'Personalized',
                color: AppColors.diabetesFriendly,
                compact: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HealthFiltersScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QuickActionCard(
                icon: Icons.eco_rounded,
                label: 'Leftovers',
                subtitle: 'Reduce waste',
                color: AppColors.accent,
                compact: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeftoverScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                icon: Icons.bookmark_rounded,
                label: 'Saved',
                subtitle: '${recipeProvider.savedRecipes.length} recipes',
                color: AppColors.warning,
                compact: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SavedRecipesScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QuickActionCard(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scanner',
                subtitle: 'Check pantry',
                color: AppColors.primary,
                compact: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IngredientScannerScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Desktop: 2 rows of 2 cards
  Widget _buildDesktopQuickActions(RecipeProvider recipeProvider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                icon: Icons.healing_rounded,
                label: 'Health Filters',
                subtitle: 'Personalized meals',
                color: AppColors.diabetesFriendly,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HealthFiltersScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: QuickActionCard(
                icon: Icons.eco_rounded,
                label: 'Leftovers',
                subtitle: 'Reduce waste',
                color: AppColors.accent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeftoverScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                icon: Icons.bookmark_rounded,
                label: 'Saved',
                subtitle: '${recipeProvider.savedRecipes.length} recipes',
                color: AppColors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SavedRecipesScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: QuickActionCard(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Ingredient Scanner',
                subtitle: 'Check your pantry',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IngredientScannerScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
