import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/recipe_provider.dart';
import '../../navigation/main_navigation.dart';

class PreferenceQuizScreen extends StatefulWidget {
  const PreferenceQuizScreen({super.key});

  @override
  State<PreferenceQuizScreen> createState() => _PreferenceQuizScreenState();
}

class _PreferenceQuizScreenState extends State<PreferenceQuizScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Step 1 — Health & Diet Goals
  final List<String> _healthGoals = [];
  final List<_ChipOption> _goalOptions = [
    _ChipOption('⚖️', 'Weight Loss', 'Lighter, lower-calorie dishes'),
    _ChipOption('❤️', 'Heart Health', 'Low-sodium, heart-friendly meals'),
    _ChipOption('🩺', 'Diabetic-Friendly', 'Low-sugar, balanced carbs'),
    _ChipOption('💪', 'High Protein', 'Muscle-building, protein-rich foods'),
    _ChipOption('🌾', 'Low Carb', 'Minimal grains & starchy foods'),
    _ChipOption('🧘', 'Balanced Diet', 'Well-rounded nutritious meals'),
    _ChipOption('✨', 'No Specific Goal', 'Just great food!'),
  ];

  // Step 2 — Dietary Restrictions
  final List<String> _dietaryNeeds = [];
  final List<_ChipOption> _dietaryOptions = [
    _ChipOption('🌙', 'Halal', 'Permissible ingredients only'),
    _ChipOption('🥗', 'Vegetarian', 'No meat or fish'),
    _ChipOption('🌱', 'Vegan', 'No animal products'),
    _ChipOption('🌾', 'Gluten-Free', 'No wheat, barley or rye'),
    _ChipOption('🥛', 'Dairy-Free', 'No milk-based products'),
    _ChipOption('🥜', 'Nut-Free', 'Avoid tree nuts & peanuts'),
    _ChipOption('✅', 'No Restrictions', 'I eat everything!'),
  ];

  // Step 3 — Favorite Ingredients
  final List<String> _favoriteIngredients = [];
  final List<_ChipOption> _ingredientOptions = [
    _ChipOption('🍗', 'Chicken', 'Versatile & lean'),
    _ChipOption('🥩', 'Lamb & Beef', 'Rich, traditional MENA staples'),
    _ChipOption('🐟', 'Fish & Seafood', 'Light coastal flavors'),
    _ChipOption('🫘', 'Legumes', 'Lentils, chickpeas, fava beans'),
    _ChipOption('🍚', 'Rice & Grains', 'Pilaf, couscous, freekeh'),
    _ChipOption('🥦', 'Fresh Vegetables', 'Garden-fresh & colorful'),
    _ChipOption('🥚', 'Eggs', 'Quick & protein-packed'),
    _ChipOption('🧀', 'Dairy', 'Labneh, halloumi, yogurt'),
  ];

  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishQuiz();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishQuiz() async {
    setState(() => _isSaving = true);

    final prefs = UserPreferences(
      cuisineStyles: [],
      dietaryNeeds: _dietaryNeeds,
      spiceLevel: 0.4,
      flavorProfile: _healthGoals,
      favoriteIngredients: _favoriteIngredients,
    );

    await PreferencesService().savePreferences(
      cuisineStyles: [],
      dietaryNeeds: _dietaryNeeds,
      spiceLevel: 0.4,
      flavorProfile: _healthGoals,
      favoriteIngredients: _favoriteIngredients,
    );

    if (mounted) {
      await context.read<UserProvider>().applyLocalPreferences(prefs);
    }

    // Trigger recommendations with the freshly saved preferences
    if (mounted) {
      final mergedPrefs = [..._healthGoals, ..._favoriteIngredients];
      context.read<RecipeProvider>().loadRecommendations(
        preferences: mergedPrefs,
        allergies: prefs.asAllergies,
        disliked: [],
      );
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigation(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  Future<void> _skipAll() async {
    await PreferencesService().savePreferences(
      cuisineStyles: [],
      dietaryNeeds: [],
      spiceLevel: 0.4,
      flavorProfile: [],
      favoriteIngredients: [],
    );
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigation(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  String get _ctaLabel =>
      _currentStep == 2 ? "Let's Cook! 🍳" : 'Continue';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        children: [
          _buildAmbientGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildStepIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildGoalsStep(),
                      _buildDietaryStep(),
                      _buildIngredientsStep(),
                    ],
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ambient glow ───────────────────────────────────────────────────────

  Widget _buildAmbientGlow() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, __) {
        final t = _glowController.value;
        return Stack(
          children: [
            Positioned(
              top: -140,
              right: -100,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.07 + t * 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withOpacity(0.09 + t * 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final labels = ['Health Goals', 'Dietary Needs', 'Favorite Ingredients'];
    final subtitles = [
      'What are you trying to achieve?',
      'Any restrictions we should know?',
      'What do you love to cook with?',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentStep + 1} of 3',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _skipAll,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(_currentStep),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labels[_currentStep],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitles[_currentStep],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 500.ms, delay: 100.ms);
  }

  // ─── Step indicator ──────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isActive
                    ? AppColors.primary
                    : isDone
                        ? AppColors.primary.withOpacity(0.5)
                        : Colors.white.withOpacity(0.12),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Step 1: Health Goals ────────────────────────────────────────────────

  Widget _buildGoalsStep() {
    return _buildChipPage(
      hint: 'Select all that apply — the AI will tailor every recommendation to your goals.',
      options: _goalOptions,
      selected: _healthGoals,
      onToggle: (label) {
        setState(() {
          if (label == 'No Specific Goal') {
            if (_healthGoals.contains('No Specific Goal')) {
              _healthGoals.remove('No Specific Goal');
            } else {
              _healthGoals.clear();
              _healthGoals.add('No Specific Goal');
            }
          } else {
            _healthGoals.remove('No Specific Goal');
            _healthGoals.contains(label)
                ? _healthGoals.remove(label)
                : _healthGoals.add(label);
          }
        });
      },
    );
  }

  // ─── Step 2: Dietary Restrictions ────────────────────────────────────────

  Widget _buildDietaryStep() {
    return _buildChipPage(
      hint: 'Recipes and AI suggestions will always respect your dietary restrictions.',
      options: _dietaryOptions,
      selected: _dietaryNeeds,
      onToggle: (label) {
        setState(() {
          if (label == 'No Restrictions' || label == 'I eat everything!') {
            if (_dietaryNeeds.contains('No Restrictions')) {
              _dietaryNeeds.remove('No Restrictions');
            } else {
              _dietaryNeeds.clear();
              _dietaryNeeds.add('No Restrictions');
            }
          } else {
            _dietaryNeeds.remove('No Restrictions');
            _dietaryNeeds.contains(label)
                ? _dietaryNeeds.remove(label)
                : _dietaryNeeds.add(label);
          }
        });
      },
    );
  }

  // ─── Step 3: Favorite Ingredients ────────────────────────────────────────

  Widget _buildIngredientsStep() {
    return _buildChipPage(
      hint: 'The AI prioritizes recipes featuring your favorite ingredients first.',
      options: _ingredientOptions,
      selected: _favoriteIngredients,
      onToggle: (label) {
        setState(() {
          _favoriteIngredients.contains(label)
              ? _favoriteIngredients.remove(label)
              : _favoriteIngredients.add(label);
        });
      },
    );
  }

  // ─── Generic chip page ───────────────────────────────────────────────────

  Widget _buildChipPage({
    required String hint,
    required List<_ChipOption> options,
    required List<String> selected,
    required void Function(String) onToggle,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hint text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 14, color: AppColors.primary.withOpacity(0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((opt) => _AnimatedChip(
              emoji: opt.emoji,
              label: opt.label,
              description: opt.description,
              isSelected: selected.contains(opt.label),
              onTap: () => onToggle(opt.label),
            )).toList(),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
  }

  // ─── Bottom nav ──────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF080808).withOpacity(0),
            const Color(0xFF080808),
          ],
        ),
      ),
      child: Row(
        children: [
          // Back
          AnimatedOpacity(
            opacity: _currentStep > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: GestureDetector(
              onTap: _currentStep > 0 ? _prevStep : null,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1), width: 1),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),

          if (_currentStep > 0) const SizedBox(width: 12),

          // CTA
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: !_isSaving ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _ctaLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (_currentStep < 2) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Chip ────────────────────────────────────────────────────────

class _AnimatedChip extends StatefulWidget {
  final String emoji;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedChip({
    required this.emoji,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<_AnimatedChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - _controller.value * 0.05,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary.withOpacity(0.14)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary.withOpacity(0.75)
                  : Colors.white.withOpacity(0.09),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isSelected
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (widget.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: TextStyle(
                        color: widget.isSelected
                            ? AppColors.primary.withOpacity(0.65)
                            : Colors.white.withOpacity(0.32),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────

class _ChipOption {
  final String emoji;
  final String label;
  final String description;
  const _ChipOption(this.emoji, this.label, this.description);
}
