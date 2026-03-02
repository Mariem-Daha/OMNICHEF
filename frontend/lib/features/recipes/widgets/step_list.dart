import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/recipe_model.dart';

class StepList extends StatefulWidget {
  final List<RecipeStep> steps;

  const StepList({
    super.key,
    required this.steps,
  });

  @override
  State<StepList> createState() => _StepListState();
}

class _StepListState extends State<StepList> {
  final Set<int> _completedSteps = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${_completedSteps.length}/${widget.steps.length} steps',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Steps
          ...widget.steps.map((step) {
            final isCompleted = _completedSteps.contains(step.stepNumber);
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isCompleted) {
                    _completedSteps.remove(step.stepNumber);
                  } else {
                    _completedSteps.add(step.stepNumber);
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step number
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: isCompleted 
                                ? AppColors.warmGradient 
                                : null,
                            color: isCompleted 
                                ? null 
                                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                            borderRadius: BorderRadius.circular(12),
                            border: isCompleted 
                                ? null 
                                : Border.all(
                                    color: isDark 
                                        ? AppColors.dividerDark 
                                        : AppColors.dividerLight,
                                  ),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                : Text(
                                    '${step.stepNumber}',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                          ),
                        ),
                        if (step.stepNumber < widget.steps.length)
                          Container(
                            width: 2,
                            height: 60,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isCompleted 
                                ? AppColors.primary 
                                : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                          ),
                      ],
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: isCompleted 
                              ? Border.all(color: AppColors.primary.withOpacity(0.3))
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    step.instruction,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          decoration: isCompleted 
                                              ? TextDecoration.lineThrough 
                                              : null,
                                          color: isCompleted 
                                              ? (isDark 
                                                  ? AppColors.textTertiaryDark 
                                                  : AppColors.textTertiaryLight)
                                              : null,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            if (step.durationMinutes != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: AppColors.textTertiaryLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${step.durationMinutes} min',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                            if (step.tip != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 16,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        step.tip!,
                                        style: TextStyle(
                                          color: AppColors.warning,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
