import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../screens/onboarding_screen.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPage({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration container
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: data.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: data.gradient.colors.first.withOpacity(0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                data.icon,
                size: 80,
                color: Colors.white,
              ),
            ),
          ).animate()
           .scale(duration: 600.ms, curve: Curves.elasticOut)
           .fade(duration: 400.ms)
           .shimmer(delay: 400.ms, duration: 1800.ms, color: Colors.white38),
          
          const SizedBox(height: 60),
          
          // Title
          Text(
            data.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ).animate()
           .fade(duration: 600.ms, delay: 200.ms)
           .slideY(begin: 0.3, end: 0, curve: Curves.easeOutQuad),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            data.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ).animate()
           .fade(duration: 600.ms, delay: 400.ms)
           .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
        ],
      ),
    );
  }
}
