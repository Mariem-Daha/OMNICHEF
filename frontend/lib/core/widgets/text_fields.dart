import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final bool enabled;

  const CustomTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          onChanged: widget.onChanged,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          enabled: widget.enabled,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 22)
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : widget.suffixIcon != null
                    ? IconButton(
                        icon: Icon(widget.suffixIcon, size: 22),
                        onPressed: widget.onSuffixTap,
                      )
                    : null,
          ),
        ),
      ],
    );
  }
}

class SearchTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final void Function(String)? onChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onTap;

  const SearchTextField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onFilterTap,
    this.onTap,
  });

  @override
  State<SearchTextField> createState() => _SearchTextFieldState();
}

class _SearchTextFieldState extends State<SearchTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.surfaceDark 
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFocused 
              ? AppColors.primary
              : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
          width: 1.5,
        ),
        boxShadow: [
          if (_isFocused)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
        ],
      ),
      child: Focus(
        onFocusChange: (focused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isFocused = focused);
          });
        },
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Search recipes...',
            hintStyle: TextStyle(
              color: isDark 
                  ? AppColors.textTertiaryDark 
                  : AppColors.textTertiaryLight,
              fontWeight: FontWeight.w400,
              fontSize: 15,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 12),
              child: Icon(
                Icons.search_rounded, 
                size: 24,
                color: _isFocused 
                    ? AppColors.primary 
                    : (isDark 
                        ? AppColors.textTertiaryDark 
                        : AppColors.textTertiaryLight),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 54),
            suffixIcon: widget.onFilterTap != null
                ? GestureDetector(
                    onTap: widget.onFilterTap,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.tune_rounded, 
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}
