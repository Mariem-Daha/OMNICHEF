import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HealthTag extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? color;
  final bool showIcon;

  const HealthTag({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.color,
    this.showIcon = false,
  });

  @override
  State<HealthTag> createState() => _HealthTagState();
}

class _HealthTagState extends State<HealthTag> {
  bool _isPressed = false;

  Color get tagColor {
    if (widget.color != null) return widget.color!;
    
    switch (widget.label.toLowerCase()) {
      case 'diabetes-friendly':
        return AppColors.diabetesFriendly;
      case 'low salt':
        return AppColors.lowSalt;
      case 'heart healthy':
        return AppColors.heartHealthy;
      case 'weight loss':
        return AppColors.weightLoss;
      case 'allergy-free':
      case 'allergen-free':
        return AppColors.allergyFree;
      case 'quick meal':
        return AppColors.quickMeal;
      case 'vegetarian':
      case 'vegan':
        return AppColors.accent;
      case 'iron-rich':
        return AppColors.ironRich;
      case 'protein-rich':
        return AppColors.proteinRich;
      default:
        return AppColors.primary;
    }
  }

  IconData get tagIcon {
    switch (widget.label.toLowerCase()) {
      case 'diabetes-friendly':
        return Icons.bloodtype_rounded;
      case 'low salt':
        return Icons.water_drop_rounded;
      case 'heart healthy':
        return Icons.favorite_rounded;
      case 'weight loss':
        return Icons.fitness_center_rounded;
      case 'allergy-free':
      case 'allergen-free':
        return Icons.shield_rounded;
      case 'quick meal':
        return Icons.timer_rounded;
      case 'vegetarian':
      case 'vegan':
        return Icons.eco_rounded;
      case 'iron-rich':
        return Icons.bolt_rounded;
      case 'protein-rich':
        return Icons.egg_alt_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        padding: EdgeInsets.symmetric(
          horizontal: widget.showIcon ? 14 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: widget.isSelected 
              ? LinearGradient(
                  colors: [tagColor, tagColor.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: widget.isSelected ? null : tagColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isSelected ? Colors.transparent : tagColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: widget.isSelected 
              ? [
                  BoxShadow(
                    color: tagColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcon) ...[
              Icon(
                tagIcon,
                size: 16,
                color: widget.isSelected ? Colors.white : tagColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected ? Colors.white : tagColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomFilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;

  const CustomFilterChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
  });

  @override
  State<CustomFilterChip> createState() => _CustomFilterChipState();
}

class _CustomFilterChipState extends State<CustomFilterChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: widget.isSelected ? AppColors.warmGradient : null,
          color: widget.isSelected 
              ? null 
              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isSelected 
                ? Colors.transparent 
                : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
            width: 1.5,
          ),
          boxShadow: widget.isSelected 
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppColors.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 20,
                color: widget.isSelected 
                    ? Colors.white 
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected 
                    ? Colors.white 
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.isSelected) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded, 
                  size: 14, 
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class IngredientChip extends StatefulWidget {
  final String ingredient;
  final VoidCallback? onRemove;
  final bool showRemove;

  const IngredientChip({
    super.key,
    required this.ingredient,
    this.onRemove,
    this.showRemove = true,
  });

  @override
  State<IngredientChip> createState() => _IngredientChipState();
}

class _IngredientChipState extends State<IngredientChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: widget.showRemove ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.showRemove ? (_) {
        setState(() => _isPressed = false);
        widget.onRemove?.call();
      } : null,
      onTapCancel: widget.showRemove ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentLight.withOpacity(isDark ? 0.25 : 0.7),
              AppColors.accentLight.withOpacity(isDark ? 0.15 : 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.accent.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.ingredient,
              style: TextStyle(
                color: isDark ? AppColors.textPrimaryDark : AppColors.accentDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.showRemove) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.accentDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CategoryChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<CategoryChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: widget.isSelected ? AppColors.sunsetGradient : null,
          color: widget.isSelected 
              ? null 
              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                    spreadRadius: -2,
                  ),
                ]
              : AppColors.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isSelected 
                    ? Colors.white.withOpacity(0.2) 
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.isSelected 
                    ? Colors.white 
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected 
                    ? Colors.white 
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
