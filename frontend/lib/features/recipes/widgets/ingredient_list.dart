import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/recipe_model.dart';

class IngredientList extends StatelessWidget {
  final List<String> ingredients;
  final int servings;
  final int originalServings;
  final List<IngredientSubstitution> substitutions;
  final Function(int) onServingsChanged;

  const IngredientList({
    super.key,
    required this.ingredients,
    required this.servings,
    required this.originalServings,
    required this.substitutions,
    required this.onServingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Servings adjuster
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Servings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    _buildServingButton(
                      context,
                      Icons.remove_rounded,
                      () {
                        if (servings > 1) onServingsChanged(servings - 1);
                      },
                    ),
                    Container(
                      width: 50,
                      alignment: Alignment.center,
                      child: Text(
                        '$servings',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    _buildServingButton(
                      context,
                      Icons.add_rounded,
                      () => onServingsChanged(servings + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Ingredients list
          ...ingredients.asMap().entries.map((entry) {
            final ingredient = entry.value;
            final substitution = substitutions.firstWhere(
              (s) => ingredient.toLowerCase().contains(s.original.toLowerCase()),
              orElse: () => IngredientSubstitution(
                original: '',
                substitute: '',
                reason: '',
              ),
            );
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ingredient,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  if (substitution.substitute.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Substitute: ${substitution.substitute} - ${substitution.reason}',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildServingButton(BuildContext context, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }
}
