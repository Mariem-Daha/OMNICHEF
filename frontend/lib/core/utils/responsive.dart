import 'package:flutter/material.dart';

/// Responsive utility for handling different screen sizes
class Responsive {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Get screen width
  static double width(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double height(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Get responsive value based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Get responsive padding
  static EdgeInsets padding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0),
    );
  }

  /// Get responsive horizontal padding value
  static double horizontalPadding(BuildContext context) {
    return value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0);
  }

  /// Get grid column count for recipe cards
  static int recipeGridColumns(BuildContext context) {
    return value(context, mobile: 2, tablet: 3, desktop: 5);
  }

  /// Get grid spacing
  static double gridSpacing(BuildContext context) {
    return value(context, mobile: 12.0, tablet: 16.0, desktop: 18.0);
  }

  /// Get card aspect ratio
  static double cardAspectRatio(BuildContext context) {
    return value(context, mobile: 0.75, tablet: 0.72, desktop: 0.70);
  }

  /// Get bottom nav icon size
  static double navIconSize(BuildContext context) {
    return value(context, mobile: 24.0, tablet: 28.0, desktop: 30.0);
  }

  /// Get font scale factor
  static double fontScale(BuildContext context) {
    return value(context, mobile: 0.9, tablet: 0.95, desktop: 1.0);
  }
}

/// Extension for easier responsive checks
extension ResponsiveExtension on BuildContext {
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  double get screenWidth => Responsive.width(this);
  double get screenHeight => Responsive.height(this);
}
