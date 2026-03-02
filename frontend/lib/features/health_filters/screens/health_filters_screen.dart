import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../../core/widgets/recipe_cards.dart';
import '../../recipes/screens/recipe_detail_screen.dart';

class HealthFiltersScreen extends StatefulWidget {
  const HealthFiltersScreen({super.key});

  @override
  State<HealthFiltersScreen> createState() => _HealthFiltersScreenState();
}

class _HealthFiltersScreenState extends State<HealthFiltersScreen> {
  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final filteredRecipes = recipeProvider.getFilteredRecipes();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Filters'),
        centerTitle: true,
        actions: [
          if (recipeProvider.selectedHealthFilters.isNotEmpty)
            TextButton(
              onPressed: () => recipeProvider.clearHealthFilters(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.diabetesFriendly.withOpacity(0.15),
                    AppColors.heartHealthy.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.diabetesFriendly, AppColors.heartHealthy],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.healing_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Health-Aligned Eating',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Find recipes tailored to your health needs',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Filter section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Select Health Conditions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          
          // Filter list - original 2 column style
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildFilterOption(
                    context,
                    'Diabetes-Friendly',
                    Icons.bloodtype_outlined,
                    AppColors.diabetesFriendly,
                    'Low glycemic index recipes',
                    recipeProvider,
                  ),
                  _buildFilterOption(
                    context,
                    'Low Salt',
                    Icons.grain_rounded,
                    AppColors.lowSalt,
                    'For hypertension management',
                    recipeProvider,
                  ),
                  _buildFilterOption(
                    context,
                    'Heart Healthy',
                    Icons.favorite_rounded,
                    AppColors.heartHealthy,
                    'Good fats and low cholesterol',
                    recipeProvider,
                  ),
                  _buildFilterOption(
                    context,
                    'Weight Loss',
                    Icons.fitness_center_rounded,
                    AppColors.weightLoss,
                    'Low calorie, high nutrition',
                    recipeProvider,
                  ),
                  _buildFilterOption(
                    context,
                    'Iron-Rich',
                    Icons.local_hospital_rounded,
                    AppColors.error,
                    'For anemia prevention',
                    recipeProvider,
                  ),
                  _buildFilterOption(
                    context,
                    'Quick Meal',
                    Icons.schedule_rounded,
                    AppColors.quickMeal,
                    'Ready in 30 minutes or less',
                    recipeProvider,
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          
          // Results header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                recipeProvider.selectedHealthFilters.isEmpty
                    ? 'All Recipes'
                    : 'Filtered Recipes (${filteredRecipes.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          
          // Recipe grid - smaller cards with higher aspect ratio
          filteredRecipes.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.textTertiaryLight.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppColors.textTertiaryLight,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No matching recipes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final recipe = filteredRecipes[index];
                        return CompactRecipeCard(
                          recipe: recipe,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailScreen(recipe: recipe),
                            ),
                          ),
                        );
                      },
                      childCount: filteredRecipes.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String description,
    RecipeProvider provider,
  ) {
    final isSelected = provider.selectedHealthFilters.contains(label);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => provider.toggleHealthFilter(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: (MediaQuery.of(context).size.width - 52) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.15) 
              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
