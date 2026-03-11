import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/recipe_cards.dart';
import '../../../core/widgets/text_fields.dart';
import '../../../core/widgets/skeleton_loaders.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/section_header.dart';
import '../../chat/screens/voice_assistant_mode.dart';
import '../../recipes/screens/recipe_detail_screen.dart';
import '../../health_filters/screens/health_filters_screen.dart';
import '../../recipes/screens/recipe_library_screen.dart';

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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _isLoading = false);
            _animationController.forward();
          }
        });
      }
    });
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
            
                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 10 : 14, horizontalPadding, isMobile ? 10 : 14),
                    child: SearchTextField(
                      hint: 'Ask Gemini or search recipes, ingredients...',
                      onFilterTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HealthFiltersScreen(),
                          ),
                        );
                      },
                    ),
                  ),
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
