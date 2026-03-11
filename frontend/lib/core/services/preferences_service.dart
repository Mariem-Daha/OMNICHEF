import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages local device preferences — no account/login required.
/// Each device is treated as a unique user; preferences persist across sessions.
class PreferencesService {
  static const _keySetupDone = 'setup_done';
  static const _keyCuisineStyles = 'cuisine_styles';
  static const _keyDietaryNeeds = 'dietary_needs';
  static const _keySpiceLevel = 'spice_level';
  static const _keyFlavorProfile = 'flavor_profile';
  static const _keyFavoriteIngredients = 'favorite_ingredients';
  static const _keyDeviceId = 'device_id';

  // Singleton
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  /// Whether the user has completed the preference quiz.
  Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySetupDone) ?? false;
  }

  /// Save all preferences from the quiz and mark setup as done.
  Future<void> savePreferences({
    required List<String> cuisineStyles,
    required List<String> dietaryNeeds,
    required double spiceLevel,
    required List<String> flavorProfile,
    List<String> favoriteIngredients = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySetupDone, true);
    await prefs.setString(_keyCuisineStyles, jsonEncode(cuisineStyles));
    await prefs.setString(_keyDietaryNeeds, jsonEncode(dietaryNeeds));
    await prefs.setDouble(_keySpiceLevel, spiceLevel);
    await prefs.setString(_keyFlavorProfile, jsonEncode(flavorProfile));
    await prefs.setString(_keyFavoriteIngredients, jsonEncode(favoriteIngredients));
  }

  /// Load saved preferences. Returns null if setup not done.
  Future<UserPreferences?> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keySetupDone) ?? false)) return null;

    List<String> decode(String? raw) {
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<String>();
    }

    return UserPreferences(
      cuisineStyles: decode(prefs.getString(_keyCuisineStyles)),
      dietaryNeeds: decode(prefs.getString(_keyDietaryNeeds)),
      spiceLevel: prefs.getDouble(_keySpiceLevel) ?? 0.5,
      flavorProfile: decode(prefs.getString(_keyFlavorProfile)),
      favoriteIngredients: decode(prefs.getString(_keyFavoriteIngredients)),
    );
  }

  /// Get or generate a stable device ID for this device.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_keyDeviceId);
    if (id == null) {
      id = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  /// Clear all saved preferences (for testing or reset).
  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySetupDone);
    await prefs.remove(_keyCuisineStyles);
    await prefs.remove(_keyDietaryNeeds);
    await prefs.remove(_keySpiceLevel);
    await prefs.remove(_keyFlavorProfile);
    await prefs.remove(_keyFavoriteIngredients);
  }
}

/// Data class holding all user preferences collected during the quiz.
class UserPreferences {
  final List<String> cuisineStyles;
  final List<String> dietaryNeeds;
  final double spiceLevel;
  final List<String> flavorProfile; // health goals
  final List<String> favoriteIngredients;

  const UserPreferences({
    required this.cuisineStyles,
    required this.dietaryNeeds,
    required this.spiceLevel,
    required this.flavorProfile,
    this.favoriteIngredients = const [],
  });

  /// Converts preferences to a human-readable context string for the AI.
  String toAiContext() {
    final parts = <String>[];

    if (flavorProfile.isNotEmpty &&
        !flavorProfile.contains('No Specific Goal')) {
      parts.add('Health goals: ${flavorProfile.join(', ')}');
    }
    if (dietaryNeeds.isNotEmpty && !dietaryNeeds.contains('No Restrictions')) {
      parts.add('Dietary restrictions: ${dietaryNeeds.join(', ')}');
    }
    if (favoriteIngredients.isNotEmpty) {
      parts.add('Favorite ingredients: ${favoriteIngredients.join(', ')}');
    }

    return parts.join('. ');
  }

  /// Build health filters list from dietary needs (maps to existing UserModel fields).
  List<String> get asHealthFilters {
    final filters = <String>[];
    for (final need in dietaryNeeds) {
      switch (need) {
        case 'Vegetarian':
          filters.add('Vegetarian');
          break;
        case 'Vegan':
          filters.add('Vegan');
          break;
        case 'Gluten-Free':
          filters.add('Gluten Free');
          break;
        case 'Dairy-Free':
          filters.add('Dairy Free');
          break;
        case 'Halal':
          filters.add('Halal');
          break;
      }
    }
    return filters;
  }

  /// Build allergies list from dietary needs.
  List<String> get asAllergies {
    final allergies = <String>[];
    for (final need in dietaryNeeds) {
      if (need == 'Nut-Free') allergies.add('Tree Nuts');
      if (need == 'Gluten-Free') allergies.add('Gluten');
      if (need == 'Dairy-Free') allergies.add('Dairy');
    }
    return allergies;
  }
}
