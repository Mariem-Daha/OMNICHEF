import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/animations.dart';

class IngredientScannerScreen extends StatefulWidget {
  const IngredientScannerScreen({super.key});

  @override
  State<IngredientScannerScreen> createState() => _IngredientScannerScreenState();
}

class _IngredientScannerScreenState extends State<IngredientScannerScreen> {
  final Set<String> _selectedIngredients = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Map<String, List<String>> _ingredientCategories = {
    'Proteins': [
      'Chicken',
      'Beef',
      'Lamb',
      'Fish',
      'Shrimp',
      'Eggs',
      'Tofu',
      'Lentils',
      'Chickpeas',
    ],
    'Vegetables': [
      'Onion',
      'Tomato',
      'Carrot',
      'Potato',
      'Bell Pepper',
      'Eggplant',
      'Zucchini',
      'Spinach',
      'Okra',
      'Cabbage',
    ],
    'Grains & Starches': [
      'Rice',
      'Couscous',
      'Bread',
      'Pasta',
      'Flour',
      'Semolina',
    ],
    'Spices & Herbs': [
      'Cumin',
      'Coriander',
      'Paprika',
      'Turmeric',
      'Cinnamon',
      'Ginger',
      'Garlic',
      'Parsley',
      'Cilantro',
      'Mint',
    ],
    'Dairy': [
      'Milk',
      'Butter',
      'Yogurt',
      'Cheese',
      'Cream',
    ],
    'Pantry': [
      'Olive Oil',
      'Vegetable Oil',
      'Tomato Paste',
      'Lemon',
      'Honey',
      'Sugar',
      'Salt',
      'Black Pepper',
    ],
  };

  List<String> get _allIngredients {
    return _ingredientCategories.values.expand((e) => e).toList();
  }

  List<String> get _filteredIngredients {
    if (_searchQuery.isEmpty) return [];
    return _allIngredients
        .where((i) => i.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _findRecipes() {
    if (_selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one ingredient'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Show results bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecipeSuggestionsSheet(
        ingredients: _selectedIngredients.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFDF6F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: TapScale(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        title: const Text(
          'Ingredient Scanner',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_selectedIngredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TapScale(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIngredients.clear()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search ingredients...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          // Selected ingredients chips
          if (_selectedIngredients.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _selectedIngredients.map((ingredient) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        ingredient,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: AppColors.primary,
                      deleteIcon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      onDeleted: () {
                        setState(() => _selectedIngredients.remove(ingredient));
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          if (_selectedIngredients.isNotEmpty) const SizedBox(height: 12),

          // Search results or categories
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(isDark)
                : _buildCategories(isDark),
          ),
        ],
      ),
      bottomNavigationBar: _selectedIngredients.isNotEmpty
          ? _buildFindRecipesButton(isDark)
          : null,
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_filteredIngredients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textTertiaryLight,
            ),
            const SizedBox(height: 12),
            Text(
              'No ingredients found',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredIngredients.length,
      itemBuilder: (context, index) {
        final ingredient = _filteredIngredients[index];
        final isSelected = _selectedIngredients.contains(ingredient);

        return _buildIngredientTile(ingredient, isSelected, isDark);
      },
    );
  }

  Widget _buildCategories(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _ingredientCategories.length,
      itemBuilder: (context, index) {
        final category = _ingredientCategories.keys.elementAt(index);
        final ingredients = _ingredientCategories[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ingredients.map((ingredient) {
                final isSelected = _selectedIngredients.contains(ingredient);
                return _buildIngredientChip(ingredient, isSelected, isDark);
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildIngredientTile(String ingredient, bool isSelected, bool isDark) {
    return TapScale(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedIngredients.remove(ingredient);
            } else {
              _selectedIngredients.add(ingredient);
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Text(
                ingredient,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : null,
                ),
              ),
              const Spacer(),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textTertiaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientChip(String ingredient, bool isSelected, bool isDark) {
    return TapScale(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedIngredients.remove(ingredient);
            } else {
              _selectedIngredients.add(ingredient);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              Text(
                ingredient,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindRecipesButton(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: TapScale(
        child: GestureDetector(
          onTap: _findRecipes,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.warmGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'Find Recipes (${_selectedIngredients.length} ingredients)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Recipe suggestions bottom sheet
class _RecipeSuggestionsSheet extends StatelessWidget {
  final List<String> ingredients;

  const _RecipeSuggestionsSheet({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Simulated recipe suggestions based on ingredients
    final suggestions = _generateSuggestions(ingredients);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.warmGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recipe Suggestions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Based on ${ingredients.length} ingredients',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final recipe = suggestions[index];
                return _buildRecipeSuggestionCard(context, recipe, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateSuggestions(List<String> ingredients) {
    // Simple suggestion logic
    final hasProtein = ingredients.any((i) =>
        ['Chicken', 'Beef', 'Lamb', 'Fish', 'Shrimp', 'Eggs'].contains(i));
    final hasRice = ingredients.contains('Rice');
    final hasVeggies = ingredients.any((i) =>
        ['Tomato', 'Onion', 'Carrot', 'Potato', 'Bell Pepper'].contains(i));

    List<Map<String, dynamic>> suggestions = [];

    if (hasProtein && hasRice) {
      suggestions.add({
        'name': 'Thieboudienne',
        'description': 'Classic Mauritanian fish and rice dish',
        'match': 95,
        'time': '60 min',
      });
    }
    if (ingredients.contains('Chicken') && ingredients.contains('Onion')) {
      suggestions.add({
        'name': 'Chicken Yassa',
        'description': 'Senegalese lemon-onion chicken',
        'match': 88,
        'time': '45 min',
      });
    }
    if (hasVeggies && ingredients.contains('Eggs')) {
      suggestions.add({
        'name': 'Shakshuka',
        'description': 'North African poached eggs in tomato sauce',
        'match': 82,
        'time': '25 min',
      });
    }
    if (ingredients.contains('Chickpeas')) {
      suggestions.add({
        'name': 'Hummus',
        'description': 'Creamy chickpea dip',
        'match': 90,
        'time': '15 min',
      });
    }
    if (hasVeggies) {
      suggestions.add({
        'name': 'Fattoush Salad',
        'description': 'Lebanese bread salad',
        'match': 75,
        'time': '20 min',
      });
    }

    // Always add some fallback suggestions
    if (suggestions.length < 3) {
      suggestions.addAll([
        {
          'name': 'Couscous Royal',
          'description': 'Traditional MENA grain dish',
          'match': 65,
          'time': '50 min',
        },
        {
          'name': 'Lentil Soup',
          'description': 'Hearty and nutritious',
          'match': 60,
          'time': '35 min',
        },
      ]);
    }

    return suggestions;
  }

  Widget _buildRecipeSuggestionCard(
      BuildContext context, Map<String, dynamic> recipe, bool isDark) {
    return TapScale(
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening ${recipe['name']}...'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : const Color(0xFFFFFBF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Match percentage
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.warmGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${recipe['match']}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe['description'],
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe['time'],
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
