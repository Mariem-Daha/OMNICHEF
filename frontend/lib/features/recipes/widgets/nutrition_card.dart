import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/recipe_model.dart';

class NutritionCard extends StatelessWidget {
  final NutritionInfo nutrition;

  const NutritionCard({
    super.key,
    required this.nutrition,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calories center
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularPercentIndicator(
                  radius: 70,
                  lineWidth: 10,
                  percent: (nutrition.calories / 2000).clamp(0, 1),
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${nutrition.calories}',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'kcal',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  progressColor: AppColors.primary,
                  backgroundColor: isDark 
                      ? AppColors.dividerDark 
                      : AppColors.dividerLight,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                const SizedBox(width: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMacroRow(
                      context,
                      'Protein',
                      '${nutrition.protein.toInt()}g',
                      AppColors.accent,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                      context,
                      'Carbs',
                      '${nutrition.carbs.toInt()}g',
                      AppColors.secondary,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                      context,
                      'Fat',
                      '${nutrition.fat.toInt()}g',
                      AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Detailed nutrition
          Text(
            'Nutrition Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          
          const SizedBox(height: 16),
          
          _buildNutritionRow(context, 'Protein', '${nutrition.protein}g', isDark),
          _buildNutritionRow(context, 'Carbohydrates', '${nutrition.carbs}g', isDark),
          _buildNutritionRow(context, 'Fat', '${nutrition.fat}g', isDark),
          _buildNutritionRow(context, 'Fiber', '${nutrition.fiber}g', isDark),
          _buildNutritionRow(context, 'Sodium', '${nutrition.sodium}mg', isDark),
          _buildNutritionRow(context, 'Sugar', '${nutrition.sugar}g', isDark),
          
          const SizedBox(height: 24),
          
          // Health note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.info.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nutritional values are estimates and may vary based on portion sizes and ingredient substitutions.',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMacroRow(BuildContext context, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildNutritionRow(BuildContext context, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
