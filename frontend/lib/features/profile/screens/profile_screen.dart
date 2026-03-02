import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../../core/widgets/chips.dart';
import '../../auth/screens/login_screen.dart';
import '../../recipes/screens/recipe_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final recipeProvider = context.watch<RecipeProvider>();
    final user = userProvider.user;
    
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Profile Banner Header
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.warmGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative pattern
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 40,
                      bottom: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                user?.name.isNotEmpty == true 
                                    ? user!.name[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? 'Guest User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? 'guest@omnichef.app',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.restaurant_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        user?.cookingSkill ?? 'Intermediate',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Edit button
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Stats Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          context,
                          '${recipeProvider.savedRecipes.length}',
                          'Saved',
                          Icons.bookmark_rounded,
                          AppColors.warning,
                          isDark,
                        ),
                      ),
                      _buildStatDivider(isDark),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          '${user?.recipesCooked ?? 0}',
                          'Cooked',
                          Icons.restaurant_rounded,
                          AppColors.accent,
                          isDark,
                        ),
                      ),
                      _buildStatDivider(isDark),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          '${user?.cookingStreak ?? 0}',
                          'Streak',
                          Icons.local_fire_department_rounded,
                          const Color(0xFFFF6B35),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            
            // Cooking Level & Streak Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _CookingProgressCard(
                  recipesCooked: user?.recipesCooked ?? 0,
                  streak: user?.cookingStreak ?? 0,
                  isDark: isDark,
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            
            // Health Quiz CTA
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _HealthQuizCard(isDark: isDark),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            
            // Health Needs Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildSection(
                  context,
                  'Health Needs',
                  Icons.healing_rounded,
                  isDark,
                  child: user?.healthFilters.isEmpty ?? true
                      ? Text(
                          'No health filters set',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: user!.healthFilters.map((filter) {
                            return HealthTag(label: filter);
                          }).toList(),
                        ),
                ),
              ),
            ),
            
            // Disliked Ingredients Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildSection(
                  context,
                  'Disliked Ingredients',
                  Icons.not_interested_rounded,
                  isDark,
                  child: user?.dislikedIngredients.isEmpty ?? true
                      ? Text(
                          'No disliked ingredients',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: user!.dislikedIngredients.map((ingredient) {
                            return IngredientChip(
                              ingredient: ingredient,
                              showRemove: false,
                            );
                          }).toList(),
                        ),
                ),
              ),
            ),
            
            // Recent Meals Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildSection(
                  context,
                  'Recent Meals',
                  Icons.history_rounded,
                  isDark,
                  child: recipeProvider.recentRecipes.isEmpty
                      ? Text(
                          'No recent meals',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Column(
                          children: recipeProvider.recentRecipes.take(3).map((recipe) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  color: AppColors.secondaryLight,
                                  child: Image.network(
                                    recipe.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.restaurant_rounded,
                                      color: AppColors.primary.withOpacity(0.3),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                recipe.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              subtitle: Text(
                                recipe.cuisine,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: isDark 
                                    ? AppColors.textTertiaryDark 
                                    : AppColors.textTertiaryLight,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecipeDetailScreen(recipe: recipe),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
            ),
            
            // Settings Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSettingRow(
                        context,
                        Icons.dark_mode_rounded,
                        'Dark Mode',
                        isDark,
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (_) => themeProvider.toggleTheme(),
                          activeColor: AppColors.primary,
                        ),
                      ),
                      
                      const Divider(height: 24),
                      
                      _buildSettingRow(
                        context,
                        Icons.notifications_rounded,
                        'Notifications',
                        isDark,
                        onTap: () {},
                      ),
                      
                      const Divider(height: 24),
                      
                      _buildSettingRow(
                        context,
                        Icons.language_rounded,
                        'Language',
                        isDark,
                        subtitle: 'English',
                        onTap: () {},
                      ),
                      
                      const Divider(height: 24),
                      
                      _buildSettingRow(
                        context,
                        Icons.help_outline_rounded,
                        'Help & Support',
                        isDark,
                        onTap: () {},
                      ),
                      
                      const Divider(height: 24),
                      
                      _buildSettingRow(
                        context,
                        Icons.info_outline_rounded,
                        'About',
                        isDark,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Logout button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: OutlinedButton(
                  onPressed: () {
                    userProvider.logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Log Out'),
                    ],
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 60,
      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    bool isDark, {
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context,
    IconData icon,
    String title,
    bool isDark, {
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          trailing ?? Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: isDark 
                ? AppColors.textTertiaryDark 
                : AppColors.textTertiaryLight,
          ),
        ],
      ),
    );
  }
}

// Cooking Progress Card with Level and Streak
class _CookingProgressCard extends StatelessWidget {
  final int recipesCooked;
  final int streak;
  final bool isDark;

  const _CookingProgressCard({
    required this.recipesCooked,
    required this.streak,
    required this.isDark,
  });

  String get levelTitle {
    if (recipesCooked >= 20) return 'Pro Chef';
    if (recipesCooked >= 5) return 'Intermediate';
    return 'Beginner';
  }

  Color get levelColor {
    if (recipesCooked >= 20) return const Color(0xFFFFD700); // Gold
    if (recipesCooked >= 5) return AppColors.accent;
    return AppColors.primary;
  }

  IconData get levelIcon {
    if (recipesCooked >= 20) return Icons.workspace_premium_rounded;
    if (recipesCooked >= 5) return Icons.trending_up_rounded;
    return Icons.emoji_events_outlined;
  }

  int get nextLevelTarget {
    if (recipesCooked >= 20) return recipesCooked; // Already max
    if (recipesCooked >= 5) return 20;
    return 5;
  }

  double get progress {
    if (recipesCooked >= 20) return 1.0;
    if (recipesCooked >= 5) return (recipesCooked - 5) / 15;
    return recipesCooked / 5;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            levelColor.withOpacity(0.15),
            levelColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: levelColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [levelColor, levelColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: levelColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(levelIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      levelTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: levelColor,
                      ),
                    ),
                    Text(
                      recipesCooked >= 20
                          ? 'Master level achieved!'
                          : '$recipesCooked / $nextLevelTarget recipes to next level',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark 
                            ? AppColors.textSecondaryDark 
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFF6B35),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: levelColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          // Level milestones
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMilestone('Beginner', '0-5', recipesCooked >= 0, const Color(0xFF4CAF50)),
              _buildMilestone('Intermediate', '5-20', recipesCooked >= 5, AppColors.accent),
              _buildMilestone('Pro', '20+', recipesCooked >= 20, const Color(0xFFFFD700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestone(String label, String range, bool achieved, Color color) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: achieved ? color : Colors.grey.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            achieved ? Icons.check_rounded : Icons.circle_outlined,
            color: achieved ? Colors.white : Colors.grey,
            size: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: achieved ? FontWeight.w600 : FontWeight.w400,
            color: achieved ? color : Colors.grey,
          ),
        ),
        Text(
          range,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

// Health Personalization Quiz Card
class _HealthQuizCard extends StatelessWidget {
  final bool isDark;

  const _HealthQuizCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHealthQuiz(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.heartHealthy.withOpacity(0.15),
              AppColors.diabetesFriendly.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.heartHealthy.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.heartHealthy, AppColors.diabetesFriendly],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Personalization Quiz',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Get personalized recipe recommendations',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark 
                          ? AppColors.textSecondaryDark 
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.heartHealthy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.heartHealthy,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHealthQuiz(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HealthQuizModal(),
    );
  }
}

// Health Quiz Modal
class _HealthQuizModal extends StatefulWidget {
  const _HealthQuizModal();

  @override
  State<_HealthQuizModal> createState() => _HealthQuizModalState();
}

class _HealthQuizModalState extends State<_HealthQuizModal> {
  int _currentQuestion = 0;
  final Map<String, dynamic> _answers = {};

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Do you have any dietary restrictions?',
      'type': 'multi',
      'options': ['Diabetes', 'Heart Condition', 'Hypertension', 'None'],
    },
    {
      'question': 'What are your health goals?',
      'type': 'multi',
      'options': ['Weight Loss', 'Build Muscle', 'More Energy', 'Better Digestion'],
    },
    {
      'question': 'How much time do you usually have to cook?',
      'type': 'single',
      'options': ['Under 15 min', '15-30 min', '30-60 min', 'More than 1 hour'],
    },
    {
      'question': 'Any allergies we should know about?',
      'type': 'multi',
      'options': ['Nuts', 'Dairy', 'Gluten', 'Shellfish', 'None'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = _questions[_currentQuestion];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Progress
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Question ${_currentQuestion + 1}/${_questions.length}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentQuestion + 1) / _questions.length,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          
          // Question
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question['question'],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question['type'] == 'multi' 
                        ? 'Select all that apply' 
                        : 'Select one',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark 
                          ? AppColors.textSecondaryDark 
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Options
                  Expanded(
                    child: ListView.separated(
                      itemCount: (question['options'] as List).length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final option = question['options'][index];
                        final key = 'q$_currentQuestion';
                        final isSelected = question['type'] == 'multi'
                            ? (_answers[key] as List?)?.contains(option) ?? false
                            : _answers[key] == option;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (question['type'] == 'multi') {
                                _answers[key] ??= <String>[];
                                final list = _answers[key] as List;
                                if (list.contains(option)) {
                                  list.remove(option);
                                } else {
                                  list.add(option);
                                }
                              } else {
                                _answers[key] = option;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : isDark 
                                      ? AppColors.cardDark 
                                      : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    shape: question['type'] == 'multi'
                                        ? BoxShape.rectangle
                                        : BoxShape.circle,
                                    borderRadius: question['type'] == 'multi'
                                        ? BorderRadius.circular(6)
                                        : null,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.grey,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  option,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: isSelected 
                                        ? FontWeight.w600 
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_currentQuestion > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _currentQuestion--);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentQuestion > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentQuestion < _questions.length - 1) {
                        setState(() => _currentQuestion++);
                      } else {
                        _submitQuiz();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _currentQuestion < _questions.length - 1 ? 'Next' : 'Complete',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitQuiz() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Health profile updated!'),
          ],
        ),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
