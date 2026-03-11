import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool useGradient;
  final bool compact; // For mobile layout

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    this.onTap,
    this.useGradient = false,
    this.compact = false,
  });

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isPressed = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use compact layout for mobile
    if (widget.compact) {
      return _buildCompactCard(context, isDark);
    }
    
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap?.call();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuint,
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                  ? [
                      AppColors.cardDark.withOpacity(0.8),
                      const Color(0xFF2C2C2C).withOpacity(0.6),
                    ]
                  : [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(isDark ? 0.15 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon with glow
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withOpacity(0.2),
                      widget.color.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: widget.color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon, 
                    color: widget.color, 
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        fontSize: 15,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark 
                              ? AppColors.textTertiaryDark 
                              : AppColors.textTertiaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Compact card for mobile layout
  Widget _buildCompactCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap?.call();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuint,
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [
                    AppColors.cardDark.withOpacity(0.8),
                    const Color(0xFF2C2C2C).withOpacity(0.6),
                  ]
                : [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.05) 
                : Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(isDark ? 0.15 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon with glow
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color.withOpacity(0.2),
                    widget.color.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: widget.color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  widget.icon, 
                  color: widget.color, 
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark 
                      ? AppColors.textTertiaryDark 
                      : AppColors.textTertiaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Large featured action card with gradient
class FeaturedActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const FeaturedActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
    this.onTap,
  });

  @override
  State<FeaturedActionCard> createState() => _FeaturedActionCardState();
}

class _FeaturedActionCardState extends State<FeaturedActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradientColors.first.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
