import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../../core/widgets/recipe_cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/data/dummy_recipes.dart';
import '../../recipes/screens/recipe_detail_screen.dart';

class LeftoverScreen extends StatefulWidget {
  const LeftoverScreen({super.key});

  @override
  State<LeftoverScreen> createState() => _LeftoverScreenState();
}

class _LeftoverScreenState extends State<LeftoverScreen> {
  final TextEditingController _ingredientController = TextEditingController();

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final matchedRecipes = recipeProvider.getRecipesByLeftovers();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leftover Mode'),
        centerTitle: true,
        actions: [
          if (recipeProvider.leftoverIngredients.isNotEmpty)
            TextButton(
              onPressed: () => recipeProvider.clearLeftovers(),
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.2),
                  AppColors.accentLight.withOpacity(0.2),
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
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
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
                            'Reduce Food Waste',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tell us what's in your fridge",
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
          
          // Input field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ingredientController,
                    decoration: InputDecoration(
                      hintText: 'Add an ingredient...',
                      prefixIcon: const Icon(Icons.add_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: AppColors.primary,
                        onPressed: () {
                          if (_ingredientController.text.isNotEmpty) {
                            recipeProvider.addLeftoverIngredient(
                              _ingredientController.text,
                            );
                            _ingredientController.clear();
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        recipeProvider.addLeftoverIngredient(value);
                        _ingredientController.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Common ingredients
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Common Ingredients',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: DummyRecipes.commonIngredients.length,
              itemBuilder: (context, index) {
                final ingredient = DummyRecipes.commonIngredients[index];
                final isSelected = recipeProvider.leftoverIngredients.contains(ingredient);
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CustomFilterChip(
                    label: ingredient,
                    isSelected: isSelected,
                    onTap: () {
                      if (isSelected) {
                        recipeProvider.removeLeftoverIngredient(ingredient);
                      } else {
                        recipeProvider.addLeftoverIngredient(ingredient);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Selected ingredients
          if (recipeProvider.leftoverIngredients.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Your Ingredients (${recipeProvider.leftoverIngredients.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recipeProvider.leftoverIngredients.map((ingredient) {
                  return IngredientChip(
                    ingredient: ingredient,
                    onRemove: () => recipeProvider.removeLeftoverIngredient(ingredient),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
          
          // Results
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  recipeProvider.leftoverIngredients.isEmpty
                      ? 'Add ingredients to see recipes'
                      : 'Matching Recipes (${matchedRecipes.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Recipe grid
          Expanded(
            child: recipeProvider.leftoverIngredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textTertiaryLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Add some ingredients',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "We'll find recipes you can make",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : matchedRecipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: AppColors.textTertiaryLight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matching recipes',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adding more ingredients',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: matchedRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = matchedRecipes[index];
                          return RecipeCard(
                            recipe: recipe,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(recipe: recipe),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
