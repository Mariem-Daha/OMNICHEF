import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/text_fields.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../../navigation/main_navigation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form data
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedAgeRange = '25-34';
  String _selectedCookingSkill = 'Intermediate';
  final List<String> _selectedHealthNeeds = [];
  final List<String> _dislikedIngredients = [];

  final List<String> _ageRanges = ['Under 18', '18-24', '25-34', '35-44', '45-54', '55+'];
  final List<String> _cookingSkills = ['Beginner', 'Intermediate', 'Advanced', 'Chef'];
  final List<String> _healthOptions = [
    'Diabetes',
    'Hypertension',
    'Anemia',
    'Weight Loss',
    'Heart Health',
    'Allergies',
    'None',
  ];
  final List<String> _commonDislikes = [
    'Onions',
    'Garlic',
    'Cilantro',
    'Spicy food',
    'Fish',
    'Lamb',
    'Eggs',
    'Dairy',
    'Nuts',
    'Gluten',
  ];

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _completeSignup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _completeSignup() async {
    setState(() => _isLoading = true);
    
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.register(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    );
    
    if (mounted) {
      if (success) {
        // Update profile with additional info
        await userProvider.updateProfile({
          'age_range': _selectedAgeRange,
          'cooking_skill': _selectedCookingSkill,
          'health_filters': _selectedHealthNeeds,
          'disliked_ingredients': _dislikedIngredients,
        });
        
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
                const MainNavigation(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (route) => false,
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userProvider.error ?? 'Registration failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _previousStep,
        ),
        title: Text('Step ${_currentStep + 1} of 3'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentStep 
                          ? AppColors.primary 
                          : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildAccountStep(),
                _buildProfileStep(),
                _buildPreferencesStep(),
              ],
            ),
          ),
          
          // Next button
          Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryButton(
              text: _currentStep == 2 ? 'Complete Setup' : 'Continue',
              onPressed: _nextStep,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Account',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your details to get started',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 32),
          
          CustomTextField(
            label: 'Full Name',
            hint: 'Enter your name',
            controller: _nameController,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          
          CustomTextField(
            label: 'Email',
            hint: 'Enter your email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 20),
          
          CustomTextField(
            label: 'Password',
            hint: 'Create a password',
            controller: _passwordController,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 24),
          
          // Social signup
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          
          SocialButton(
            text: 'Continue with Google',
            iconPath: 'google',
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          SocialButton(
            text: 'Continue with Apple',
            iconPath: 'apple',
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell Us About You',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Help us personalize your experience',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 32),
          
          // Age range
          Text(
            'Age Range',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ageRanges.map<Widget>((age) {
              return CustomFilterChip(
                label: age,
                isSelected: _selectedAgeRange == age,
                onTap: () => setState(() => _selectedAgeRange = age),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 28),
          
          // Cooking skill
          Text(
            'Cooking Skill Level',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cookingSkills.map<Widget>((skill) {
              return CustomFilterChip(
                label: skill,
                isSelected: _selectedCookingSkill == skill,
                onTap: () => setState(() => _selectedCookingSkill = skill),
                icon: _getSkillIcon(skill),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 28),
          
          // Health needs
          Text(
            'Health Considerations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select all that apply',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _healthOptions.map((health) {
              final isSelected = _selectedHealthNeeds.contains(health);
              return HealthTag(
                label: health,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (health == 'None') {
                      _selectedHealthNeeds.clear();
                      if (!isSelected) _selectedHealthNeeds.add(health);
                    } else {
                      _selectedHealthNeeds.remove('None');
                      if (isSelected) {
                        _selectedHealthNeeds.remove(health);
                      } else {
                        _selectedHealthNeeds.add(health);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Food Preferences',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Tell us what you don't like so we can avoid it",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 32),
          
          // Disliked ingredients
          Text(
            'Disliked Ingredients',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to select ingredients you avoid',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonDislikes.map((ingredient) {
              final isSelected = _dislikedIngredients.contains(ingredient);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _dislikedIngredients.remove(ingredient);
                    } else {
                      _dislikedIngredients.add(ingredient);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.error.withOpacity(0.1) 
                        : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? AppColors.error 
                          : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        ingredient,
                        style: TextStyle(
                          color: isSelected 
                              ? AppColors.error 
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          
          // Selected summary
          if (_dislikedIngredients.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "We'll avoid recipes with: ${_dislikedIngredients.join(', ')}",
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentLight.withOpacity(isDark ? 0.2 : 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, color: AppColors.accentDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can always update these preferences later in your profile settings.',
                    style: TextStyle(
                      color: AppColors.accentDark,
                      fontSize: 13,
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

  IconData _getSkillIcon(String skill) {
    switch (skill) {
      case 'Beginner':
        return Icons.school_outlined;
      case 'Intermediate':
        return Icons.restaurant_outlined;
      case 'Advanced':
        return Icons.emoji_events_outlined;
      case 'Chef':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }
}
