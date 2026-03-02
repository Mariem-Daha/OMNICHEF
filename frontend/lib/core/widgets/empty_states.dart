import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Empty state types for different scenarios
enum EmptyStateType {
  noSavedRecipes,
  noRecentMeals,
  noLeftovers,
  noSearchResults,
  noRecipes,
  noMessages,
  noNotifications,
}

class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String? customTitle;
  final String? customMessage;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateWidget({
    super.key,
    required this.type,
    this.customTitle,
    this.customMessage,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _getConfig();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated illustration container
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    config.color.withOpacity(0.1),
                    config.color.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        config.color.withOpacity(0.15),
                        config.color.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    config.icon,
                    size: 48,
                    color: config.color.withOpacity(0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Title
            Text(
              customTitle ?? config.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Message
            Text(
              customMessage ?? config.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Action button
            if (onAction != null) ...[
              const SizedBox(height: 28),
              _buildActionButton(context, config),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, _EmptyStateConfig config) {
    return GestureDetector(
      onTap: onAction,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [config.color, config.color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: config.color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              config.actionIcon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              actionLabel ?? config.actionLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _EmptyStateConfig _getConfig() {
    switch (type) {
      case EmptyStateType.noSavedRecipes:
        return _EmptyStateConfig(
          icon: Icons.bookmark_outline_rounded,
          title: 'No Saved Recipes Yet',
          message: 'Start exploring and save your favorite recipes to access them quickly anytime.',
          actionLabel: 'Explore Recipes',
          actionIcon: Icons.explore_rounded,
          color: AppColors.warning,
        );
      case EmptyStateType.noRecentMeals:
        return _EmptyStateConfig(
          icon: Icons.restaurant_outlined,
          title: 'No Recent Meals',
          message: 'Your cooking history will appear here. Let\'s cook something delicious!',
          actionLabel: 'Start Cooking',
          actionIcon: Icons.play_arrow_rounded,
          color: AppColors.primary,
        );
      case EmptyStateType.noLeftovers:
        return _EmptyStateConfig(
          icon: Icons.eco_outlined,
          title: 'No Ingredients Added',
          message: 'Tell us what ingredients you have, and we\'ll suggest amazing recipes for you.',
          actionLabel: 'Add Ingredients',
          actionIcon: Icons.add_rounded,
          color: AppColors.accent,
        );
      case EmptyStateType.noSearchResults:
        return _EmptyStateConfig(
          icon: Icons.search_off_rounded,
          title: 'No Results Found',
          message: 'We couldn\'t find any recipes matching your search. Try different keywords.',
          actionLabel: 'Clear Search',
          actionIcon: Icons.refresh_rounded,
          color: AppColors.info,
        );
      case EmptyStateType.noRecipes:
        return _EmptyStateConfig(
          icon: Icons.menu_book_outlined,
          title: 'No Recipes Available',
          message: 'Check back soon! We\'re adding new authentic recipes regularly.',
          actionLabel: 'Refresh',
          actionIcon: Icons.refresh_rounded,
          color: AppColors.secondary,
        );
      case EmptyStateType.noMessages:
        return _EmptyStateConfig(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Start a Conversation',
          message: 'Ask me anything about cooking, recipes, or get personalized suggestions.',
          actionLabel: 'Say Hello',
          actionIcon: Icons.waving_hand_rounded,
          color: AppColors.primary,
        );
      case EmptyStateType.noNotifications:
        return _EmptyStateConfig(
          icon: Icons.notifications_none_rounded,
          title: 'All Caught Up!',
          message: 'You\'re all caught up. New cooking tips and updates will appear here.',
          actionLabel: 'Browse Recipes',
          actionIcon: Icons.explore_rounded,
          color: AppColors.accent,
        );
    }
  }
}

class _EmptyStateConfig {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final Color color;

  const _EmptyStateConfig({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.color,
  });
}

/// Compact empty state for inline use
class CompactEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const CompactEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Text(
            message,
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
