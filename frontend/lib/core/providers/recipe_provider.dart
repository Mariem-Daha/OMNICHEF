import 'package:flutter/material.dart';
import '../models/recipe_model.dart';
import '../services/api_service.dart';
import '../data/dummy_recipes.dart';
class RecipeProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<Recipe> _recipes = [];
  List<Recipe> _mauritanianRecipes = [];
  List<Recipe> _menaRecipes = [];
  List<Recipe> _globalRecipes = [];
  List<Recipe> _savedRecipes = [];
  List<Recipe> _recentRecipes = [];
  List<String> _selectedHealthFilters = [];
  List<String> _leftoverIngredients = [];
  bool _isLoading = false;
  bool _isLoadingMauritanian = false;
  bool _isLoadingMena = false;
  bool _isLoadingMore = false;
  bool _isLoadingGlobal = false;
  String? _error;
  int _globalTotalResults = 0;
  String _globalSearchQuery = '';
  String _globalCuisineFilter = '';
  
  // Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecipes = 0;
  static const int _perPage = 20;

  List<Recipe> get recipes => _recipes;
  List<Recipe> get mauritanianRecipes => _mauritanianRecipes;
  List<Recipe> get menaRecipes => _menaRecipes;
  List<Recipe> get globalRecipes => _globalRecipes;
  List<Recipe> get savedRecipes => _savedRecipes;
  List<Recipe> get recentRecipes => _recentRecipes;
  List<String> get selectedHealthFilters => _selectedHealthFilters;
  List<String> get leftoverIngredients => _leftoverIngredients;
  bool get isLoading => _isLoading || _isLoadingMauritanian || _isLoadingMena;
  bool get isLoadingMena => _isLoadingMena;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingGlobal => _isLoadingGlobal;
  int get globalTotalResults => _globalTotalResults;
  bool get hasMoreGlobalRecipes => _globalRecipes.length < _globalTotalResults;
  String? get error => _error;
  
  // Pagination getters
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalRecipes => _totalRecipes;
  bool get hasMoreRecipes => _currentPage < _totalPages;

  RecipeProvider() {
    loadRecipes();
    loadMauritanianRecipes();
    loadMenaRecipes();
    loadGlobalRecipes();
  }

  /// Load initial recipes from API (resets pagination).
  Future<void> loadRecipes() async {
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    notifyListeners();
    
    try {
      final result = await _api.getRecipes(page: 1, perPage: _perPage);
      _recipes = result.recipes;
      _totalPages = result.pages;
      _totalRecipes = result.total;
      _currentPage = result.page;
      _savedRecipes = _recipes.where((r) => r.isSaved).toList();
      _error = null;
    } catch (e) {
      _error = 'Failed to load recipes: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load more recipes (next page) for infinite scroll.
  Future<void> loadMoreRecipes() async {
    if (_isLoadingMore || !hasMoreRecipes) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final nextPage = _currentPage + 1;
      final result = await _api.getRecipes(page: nextPage, perPage: _perPage);
      
      // Append new recipes to existing list
      _recipes.addAll(result.recipes);
      _currentPage = result.page;
      _totalPages = result.pages;
      _totalRecipes = result.total;
      
      // Update saved recipes list
      _savedRecipes = _recipes.where((r) => r.isSaved).toList();
      _error = null;
    } catch (e) {
      _error = 'Failed to load more recipes: $e';
      debugPrint(_error);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Load saved recipes from API (requires auth).
  Future<void> loadSavedRecipes() async {
    if (!_api.isAuthenticated) return;
    
    try {
      _savedRecipes = await _api.getSavedRecipes();
      // Update isSaved flag on recipes
      for (var saved in _savedRecipes) {
        final index = _recipes.indexWhere((r) => r.id == saved.id);
        if (index != -1) {
          _recipes[index] = _recipes[index].copyWith(isSaved: true);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load saved recipes: $e');
    }
  }

  Recipe? get dailySuggestion {
    return Recipe(
      id: 'daily_perfect_dish',
      name: 'Wagyu Beef Medallions',
      description: 'Melt-in-your-mouth Wagyu beef medallions seared to perfection, served with a rich red wine reduction and truffle mash.',
      imageUrl: 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=1200&q=100', // Premium Steak Photo
      cuisine: 'French',
      prepTime: 45,
      cookTime: 90,
      servings: 4,
      calories: 850,
      tags: ['Premium', 'High Protein', 'Glazed', 'Mouth-watering'],
      ingredients: [
        '1 premium lamb crown roast (about 2 lbs)',
        '2 tbsp Ras el Hanout (Moroccan spice blend)',
        '3 tbsp extra virgin olive oil',
        '1/2 cup pomegranate molasses',
        'Fresh mint and cilantro for garnish'
      ],
      steps: [
        RecipeStep(stepNumber: 1, instruction: 'Preheat oven to 375°F. Rub the roast with olive oil and spices.', durationMinutes: 10),
        RecipeStep(stepNumber: 2, instruction: 'Roast for 60 minutes, brushing with pomegranate molasses every 20 minutes.', durationMinutes: 60),
        RecipeStep(stepNumber: 3, instruction: 'Rest for 15 minutes before carving.', durationMinutes: 15),
      ],
      nutrition: NutritionInfo(
        calories: 850,
        protein: 45.0,
        carbs: 12.0,
        fat: 65.0,
        fiber: 2.0,
        sodium: 450.0,
        sugar: 8.0,
      ),
      difficulty: 'Hard',
    );
  }

  /// Load Mauritanian recipes from API.
  Future<void> loadMauritanianRecipes() async {
    _isLoadingMauritanian = true;
    notifyListeners();
    try {
      _mauritanianRecipes = await _api.getRecipesByCuisine('Mauritanian');
    } catch (e) {
      debugPrint('Failed to load Mauritanian recipes: $e');
    } finally {
      _isLoadingMauritanian = false;
      notifyListeners();
    }
  }

  /// Load MENA recipes from API.
  Future<void> loadMenaRecipes() async {
    _isLoadingMena = true;
    notifyListeners();
    try {
      final results = await _api.getRecipesByCuisine('MENA');
      _menaRecipes = results.where((r) => r.cuisine.toLowerCase() != 'mauritania' && r.cuisine.toLowerCase() != 'mauritanian').toList();
    } catch (e) {
      debugPrint('Failed to load MENA recipes: $e');
    } finally {
      _isLoadingMena = false;
      notifyListeners();
    }
  }

  /// Load global recipes via Spoonacular (initial random load).
  Future<void> loadGlobalRecipes({bool refresh = false}) async {
    if (_isLoadingGlobal) return;
    if (!refresh && _globalRecipes.isNotEmpty) return;

    _isLoadingGlobal = true;
    _globalSearchQuery = '';
    _globalCuisineFilter = '';
    notifyListeners();
    try {
      _globalRecipes = await _api.getRandomGlobalRecipes(number: 20);
      _globalTotalResults = _globalRecipes.length;
    } catch (e) {
      debugPrint('Failed to load global recipes: $e');
    } finally {
      _isLoadingGlobal = false;
      notifyListeners();
    }
  }

  /// Search global recipes via Spoonacular.
  Future<void> searchGlobalRecipes({
    String query = '',
    String cuisine = '',
    List<String> healthTags = const [],
  }) async {
    _isLoadingGlobal = true;
    _globalSearchQuery = query;
    _globalCuisineFilter = cuisine;
    notifyListeners();
    try {
      final result = await _api.searchGlobalRecipes(
        query: query,
        cuisine: cuisine,
        healthTags: healthTags.isNotEmpty ? healthTags : _selectedHealthFilters,
        number: 20,
        offset: 0,
      );
      _globalRecipes = result.results;
      _globalTotalResults = result.totalResults;
    } catch (e) {
      debugPrint('Failed to search global recipes: $e');
    } finally {
      _isLoadingGlobal = false;
      notifyListeners();
    }
  }

  /// Load more global recipes (pagination).
  Future<void> loadMoreGlobalRecipes() async {
    if (_isLoadingGlobal || !hasMoreGlobalRecipes) return;

    _isLoadingGlobal = true;
    notifyListeners();
    try {
      final nextOffset = _globalRecipes.length;
      final result = await _api.searchGlobalRecipes(
        query: _globalSearchQuery,
        cuisine: _globalCuisineFilter,
        healthTags: _selectedHealthFilters,
        number: 20,
        offset: nextOffset,
      );
      _globalRecipes.addAll(result.results);
      _globalTotalResults = result.totalResults;
    } catch (e) {
      debugPrint('Failed to load more global recipes: $e');
    } finally {
      _isLoadingGlobal = false;
      notifyListeners();
    }
  }

  List<Recipe> getFilteredRecipes() {
    if (_selectedHealthFilters.isEmpty) return _recipes;
    
    return _recipes.where((recipe) {
      return _selectedHealthFilters.every((filter) => recipe.tags.contains(filter));
    }).toList();
  }

  /// Get recipes by leftover ingredients from API.
  Future<List<Recipe>> getRecipesByLeftoversFromApi() async {
    if (_leftoverIngredients.isEmpty) return _recipes;
    
    try {
      final results = await _api.getRecipesByLeftovers(_leftoverIngredients);
      return results.where((r) => r.cuisine.toLowerCase() != 'mauritania' && r.cuisine.toLowerCase() != 'mauritanian').toList();
    } catch (e) {
      debugPrint('Failed to get recipes by leftovers: $e');
      return getRecipesByLeftovers();
    }
  }

  List<Recipe> getRecipesByLeftovers() {
    if (_leftoverIngredients.isEmpty) return _recipes;
    
    return _recipes.where((recipe) {
      int matchCount = recipe.ingredients
          .where((ing) => _leftoverIngredients.any(
              (leftover) => ing.toLowerCase().contains(leftover.toLowerCase())))
          .length;
      return matchCount >= 2;
    }).toList();
  }

  /// Search recipes via API.
  Future<List<Recipe>> searchRecipes(String query) async {
    if (query.isEmpty) return _recipes;
    
    try {
      final results = await _api.searchRecipes(query);
      return results.where((r) => r.cuisine.toLowerCase() != 'mauritania' && r.cuisine.toLowerCase() != 'mauritanian').toList();
    } catch (e) {
      debugPrint('Search failed: $e');
      // Fallback to local search
      return _recipes.where((r) => 
        r.name.toLowerCase().contains(query.toLowerCase()) ||
        r.description.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }
  }

  /// Get recipes by tags from API.
  Future<List<Recipe>> getRecipesByTagsFromApi() async {
    if (_selectedHealthFilters.isEmpty) return _recipes;
    
    try {
      final results = await _api.getRecipesByTags(_selectedHealthFilters);
      return results.where((r) => r.cuisine.toLowerCase() != 'mauritania' && r.cuisine.toLowerCase() != 'mauritanian').toList();
    } catch (e) {
      debugPrint('Failed to filter by tags: $e');
      return getFilteredRecipes();
    }
  }

  void toggleHealthFilter(String filter) {
    if (_selectedHealthFilters.contains(filter)) {
      _selectedHealthFilters.remove(filter);
    } else {
      _selectedHealthFilters.add(filter);
    }
    notifyListeners();
  }

  void clearHealthFilters() {
    _selectedHealthFilters.clear();
    notifyListeners();
  }

  void addLeftoverIngredient(String ingredient) {
    if (!_leftoverIngredients.contains(ingredient)) {
      _leftoverIngredients.add(ingredient);
      notifyListeners();
    }
  }

  void removeLeftoverIngredient(String ingredient) {
    _leftoverIngredients.remove(ingredient);
    notifyListeners();
  }

  void clearLeftovers() {
    _leftoverIngredients.clear();
    notifyListeners();
  }

  /// Toggle save/unsave recipe via API.
  Future<void> toggleSaveRecipe(Recipe recipe) async {
    final index = _recipes.indexWhere((r) => r.id == recipe.id);
    if (index == -1) return;

    final newSavedState = !recipe.isSaved;
    
    // Optimistic update
    _recipes[index] = recipe.copyWith(isSaved: newSavedState);
    _savedRecipes = _recipes.where((r) => r.isSaved).toList();
    notifyListeners();

    // Sync with API if authenticated
    if (_api.isAuthenticated) {
      try {
        if (newSavedState) {
          await _api.saveRecipe(recipe.id);
        } else {
          await _api.unsaveRecipe(recipe.id);
        }
      } catch (e) {
        // Revert on failure
        _recipes[index] = recipe.copyWith(isSaved: !newSavedState);
        _savedRecipes = _recipes.where((r) => r.isSaved).toList();
        notifyListeners();
        debugPrint('Failed to sync save state: $e');
      }
    }
  }

  void addToRecentRecipes(Recipe recipe) {
    _recentRecipes.removeWhere((r) => r.id == recipe.id);
    _recentRecipes.insert(0, recipe);
    if (_recentRecipes.length > 10) {
      _recentRecipes = _recentRecipes.take(10).toList();
    }
    notifyListeners();
  }
}
