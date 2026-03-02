import 'package:flutter/material.dart';

class AppColors {
  // ═══════════════════════════════════════════════════════════════
  // MODERN GOURMET PREMIUM PALETTE
  // ═══════════════════════════════════════════════════════════════
  
  // 🎨 Brand Color (Primary) - Rich Metallic Gold
  static const Color primary = Color(0xFFD4AF37); 
  static const Color primaryLight = Color(0xFFF3D586);
  static const Color primaryDark = Color(0xFFA67C00);
  
  // 🌿 Accent Color - Deep Forest Green (Elegant & Organic)
  static const Color secondary = Color(0xFF1A3C34);
  static const Color secondaryLight = Color(0xFF2D5A4E);
  static const Color secondaryDark = Color(0xFF0D211C);
  
  // Keep accent as alias for compatibility
  static const Color accent = Color(0xFF1A3C34);
  static const Color accentLight = Color(0xFF2D5A4E);
  static const Color accentDark = Color(0xFF0D211C);
  
  // Legacy references
  static const Color teal = Color(0xFF1A3C34);
  static const Color tealLight = Color(0xFF2D5A4E);
  static const Color tealDark = Color(0xFF0D211C);
  
  // ⚪ Light Mode Neutrals - Crisp & Clean
  static const Color backgroundLight = Color(0xFFFDFDFD);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF121212);
  static const Color textSecondaryLight = Color(0xFF555555);
  static const Color textTertiaryLight = Color(0xFF888888);
  static const Color dividerLight = Color(0xFFEEEEEE);
  
  // ⚫ Dark Mode Neutrals - Deep & Luxurious
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF141414);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF707070);
  static const Color dividerDark = Color(0xFF2C2C2C);
  
  // Semantic Colors - Muted for premium feel
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);
  
  // Health Tag Colors - Sophisticated Pastels
  static const Color diabetesFriendly = Color(0xFF7986CB);
  static const Color lowSalt = Color(0xFF4DB6AC);
  static const Color heartHealthy = Color(0xFFE57373);
  static const Color weightLoss = Color(0xFF81C784);
  static const Color allergyFree = Color(0xFFFFB74D);
  static const Color quickMeal = Color(0xFFFFD54F);
  static const Color ironRich = Color(0xFFA1887F);
  static const Color proteinRich = Color(0xFF64B5F6);
  
  // ═══════════════════════════════════════════════════════════════
  // PREMIUM GRADIENTS
  // ═══════════════════════════════════════════════════════════════
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFF3D586)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFFFC107)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFE0E0E0)], // Gold to Silver/White
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF1A3C34), Color(0xFF2D5A4E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF1A3C34), Color(0xFF0D211C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFB8860B), Color(0xFFFFD700)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Subtle overlay gradients
  static LinearGradient cardOverlayGradient = LinearGradient(
    colors: [
      Colors.transparent,
      Colors.black.withOpacity(0.8),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static LinearGradient heroOverlayGradient = LinearGradient(
    colors: [
      Colors.black.withOpacity(0.2),
      Colors.black.withOpacity(0.7),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );

  // Shadows - Refined and smooth
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];
  
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 32,
      offset: const Offset(0, 16),
      spreadRadius: -8,
    ),
  ];
  
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 10,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
  ];
  
  // Navigation shadow
  static List<BoxShadow> get navShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, -4),
      spreadRadius: -4,
    ),
  ];
  
  static List<BoxShadow> primaryShadow(double opacity) => [
    BoxShadow(
      color: primary.withOpacity(opacity),
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: -2,
    ),
  ];
}

