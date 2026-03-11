import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/animations.dart';

class AIReactionBar extends StatefulWidget {
  final Function(String) onSuggestionTap;
  final String? currentContext;

  const AIReactionBar({
    super.key,
    required this.onSuggestionTap,
    this.currentContext,
  });

  @override
  State<AIReactionBar> createState() => _AIReactionBarState();
}

class _AIReactionBarState extends State<AIReactionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  int _currentSuggestionSet = 0;

  final List<List<AISuggestion>> _suggestionSets = [
    [
      AISuggestion(
        icon: Icons.timer_rounded,
        label: 'Set timer',
        query: 'Set a timer for 5 minutes',
        color: AppColors.primary,
      ),
      AISuggestion(
        icon: Icons.favorite_rounded,
        label: 'Healthier?',
        query: 'What\'s a healthier version of this?',
        color: AppColors.accent,
      ),
      AISuggestion(
        icon: Icons.swap_horiz_rounded,
        label: 'Substitute',
        query: 'What can I substitute for this ingredient?',
        color: AppColors.secondary,
      ),
    ],
    [
      AISuggestion(
        icon: Icons.restaurant_rounded,
        label: 'Continue cooking',
        query: 'Continue to the next step',
        color: AppColors.primary,
      ),
      AISuggestion(
        icon: Icons.help_outline_rounded,
        label: 'Explain this',
        query: 'Can you explain this technique?',
        color: AppColors.info,
      ),
      AISuggestion(
        icon: Icons.local_fire_department_rounded,
        label: 'Adjust heat?',
        query: 'What heat setting should I use?',
        color: AppColors.warning,
      ),
    ],
    [
      AISuggestion(
        icon: Icons.shopping_cart_rounded,
        label: 'Shopping list',
        query: 'Create a shopping list for this recipe',
        color: AppColors.accent,
      ),
      AISuggestion(
        icon: Icons.people_rounded,
        label: 'Scale recipe',
        query: 'How do I adjust this for 6 people?',
        color: AppColors.primary,
      ),
      AISuggestion(
        icon: Icons.access_time_rounded,
        label: 'Prep ahead?',
        query: 'What can I prepare ahead of time?',
        color: AppColors.teal,
      ),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    // Rotate suggestions every 10 seconds
    Future.delayed(const Duration(seconds: 10), _rotateSuggestions);
  }

  void _rotateSuggestions() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentSuggestionSet =
              (_currentSuggestionSet + 1) % _suggestionSets.length;
        });
        _controller.forward();
        Future.delayed(const Duration(seconds: 10), _rotateSuggestions);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suggestions = _suggestionSets[_currentSuggestionSet];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark.withOpacity(0.95)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI Suggestions',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          _controller.reverse().then((_) {
                            if (!mounted) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() {
                                _currentSuggestionSet =
                                    (_currentSuggestionSet + 1) %
                                        _suggestionSets.length;
                              });
                              _controller.forward();
                            });
                          });
                        },
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: suggestions
                          .map((s) => _buildSuggestionChip(s))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionChip(AISuggestion suggestion) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TapScale(
        child: GestureDetector(
          onTap: () => widget.onSuggestionTap(suggestion.query),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: suggestion.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: suggestion.color.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  suggestion.icon,
                  size: 16,
                  color: suggestion.color,
                ),
                const SizedBox(width: 6),
                Text(
                  suggestion.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: suggestion.color,
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

class AISuggestion {
  final IconData icon;
  final String label;
  final String query;
  final Color color;

  const AISuggestion({
    required this.icon,
    required this.label,
    required this.query,
    required this.color,
  });
}
