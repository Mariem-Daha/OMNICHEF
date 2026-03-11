import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';

class UserProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  UserModel? _user;
  bool _isLoading = false;
  bool _isOnboarded = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isOnboarded => _isOnboarded;
  bool get isLoggedIn => _user != null;
  String? get error => _error;

  /// Initialize and try to restore session, loading local preferences.
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _api.init();
      if (_api.isAuthenticated) {
        _user = await _api.getCurrentUser();
      }
      // Always load locally saved preferences (device-as-user)
      await loadLocalPreferences();
    } catch (e) {
      debugPrint('Failed to restore session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load preferences from local storage and create/update the device user.
  Future<void> loadLocalPreferences() async {
    try {
      final savedPrefs = await PreferencesService().loadPreferences();
      if (savedPrefs == null) return;

      final deviceId = await PreferencesService().getDeviceId();

      // tastePreferences = health goals + favorite ingredients
      final tastePrefs = [
        ...savedPrefs.flavorProfile,       // health goals
        ...savedPrefs.favoriteIngredients, // favorite ingredients
      ];

      if (_user != null) {
        _user = _user!.copyWith(
          healthFilters: savedPrefs.asHealthFilters,
          tastePreferences: tastePrefs,
          allergies: savedPrefs.asAllergies,
          dislikedIngredients: [],
        );
      } else {
        _user = UserModel(
          id: deviceId,
          name: 'Chef',
          email: '$deviceId@local.omnichef',
          healthFilters: savedPrefs.asHealthFilters,
          tastePreferences: tastePrefs,
          allergies: savedPrefs.asAllergies,
          cookingSkill: 'Intermediate',
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load local preferences: $e');
    }
  }

  /// Apply preferences collected in the quiz and persist them.
  Future<void> applyLocalPreferences(UserPreferences prefs) async {
    try {
      final deviceId = await PreferencesService().getDeviceId();

      // tastePreferences = health goals + favorite ingredients
      final tastePrefs = [
        ...prefs.flavorProfile,       // health goals
        ...prefs.favoriteIngredients, // favorite ingredients
      ];

      if (_user != null) {
        _user = _user!.copyWith(
          healthFilters: prefs.asHealthFilters,
          tastePreferences: tastePrefs,
          allergies: prefs.asAllergies,
          dislikedIngredients: [],
        );
      } else {
        _user = UserModel(
          id: deviceId,
          name: 'Chef',
          email: '$deviceId@local.omnichef',
          healthFilters: prefs.asHealthFilters,
          tastePreferences: tastePrefs,
          allergies: prefs.asAllergies,
          cookingSkill: 'Intermediate',
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to apply preferences: $e');
    }
  }

  /// Register a new user.
  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _api.register(email, password, name);
      _user = result.user;
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Registration failed: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with email and password.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _api.login(email, password);
      _user = result.user;
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Login failed: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void setOnboarded(bool value) {
    _isOnboarded = value;
    notifyListeners();
  }

  /// Update health filters and sync with API.
  Future<void> updateHealthFilters(List<String> filters) async {
    if (_user != null) {
      _user = _user!.copyWith(healthFilters: filters);
      notifyListeners();
      
      if (_api.isAuthenticated) {
        try {
          await _api.updateProfile({'health_filters': filters});
        } catch (e) {
          debugPrint('Failed to sync health filters: $e');
        }
      }
    }
  }

  /// Update disliked ingredients and sync with API.
  Future<void> updateDislikedIngredients(List<String> ingredients) async {
    if (_user != null) {
      _user = _user!.copyWith(dislikedIngredients: ingredients);
      notifyListeners();
      
      if (_api.isAuthenticated) {
        try {
          await _api.updateProfile({'disliked_ingredients': ingredients});
        } catch (e) {
          debugPrint('Failed to sync disliked ingredients: $e');
        }
      }
    }
  }

  /// Update taste preferences and sync with API.
  Future<void> updateTastePreferences(List<String> preferences) async {
    if (_user != null) {
      _user = _user!.copyWith(tastePreferences: preferences);
      notifyListeners();
      
      if (_api.isAuthenticated) {
        try {
          await _api.updateProfile({'taste_preferences': preferences});
        } catch (e) {
          debugPrint('Failed to sync taste preferences: $e');
        }
      }
    }
  }

  /// Update full profile.
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_user == null || !_api.isAuthenticated) return false;
    
    try {
      _user = await _api.updateProfile(updates);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      return false;
    }
  }

  /// Logout and clear session.
  Future<void> logout() async {
    await _api.logout();
    _user = null;
    notifyListeners();
  }
}
