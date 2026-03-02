import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../../core/widgets/recipe_cards.dart';
import 'recipe_detail_screen.dart';

class SavedRecipesScreen extends StatelessWidget {
  const SavedRecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final savedRecipes = recipeProvider.savedRecipes;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
        centerTitle: true,
      ),
      body: savedRecipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 80,
                    color: AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved recipes yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bookmark recipes to find them here',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: savedRecipes.length,
              itemBuilder: (context, index) {
                final recipe = savedRecipes[index];
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
            ),
    );
  }
}
