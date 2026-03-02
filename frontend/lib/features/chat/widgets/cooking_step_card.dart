import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';

class CookingStepCard extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final String instruction;
  final String? tip;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const CookingStepCard({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.instruction,
    this.tip,
    this.onNext,
    this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = stepNumber / totalSteps;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.warmGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Step $stepNumber of $totalSteps',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress bar
          LinearPercentIndicator(
            lineHeight: 6,
            percent: progress,
            backgroundColor: isDark 
                ? AppColors.dividerDark 
                : AppColors.dividerLight,
            progressColor: AppColors.primary,
            barRadius: const Radius.circular(3),
            padding: EdgeInsets.zero,
          ),
          
          const SizedBox(height: 20),
          
          // Instruction
          Text(
            instruction,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
          ),
          
          // Tip
          if (tip != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip!,
                      style: TextStyle(
                        color: isDark ? AppColors.warning : AppColors.secondaryDark,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Navigation buttons
          Row(
            children: [
              if (onPrevious != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (onPrevious != null) const SizedBox(width: 12),
              Expanded(
                flex: onPrevious != null ? 1 : 2,
                child: ElevatedButton.icon(
                  onPressed: onNext,
                  icon: Icon(
                    stepNumber >= totalSteps 
                        ? Icons.check_circle_rounded 
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(stepNumber >= totalSteps ? 'Complete!' : 'Next Step'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
