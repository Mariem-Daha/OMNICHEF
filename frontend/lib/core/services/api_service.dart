import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';
import '../models/user_model.dart';

/// API Service for communicating with the OMNICHEF backend.
class ApiService {
  // Base URL can be configured via --dart-define=API_URL=...
  // Default to production Cloud Run backend
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://omnichef-backend-684753541076.us-central1.run.app/api',
  );

  /// Exposed for WebSocket consumers that need to derive wss:// URLs.
  static String get baseUrl => _baseUrl;

  static const _tokenKey = 'auth_token';

  String? _token;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  /// Initialize service and load stored token.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }
  
  /// Get authorization headers.
  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }
  
  /// Handle API response and throw on error.
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    
    final error = response.body.isNotEmpty 
        ? jsonDecode(response.body)['detail'] ?? 'Unknown error'
        : 'Request failed with status ${response.statusCode}';
    throw ApiException(error, response.statusCode);
  }

  // ============ AUTH ============
  
  /// Register a new user account.
  Future<AuthResult> register(String email, String password, String name) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
      }),
    );
    
    final data = _handleResponse(response);
    final token = data['token']['access_token'];
    await _saveToken(token);
    
    return AuthResult(
      user: UserModel.fromJson(data['user']),
      token: token,
    );
  }
  
  /// Login with email and password.
  Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    
    final data = _handleResponse(response);
    final token = data['token']['access_token'];
    await _saveToken(token);
    
    return AuthResult(
      user: UserModel.fromJson(data['user']),
      token: token,
    );
  }
  
  /// Get current authenticated user.
  Future<UserModel?> getCurrentUser() async {
    if (_token == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: _headers,
      );
      
      final data = _handleResponse(response);
      return UserModel.fromJson(data);
    } catch (e) {
      await logout();
      return null;
    }
  }
  
  /// Logout and clear stored token.
  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
  
  /// Check if user is authenticated.
  bool get isAuthenticated => _token != null;
  
  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // ============ RECIPES ============
  
  /// Get all recipes with pagination.
  Future<RecipeListResult> getRecipes({int page = 1, int perPage = 20}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes?page=$page&per_page=$perPage'),
      headers: _headers,
    );
    
    final data = _handleResponse(response);
    return RecipeListResult.fromJson(data);
  }
  
  /// Get a single recipe by ID.
  Future<Recipe> getRecipeById(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/$id'),
      headers: _headers,
    );
    
    final data = _handleResponse(response);
    return Recipe.fromJson(data);
  }
  
  /// Search recipes by query.
  Future<List<Recipe>> searchRecipes(String query) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/search?q=${Uri.encodeComponent(query)}'),
      headers: _headers,
    );
    
    final data = _handleResponse(response) as List;
    return data.map((json) => Recipe.fromJson(json)).toList();
  }
  
  /// Get recipes by cuisine type.
  Future<List<Recipe>> getRecipesByCuisine(String cuisine) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/cuisine/${Uri.encodeComponent(cuisine)}'),
      headers: _headers,
    );
    
    final data = _handleResponse(response) as List;
    return data.map((json) => Recipe.fromJson(json)).toList();
  }
  
  /// Get recipes by health tags.
  Future<List<Recipe>> getRecipesByTags(List<String> tags) async {
    final tagsParam = tags.map((t) => 'tags=${Uri.encodeComponent(t)}').join('&');
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/tags?$tagsParam'),
      headers: _headers,
    );
    
    final data = _handleResponse(response) as List;
    return data.map((json) => Recipe.fromJson(json)).toList();
  }
  
  /// Get recipes matching available ingredients.
  Future<List<Recipe>> getRecipesByLeftovers(List<String> ingredients) async {
    final ingredientsParam = ingredients.map((i) => 'ingredients=${Uri.encodeComponent(i)}').join('&');
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/leftovers?$ingredientsParam'),
      headers: _headers,
    );
    
    final data = _handleResponse(response) as List;
    return data.map((json) => Recipe.fromJson(json)).toList();
  }

  // ============ GLOBAL RECIPES (Spoonacular) ============

  /// Search global recipes via Spoonacular with full nutrition + health filters.
  Future<GlobalSearchResult> searchGlobalRecipes({
    String query = '',
    String cuisine = '',
    String diet = '',
    String intolerances = '',
    List<String> healthTags = const [],
    int number = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{};
    if (query.isNotEmpty) params['q'] = query;
    if (cuisine.isNotEmpty) params['cuisine'] = cuisine;
    if (diet.isNotEmpty) params['diet'] = diet;
    if (intolerances.isNotEmpty) params['intolerances'] = intolerances;
    if (number != 20) params['number'] = number.toString();
    if (offset != 0) params['offset'] = offset.toString();

    String tagsQuery = healthTags.map((t) => 'health_tags=${Uri.encodeComponent(t)}').join('&');
    String baseParams = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    String fullQuery = [baseParams, tagsQuery].where((s) => s.isNotEmpty).join('&');

    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/global/search?$fullQuery'),
      headers: _headers,
    );

    final data = _handleResponse(response) as Map<String, dynamic>;
    return GlobalSearchResult(
      results: (data['results'] as List).map((j) => Recipe.fromJson(j)).toList(),
      totalResults: data['totalResults'] ?? 0,
    );
  }

  /// Get a random set of global recipes with full nutrition.
  Future<List<Recipe>> getRandomGlobalRecipes({int number = 12, String tags = ''}) async {
    final params = 'number=$number${tags.isNotEmpty ? '&tags=${Uri.encodeComponent(tags)}' : ''}';
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/global/random?$params'),
      headers: _headers,
    );

    final data = _handleResponse(response) as List;
    return data.map((json) => Recipe.fromJson(json)).toList();
  }

  /// Get a single Spoonacular recipe by its numeric ID.
  Future<Recipe> getGlobalRecipeById(int spoonacularId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/global/$spoonacularId'),
      headers: _headers,
    );

    final data = _handleResponse(response);
    return Recipe.fromJson(data as Map<String, dynamic>);
  }

  /// Find global recipes matching available ingredients.
  Future<List<Recipe>> getGlobalRecipesByLeftovers(List<String> ingredients) async {
    final ingsParam = ingredients.map((i) => 'ingredients=${Uri.encodeComponent(i)}').join('&');
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/global/leftovers?$ingsParam'),
      headers: _headers,
    );

    final data = _handleResponse(response) as List;
    return data.map((json) => Recipe.fromJson(json)).toList();
  }
  
  /// Get user profile.
  Future<UserModel> getProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/profile'),
      headers: _headers,
    );
    
    final data = _handleResponse(response);
    return UserModel.fromJson(data);
  }
  
  /// Update user profile.
  Future<UserModel> updateProfile(Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users/profile'),
      headers: _headers,
      body: jsonEncode(updates),
    );
    
    final data = _handleResponse(response);
    return UserModel.fromJson(data);
  }
  
  /// Get personalised recipe recommendations based on user preferences.
  Future<List<Recipe>> getRecommendations({
    List<String> preferences = const [],
    List<String> allergies = const [],
    List<String> disliked = const [],
    int limit = 10,
  }) async {
    final params = <String>[];
    for (final p in preferences) {
      params.add('preferences=${Uri.encodeComponent(p)}');
    }
    for (final a in allergies) {
      params.add('allergies=${Uri.encodeComponent(a)}');
    }
    for (final d in disliked) {
      params.add('disliked=${Uri.encodeComponent(d)}');
    }
    params.add('limit=$limit');

    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/recommendations?${params.join('&')}'),
      headers: _headers,
    );

    final data = _handleResponse(response) as List;
    return data.map((json) => Recipe.fromJson(json)).toList();
  }

  /// Get saved recipes.
  Future<List<Recipe>> getSavedRecipes() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/saved-recipes'),
      headers: _headers,
    );
    
    final data = _handleResponse(response) as List;
    return data.map((json) => Recipe.fromJson(json)).toList();
  }
  
  /// Save a recipe.
  Future<void> saveRecipe(String recipeId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/saved-recipes/$recipeId'),
      headers: _headers,
    );
    
    _handleResponse(response);
  }
  
  /// Unsave a recipe.
  Future<void> unsaveRecipe(String recipeId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/saved-recipes/$recipeId'),
      headers: _headers,
    );
    
    _handleResponse(response);
  }

  // ============ AI CHAT ============
  
  /// Send a message to the AI cooking assistant.
  /// Returns the AI's response message.
  Future<String> chat(String message, {List<Map<String, dynamic>>? conversationHistory}) async {
    final Map<String, dynamic> body = {
      'message': message,
    };
    
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      body['conversation_history'] = conversationHistory.map((msg) => {
        'content': msg['content'],
        'is_user': msg['is_user'],
      }).toList();
    }
    
    final response = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw ApiException('Request timed out. Please check your connection.', 408),
    );
    
    final data = _handleResponse(response);
    return (data['response'] as String?) ?? '';
  }
  
  /// Check if the AI service is healthy.
  Future<bool> checkAiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/chat/health'),
        headers: _headers,
      );
      
      final data = _handleResponse(response);
      return data['model_available'] == true;
    } catch (e) {
      return false;
    }
  }

  // ============ VISION AI ============

  /// Scan an image to identify ingredients and find matching recipes.
  Future<IngredientScanResult> scanIngredients(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final b64 = base64Encode(imageBytes);
    final response = await http.post(
      Uri.parse('$_baseUrl/vision/scan-ingredients'),
      headers: _headers,
      body: jsonEncode({'image_b64': b64, 'mime_type': mimeType}),
    );
    final data = _handleResponse(response);
    return IngredientScanResult.fromJson(data);
  }

  /// Identify a cooked dish from an image and find the matching recipe.
  Future<DishIdentifyResult> identifyDish(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final b64 = base64Encode(imageBytes);
    final response = await http.post(
      Uri.parse('$_baseUrl/vision/identify-dish'),
      headers: _headers,
      body: jsonEncode({'image_b64': b64, 'mime_type': mimeType}),
    );
    final data = _handleResponse(response);
    return DishIdentifyResult.fromJson(data);
  }

  /// Returns the WebSocket URL for the AI cooking companion (vision + audio).
  String get visionCompanionWsUrl {
    // Convert http(s) base URL to ws(s) and point to companion endpoint
    final wsBase = _baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/vision/ws/companion';
  }
}

/// Result from authentication operations.
class AuthResult {
  final UserModel user;
  final String token;
  
  AuthResult({required this.user, required this.token});
}

/// Result from paginated recipe list.
class RecipeListResult {
  final List<Recipe> recipes;
  final int total;
  final int page;
  final int perPage;
  final int pages;
  
  RecipeListResult({
    required this.recipes,
    required this.total,
    required this.page,
    required this.perPage,
    required this.pages,
  });
  
  factory RecipeListResult.fromJson(Map<String, dynamic> json) {
    return RecipeListResult(
      recipes: (json['recipes'] as List).map((r) => Recipe.fromJson(r)).toList(),
      total: json['total'],
      page: json['page'],
      perPage: json['per_page'],
      pages: json['pages'],
    );
  }
}

/// API exception with error message and status code.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  
  ApiException(this.message, this.statusCode);
  
  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Result from Spoonacular global recipe search.
class GlobalSearchResult {
  final List<Recipe> results;
  final int totalResults;

  GlobalSearchResult({required this.results, required this.totalResults});
}

// ══════════════════════════════════════════════════════════════════════════════
// Vision AI result models
// ══════════════════════════════════════════════════════════════════════════════

/// Result from the ingredient scanner endpoint.
class IngredientScanResult {
  final List<String> ingredients;
  final List<String> quantities;
  final List<String> healthNotes;
  final List<Recipe> recipes;

  IngredientScanResult({
    required this.ingredients,
    required this.quantities,
    required this.healthNotes,
    required this.recipes,
  });

  factory IngredientScanResult.fromJson(Map<String, dynamic> json) {
    return IngredientScanResult(
      ingredients: List<String>.from(json['ingredients'] ?? []),
      quantities: List<String>.from(json['quantities'] ?? []),
      healthNotes: List<String>.from(json['health_notes'] ?? []),
      recipes: ((json['recipes'] ?? []) as List)
          .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Result from the dish identification endpoint.
class DishIdentifyResult {
  final String dishName;
  final String cuisine;
  final double confidence;
  final String description;
  final List<String> healthTags;
  final List<Recipe> recipes;

  DishIdentifyResult({
    required this.dishName,
    required this.cuisine,
    required this.confidence,
    required this.description,
    required this.healthTags,
    required this.recipes,
  });

  factory DishIdentifyResult.fromJson(Map<String, dynamic> json) {
    return DishIdentifyResult(
      dishName: json['dish_name'] ?? '',
      cuisine: json['cuisine'] ?? '',
      confidence: ((json['confidence'] ?? 0.5) as num).toDouble(),
      description: json['description'] ?? '',
      healthTags: List<String>.from(json['health_tags'] ?? []),
      recipes: ((json['recipes'] ?? []) as List)
          .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
