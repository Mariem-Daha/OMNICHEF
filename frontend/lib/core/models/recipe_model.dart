class Recipe {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String cuisine;
  final int prepTime;
  final int cookTime;
  final int servings;
  final int calories;
  final List<String> tags;
  final List<String> ingredients;
  final List<RecipeStep> steps;
  final NutritionInfo nutrition;
  final List<IngredientSubstitution> substitutions;
  final double rating;
  final int reviewCount;
  final bool isSaved;
  final String difficulty;
  final String chefName;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.cuisine,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    required this.calories,
    required this.tags,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    this.substitutions = const [],
    this.rating = 4.5,
    this.reviewCount = 0,
    this.isSaved = false,
    this.difficulty = 'Medium',
    this.chefName = 'Chef OMNICHEF',
  });

  int get totalTime => prepTime + cookTime;

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? cuisine,
    int? prepTime,
    int? cookTime,
    int? servings,
    int? calories,
    List<String>? tags,
    List<String>? ingredients,
    List<RecipeStep>? steps,
    NutritionInfo? nutrition,
    List<IngredientSubstitution>? substitutions,
    double? rating,
    int? reviewCount,
    bool? isSaved,
    String? difficulty,
    String? chefName,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      cuisine: cuisine ?? this.cuisine,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      tags: tags ?? this.tags,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      nutrition: nutrition ?? this.nutrition,
      substitutions: substitutions ?? this.substitutions,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isSaved: isSaved ?? this.isSaved,
      difficulty: difficulty ?? this.difficulty,
      chefName: chefName ?? this.chefName,
    );
  }

  // Backend base URL (same dart-define used by ApiService).
  static const String _backendBase = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  /// Rewrite an external image URL through the backend proxy so that
  /// CanvasKit/XHR fetches don't hit CORS restrictions.
  static String _proxyImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    // Already a relative or same-origin URL — no proxy needed.
    if (!raw.startsWith('http')) return raw;
    // Already points to our own backend — no proxy needed.
    if (raw.contains('omnichef-backend') || raw.contains('localhost') || raw.contains('127.0.0.1')) return raw;
    return '$_backendBase/recipes/global/image-proxy?url=${Uri.encodeComponent(raw)}';
  }

  /// Create Recipe from JSON (API response).
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: _proxyImageUrl(json['image_url'] ?? json['image'] ?? ''),
      cuisine: json['cuisine'] ?? 'Other',
      prepTime: json['prep_time'] ?? 0,
      cookTime: json['cook_time'] ?? 0,
      servings: json['servings'] ?? 4,
      calories: json['calories'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: (json['steps'] as List? ?? [])
          .map((s) => RecipeStep.fromJson(s))
          .toList(),
      nutrition: json['nutrition'] != null
          ? NutritionInfo.fromJson(json['nutrition'])
          : NutritionInfo(
              calories: json['calories'] ?? 0,
              protein: 0,
              carbs: 0,
              fat: 0,
              fiber: 0,
              sodium: 0,
              sugar: 0,
            ),
      substitutions: [],
      rating: _parseDouble(json['rating'], defaultValue: 4.5),
      reviewCount: json['review_count'] ?? 0,
      isSaved: json['is_saved'] ?? false,
      difficulty: json['difficulty'] ?? 'Medium',
      chefName: json['chef_name'] ?? 'Chef OMNICHEF',
    );
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Convert Recipe to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'cuisine': cuisine,
      'prep_time': prepTime,
      'cook_time': cookTime,
      'servings': servings,
      'calories': calories,
      'tags': tags,
      'ingredients': ingredients,
      'difficulty': difficulty,
      'chef_name': chefName,
      'rating': rating,
      'review_count': reviewCount,
    };
  }
}

class RecipeStep {
  final int stepNumber;
  final String instruction;
  final int? durationMinutes;
  final String? tip;

  RecipeStep({
    required this.stepNumber,
    required this.instruction,
    this.durationMinutes,
    this.tip,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      stepNumber: json['step_number'] ?? 0,
      instruction: json['instruction'] ?? '',
      durationMinutes: json['duration_minutes'],
      tip: json['tip'],
    );
  }
}

class NutritionInfo {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sodium;
  final double sugar;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.sugar,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: json['calories'] ?? 0,
      protein: _parseDouble(json['protein']),
      carbs: _parseDouble(json['carbs']),
      fat: _parseDouble(json['fat']),
      fiber: _parseDouble(json['fiber']),
      sodium: _parseDouble(json['sodium']),
      sugar: _parseDouble(json['sugar']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class IngredientSubstitution {
  final String original;
  final String substitute;
  final String reason;

  IngredientSubstitution({
    required this.original,
    required this.substitute,
    required this.reason,
  });
}
