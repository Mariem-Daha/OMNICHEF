import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../../core/widgets/recipe_cards.dart';
import '../../../core/widgets/text_fields.dart';
import '../../../core/utils/responsive.dart';
import 'recipe_detail_screen.dart';

class RecipeLibraryScreen extends StatefulWidget {
  const RecipeLibraryScreen({super.key});

  @override
  State<RecipeLibraryScreen> createState() => _RecipeLibraryScreenState();
}

class _RecipeLibraryScreenState extends State<RecipeLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();
  String _searchQuery = '';
  String _globalSearchQuery = '';
  String _selectedGlobalCuisine = '';
  final ScrollController _scrollController = ScrollController();
  final ScrollController _globalScrollController = ScrollController();

  static const List<String> _globalCuisines = [
    '', 'Italian', 'Mexican', 'American', 'French', 'Chinese',
    'Japanese', 'Indian', 'Spanish', 'Thai', 'Mediterranean',
    'Greek', 'Korean', 'Vietnamese', 'Turkish', 'British',
    'German', 'African', 'Caribbean', 'Brazilian',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Add scroll listener for infinite scroll (All tab)
    _scrollController.addListener(_onScroll);
    // Add scroll listener for Global tab infinite scroll
    _globalScrollController.addListener(_onGlobalScroll);

    // Fetch data for tabs to ensure they are populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RecipeProvider>();
      if (provider.mauritanianRecipes.isEmpty) {
        provider.loadMauritanianRecipes();
      }
      if (provider.menaRecipes.isEmpty) {
        provider.loadMenaRecipes();
      }
      if (provider.globalRecipes.isEmpty) {
        provider.loadGlobalRecipes();
      }
    });

    // Listen to tab changes to refresh if needed
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final provider = context.read<RecipeProvider>();
        if (_tabController.index == 1 && provider.mauritanianRecipes.isEmpty) {
          provider.loadMauritanianRecipes();
        } else if (_tabController.index == 2 && provider.menaRecipes.isEmpty) {
          provider.loadMenaRecipes();
        } else if (_tabController.index == 3 && provider.globalRecipes.isEmpty) {
          provider.loadGlobalRecipes();
        }
      }
    });
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more recipes when near the bottom
      final recipeProvider = context.read<RecipeProvider>();
      if (!recipeProvider.isLoadingMore && recipeProvider.hasMoreRecipes) {
        recipeProvider.loadMoreRecipes();
      }
    }
  }

  void _onGlobalScroll() {
    if (_globalScrollController.position.pixels >=
        _globalScrollController.position.maxScrollExtent - 300) {
      final provider = context.read<RecipeProvider>();
      if (!provider.isLoadingGlobal && provider.hasMoreGlobalRecipes) {
        provider.loadMoreGlobalRecipes();
      }
    }
  }

  void _triggerGlobalSearch() {
    context.read<RecipeProvider>().searchGlobalRecipes(
      query: _globalSearchQuery,
      cuisine: _selectedGlobalCuisine,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _globalSearchController.dispose();
    _scrollController.dispose();
    _globalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipeProvider = context.watch<RecipeProvider>();
    final isMobile = Responsive.isMobile(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Background Decorative Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primary.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          
          // Main Content
          SafeArea(
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Animated Header
                  SliverToBoxAdapter(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 
                        isMobile ? 20 : 32, 
                        horizontalPadding, 
                        0
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title Row with Stats
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recipe Library',
                                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1,
                                        fontSize: isMobile ? 28 : 36,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Local favourites & global cuisine from every corner of the world',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        fontSize: isMobile ? 14 : 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Recipe Count Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${recipeProvider.totalRecipes} Recipes',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Search Bar
                          SearchTextField(
                            controller: _searchController,
                            hint: 'Search by name, ingredient, or tag...',
                            onChanged: (value) {
                              setState(() => _searchQuery = value.toLowerCase());
                            },
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Category Chips
                          _buildCategoryFilter(isDark, isMobile),
                        ],
                      ),
                    ),
                  ),
                  
                  // Sticky Tab Bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTabBarDelegate(
                      child: Container(
                        color: isDark 
                            ? AppColors.backgroundDark.withOpacity(0.95) 
                            : AppColors.backgroundLight.withOpacity(0.95),
                        child: ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.cardDark : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  labelColor: Colors.white,
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  unselectedLabelColor: isDark 
                                      ? AppColors.textSecondaryDark 
                                      : AppColors.textSecondaryLight,
                                  unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  indicator: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  splashBorderRadius: BorderRadius.circular(12),
                                  tabs: const [
                                    Tab(text: 'All', height: 44),
                                    Tab(text: 'Mauritanian', height: 44),
                                    Tab(text: 'MENA', height: 44),
                                    Tab(text: '\u{1F30D} Global', height: 44),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildRecipeGrid(recipeProvider.recipes),
                  _buildRecipeGrid(recipeProvider.mauritanianRecipes),
                  _buildRecipeGrid(recipeProvider.menaRecipes),
                  _buildGlobalTab(recipeProvider, isDark, isMobile, horizontalPadding),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark, bool isMobile) {
    final categories = [
      {'icon': Icons.local_fire_department, 'label': 'Popular', 'color': const Color(0xFFE07A5F)},
      {'icon': Icons.access_time, 'label': 'Quick', 'color': const Color(0xFF4CAF50)},
      {'icon': Icons.favorite, 'label': 'Healthy', 'color': const Color(0xFFE91E63)},
      {'icon': Icons.eco, 'label': 'Vegetarian', 'color': const Color(0xFF8BC34A)},
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: (cat['color'] as Color).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (cat['color'] as Color).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(cat['icon'] as IconData, size: 18, color: cat['color'] as Color),
                const SizedBox(width: 8),
                Text(
                  cat['label'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipeGrid(List recipes) {
    final isMobile = Responsive.isMobile(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final recipeProvider = context.read<RecipeProvider>();
    
    final filteredRecipes = recipes.where((recipe) {
      if (_searchQuery.isEmpty) return true;
      return recipe.name.toLowerCase().contains(_searchQuery) ||
          recipe.description.toLowerCase().contains(_searchQuery) ||
          recipe.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
    }).toList();

    if (recipeProvider.isLoading && recipes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (filteredRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: isMobile ? 48 : 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No recipes found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    // Check if we're showing the "All" tab (only paginate on All tab)
    final isAllTab = recipes == recipeProvider.recipes;
    final showLoadingIndicator = isAllTab && recipeProvider.isLoadingMore;
    final showLoadMore = isAllTab && recipeProvider.hasMoreRecipes;
    
    // Mobile: Single column list with fixed height cards
    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 130),
        itemCount: filteredRecipes.length + (showLoadMore || showLoadingIndicator ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading indicator at the bottom
          if (index >= filteredRecipes.length) {
            return _buildLoadingIndicator(showLoadingIndicator);
          }
          
          final recipe = filteredRecipes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 280,
              child: RecipeCard(
                recipe: recipe,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailScreen(recipe: recipe),
                  ),
                ),
                onSave: () => recipeProvider.toggleSaveRecipe(recipe),
              ),
            ),
          );
        },
      );
    }

    // Desktop/Tablet: Grid layout
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 130),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: filteredRecipes.length + (showLoadMore || showLoadingIndicator ? 3 : 0), // Add 3 for full row
      itemBuilder: (context, index) {
        // Loading indicator at the bottom (spanning across)
        if (index >= filteredRecipes.length) {
          if (index == filteredRecipes.length) {
            return _buildLoadingIndicator(showLoadingIndicator);
          }
          return const SizedBox(); // Empty placeholders for grid alignment
        }
        
        final recipe = filteredRecipes[index];
        return RecipeCard(
          recipe: recipe,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(recipe: recipe),
            ),
          ),
          onSave: () => recipeProvider.toggleSaveRecipe(recipe),
        );
      },
    );
  }
  
  Widget _buildLoadingIndicator(bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: isLoading
          ? Column(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading more recipes...',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : TextButton.icon(
              onPressed: () => context.read<RecipeProvider>().loadMoreRecipes(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Load more'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
    );
  }

  // ── Global (Spoonacular) tab ──────────────────────────────────────────────

  Widget _buildGlobalTab(
    RecipeProvider provider,
    bool isDark,
    bool isMobile,
    double horizontalPadding,
  ) {
    return Column(
      children: [
        // Search + cuisine filter row
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _globalSearchController,
                onChanged: (v) => setState(() => _globalSearchQuery = v),
                onSubmitted: (_) => _triggerGlobalSearch(),
                decoration: InputDecoration(
                  hintText: 'Search millions of global recipes...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _globalSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _globalSearchController.clear();
                            setState(() => _globalSearchQuery = '');
                            provider.loadGlobalRecipes(refresh: true);
                          },
                        )
                      : IconButton(
                          icon: Icon(Icons.search_rounded, color: AppColors.primary),
                          onPressed: _triggerGlobalSearch,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.cardDark : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              // Cuisine filter chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _globalCuisines.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = _globalCuisines[i];
                    final label = c.isEmpty ? 'All cuisines' : c;
                    final selected = _selectedGlobalCuisine == c;
                    return FilterChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedGlobalCuisine = c);
                        _triggerGlobalSearch();
                      },
                      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: selected ? AppColors.primary : Colors.grey.withOpacity(0.3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Results count
              if (provider.globalTotalResults > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${provider.globalTotalResults.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} results',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Recipe list
        Expanded(
          child: provider.isLoadingGlobal && provider.globalRecipes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.globalRecipes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public_off_rounded, size: 64, color: AppColors.primary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          const Text('No global recipes found', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => provider.loadGlobalRecipes(refresh: true),
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                  : isMobile
                      ? ListView.builder(
                          controller: _globalScrollController,
                          padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 130),
                          itemCount: provider.globalRecipes.length + 1,
                          itemBuilder: (context, index) {
                            if (index >= provider.globalRecipes.length) {
                              return provider.isLoadingGlobal
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  : const SizedBox(height: 16);
                            }
                            final recipe = provider.globalRecipes[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: SizedBox(
                                height: 280,
                                child: RecipeCard(
                                  recipe: recipe,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RecipeDetailScreen(recipe: recipe),
                                    ),
                                  ),
                                  onSave: () => provider.toggleSaveRecipe(recipe),
                                ),
                              ),
                            );
                          },
                        )
                      : GridView.builder(
                          controller: _globalScrollController,
                          padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 130),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: provider.globalRecipes.length + (provider.isLoadingGlobal ? 3 : 0),
                          itemBuilder: (context, index) {
                            if (index >= provider.globalRecipes.length) {
                              return index == provider.globalRecipes.length
                                  ? const Center(child: CircularProgressIndicator())
                                  : const SizedBox();
                            }
                            final recipe = provider.globalRecipes[index];
                            return RecipeCard(
                              recipe: recipe,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecipeDetailScreen(recipe: recipe),
                                ),
                              ),
                              onSave: () => provider.toggleSaveRecipe(recipe),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 76;

  @override
  double get minExtent => 76;

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
