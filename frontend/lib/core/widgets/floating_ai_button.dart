import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/animations.dart';

class FloatingAIButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isVisible;

  const FloatingAIButton({
    super.key,
    required this.onTap,
    required this.onLongPress,
    this.isVisible = true,
  });

  @override
  State<FloatingAIButton> createState() => _FloatingAIButtonState();
}

class _FloatingAIButtonState extends State<FloatingAIButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  void _handleLongPress() {
    HapticFeedback.heavyImpact();
    setState(() => _isListening = true);
    widget.onLongPress();

    // Simulate listening duration
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isListening = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _isListening ? 1.15 : _pulseAnimation.value,
          child: GestureDetector(
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: _isListening
                    ? const LinearGradient(
                        colors: [Color(0xFF81B29A), Color(0xFF3498DB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppColors.warmGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? AppColors.accent : AppColors.primary)
                        .withOpacity(_glowAnimation.value),
                    blurRadius: _isListening ? 24 : 20,
                    offset: const Offset(0, 4),
                    spreadRadius: _isListening ? 4 : 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated ring when listening
                  if (_isListening)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: 1.5),
                      duration: const Duration(milliseconds: 1000),
                      builder: (context, value, child) {
                        return Container(
                          width: 56 * value,
                          height: 56 * value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withOpacity(1.5 - value),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  // Main icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isListening
                          ? Icons.mic_rounded
                          : Icons.auto_awesome_rounded,
                      key: ValueKey(_isListening),
                      color: Colors.white,
                      size: 26,
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
}

// Draggable version of the floating AI button
class DraggableFloatingAIButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isVisible;

  const DraggableFloatingAIButton({
    super.key,
    required this.onTap,
    required this.onLongPress,
    this.isVisible = true,
  });

  @override
  State<DraggableFloatingAIButton> createState() =>
      _DraggableFloatingAIButtonState();
}

class _DraggableFloatingAIButtonState extends State<DraggableFloatingAIButton>
    with TickerProviderStateMixin {
  Offset _position = const Offset(0, 0);
  bool _initialized = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleLongPress() {
    HapticFeedback.heavyImpact();
    setState(() => _isListening = true);
    widget.onLongPress();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isListening = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    // Initialize position on first build
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _position = Offset(size.width - 76, size.height - 180);
          _initialized = true;
        });
      });
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
            // Keep within screen bounds
            final size = MediaQuery.of(context).size;
            _position = Offset(
              _position.dx.clamp(0, size.width - 56),
              _position.dy.clamp(0, size.height - 56),
            );
          });
        },
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isListening ? 1.15 : _pulseAnimation.value,
              child: TapScale(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onTap();
                  },
                  onLongPress: _handleLongPress,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: _isListening
                          ? const LinearGradient(
                              colors: [Color(0xFF81B29A), Color(0xFF3498DB)],
                            )
                          : AppColors.warmGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening
                                  ? AppColors.accent
                                  : AppColors.primary)
                              .withOpacity(0.4),
                          blurRadius: _isListening ? 24 : 16,
                          offset: const Offset(0, 4),
                          spreadRadius: _isListening ? 4 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening
                          ? Icons.mic_rounded
                          : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
