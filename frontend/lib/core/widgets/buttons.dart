import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final button = isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: _buildChild(),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: _buildChild(),
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: 56,
      child: button,
    );
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
}

class SocialButton extends StatelessWidget {
  final String text;
  final String iconPath;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const SocialButton({
    super.key,
    required this.text,
    required this.iconPath,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? (isDark ? AppColors.surfaceDark : Colors.white),
          side: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: textColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    // Use Material icons as fallback
    if (iconPath == 'google') {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text(
            'G',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
    } else if (iconPath == 'apple') {
      return const Icon(Icons.apple, size: 24, color: Colors.black);
    }
    return const SizedBox(width: 24);
  }
}

class IconTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const IconTextButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? AppColors.primary, size: 20),
      label: Text(
        label,
        style: TextStyle(color: color ?? AppColors.primary),
      ),
    );
  }
}

class FloatingActionButtonCustom extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLarge;

  const FloatingActionButtonCustom({
    super.key,
    required this.icon,
    this.onPressed,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isLarge ? 72 : 56,
      height: isLarge ? 72 : 56,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient, // Use the new premium gradient
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(36),
          child: Icon(
            icon,
            color: Colors.white,
            size: isLarge ? 32 : 24,
          ),
        ),
      ),
    );
  }
}
