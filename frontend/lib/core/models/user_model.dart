class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String ageRange;
  final String cookingSkill;
  final List<String> healthFilters;
  final List<String> dislikedIngredients;
  final List<String> tastePreferences;
  final List<String> allergies;
  final DateTime createdAt;
  final int cookingStreak;
  final int recipesCooked;
  final DateTime? lastCookingDate;
  final bool hasCompletedHealthQuiz;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.ageRange = '25-34',
    this.cookingSkill = 'Intermediate',
    this.healthFilters = const [],
    this.dislikedIngredients = const [],
    this.tastePreferences = const [],
    this.allergies = const [],
    DateTime? createdAt,
    this.cookingStreak = 0,
    this.recipesCooked = 0,
    this.lastCookingDate,
    this.hasCompletedHealthQuiz = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // Get cooking level based on recipes cooked
  String get cookingLevel {
    if (recipesCooked >= 20) return 'Pro Home Cook';
    if (recipesCooked >= 5) return 'Intermediate';
    return 'Beginner';
  }

  // Get cooking level progress (0.0 to 1.0)
  double get levelProgress {
    if (recipesCooked >= 20) return 1.0;
    if (recipesCooked >= 5) return (recipesCooked - 5) / 15;
    return recipesCooked / 5;
  }

  // Get next level threshold
  int get nextLevelThreshold {
    if (recipesCooked >= 20) return 20;
    if (recipesCooked >= 5) return 20;
    return 5;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? ageRange,
    String? cookingSkill,
    List<String>? healthFilters,
    List<String>? dislikedIngredients,
    List<String>? tastePreferences,
    List<String>? allergies,
    DateTime? createdAt,
    int? cookingStreak,
    int? recipesCooked,
    DateTime? lastCookingDate,
    bool? hasCompletedHealthQuiz,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      ageRange: ageRange ?? this.ageRange,
      cookingSkill: cookingSkill ?? this.cookingSkill,
      healthFilters: healthFilters ?? this.healthFilters,
      dislikedIngredients: dislikedIngredients ?? this.dislikedIngredients,
      tastePreferences: tastePreferences ?? this.tastePreferences,
      allergies: allergies ?? this.allergies,
      createdAt: createdAt ?? this.createdAt,
      cookingStreak: cookingStreak ?? this.cookingStreak,
      recipesCooked: recipesCooked ?? this.recipesCooked,
      lastCookingDate: lastCookingDate ?? this.lastCookingDate,
      hasCompletedHealthQuiz: hasCompletedHealthQuiz ?? this.hasCompletedHealthQuiz,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'ageRange': ageRange,
      'cookingSkill': cookingSkill,
      'healthFilters': healthFilters,
      'dislikedIngredients': dislikedIngredients,
      'tastePreferences': tastePreferences,
      'allergies': allergies,
      'createdAt': createdAt.toIso8601String(),
      'cookingStreak': cookingStreak,
      'recipesCooked': recipesCooked,
      'lastCookingDate': lastCookingDate?.toIso8601String(),
      'hasCompletedHealthQuiz': hasCompletedHealthQuiz,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      ageRange: json['ageRange'] ?? '25-34',
      cookingSkill: json['cookingSkill'] ?? 'Intermediate',
      healthFilters: List<String>.from(json['healthFilters'] ?? []),
      dislikedIngredients: List<String>.from(json['dislikedIngredients'] ?? []),
      tastePreferences: List<String>.from(json['tastePreferences'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      cookingStreak: json['cookingStreak'] ?? 0,
      recipesCooked: json['recipesCooked'] ?? 0,
      lastCookingDate: json['lastCookingDate'] != null 
          ? DateTime.parse(json['lastCookingDate']) 
          : null,
      hasCompletedHealthQuiz: json['hasCompletedHealthQuiz'] ?? false,
    );
  }
}
