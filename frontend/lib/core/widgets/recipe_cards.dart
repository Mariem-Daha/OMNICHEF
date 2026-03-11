import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_colors.dart';
import '../models/recipe_model.dart';
import '../utils/animations.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final bool isHorizontal;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onSave,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isHorizontal) {
      return _buildHorizontalCard(context, isDark);
    }
    return _buildVerticalCard(context, isDark);
  }

  Widget _buildVerticalCard(BuildContext context, bool isDark) {
    return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Section - Upper half
                    Expanded(
                      flex: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            child: Image.network(
                              recipe.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? AppColors.surfaceDark : AppColors.dividerLight,
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  size: 40,
                                  color: AppColors.textTertiaryLight,
                                ),
                              ),
                            ),
                          ),
                          // Subtle Gradient Overlay at top for better badge contrast
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Badges
                          Positioned(
                            top: 12,
                            left: 12,
                            child: _buildGlassBadge(
                              child: Text(
                                recipe.cuisine,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _buildSaveButton(isDark, glass: true),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content Section - Lower half
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                                    const SizedBox(width: 4),
                                    Text(
                                      recipe.rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? Colors.white24 : Colors.black12,
                                      ),
                                    ),
                                    Text(
                                      '${recipe.calories} cal',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            // Bottom Action / Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${recipe.totalTime} min',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: AppColors.primary,
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
            ),
    );
  }

  // Refined Horizontal Card (Used in lists if needed)
  Widget _buildHorizontalCard(BuildContext context, bool isDark) {
    return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 300,
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                            child: Image.network(
                              recipe.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: _buildGlassBadge(
                              child: Text(
                                recipe.cuisine,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                                    const SizedBox(width: 4),
                                    Text(
                                      recipe.rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                                _buildSaveButton(isDark, size: 32, iconSize: 16),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              recipe.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                             Text(
                              '${recipe.calories} cal â€¢ ${recipe.totalTime} min',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ),
    );
  }

  Widget _buildGlassBadge({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isDark, {bool glass = false, double size = 36, double iconSize = 20}) {
    return TapScale(
      child: GestureDetector(
        onTap: onSave,
        child: glass 
          ? _buildGlassBadge(
              child: Icon(
                recipe.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: iconSize,
                color: recipe.isSaved ? AppColors.primary : Colors.white,
              ),
            )
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                recipe.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: iconSize,
                color: recipe.isSaved ? AppColors.primary : AppColors.textTertiaryLight,
              ),
            ),
      ),
    );
  }
}

class DailySuggestionCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const DailySuggestionCard({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondaryLight,
                        AppColors.primary.withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Image.network(
                    recipe.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 60,
                        color: AppColors.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.warmGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      const Text(
                        "Today's Pick",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        recipe.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: AppColors.textPrimaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        recipe.cuisine,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recipe.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildInfoChip(Icons.schedule_rounded, '${recipe.totalTime} min'),
                        const SizedBox(width: 16),
                        _buildInfoChip(Icons.local_fire_department_rounded, '${recipe.calories} cal'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'View Recipe',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
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
}

/// Compact recipe card for grid layouts - smaller footprint
class CompactRecipeCard extends StatelessWidget {
  final dynamic recipe;
  final VoidCallback? onTap;
  final VoidCallback? onSave;

  const CompactRecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TapScale(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.10), // Stronger shadow
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: AppColors.primary.withOpacity(isDark ? 0.05 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.secondaryLight,
                              AppColors.primary.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Image.network(
                          recipe.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.restaurant_rounded,
                              size: 24,
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Time badge
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 9, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              '${recipe.totalTime}m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Save button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onSave,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.cardDark : Colors.white).withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            recipe.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 12,
                            color: recipe.isSaved ? AppColors.primary : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        recipe.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 10,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${recipe.calories}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.star_rounded, size: 10, color: AppColors.warning),
                              const SizedBox(width: 1),
                              Text(
                                recipe.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
