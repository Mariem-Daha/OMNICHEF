import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class VoiceInputButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback? onPressed;

  const VoiceInputButton({
    super.key,
    this.isListening = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.warmGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(isListening ? 0.5 : 0.3),
              blurRadius: isListening ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isListening)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 1.3),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            Icon(
              isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
