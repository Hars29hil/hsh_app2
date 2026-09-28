import 'package:flutter/material.dart';

/// Design system color tokens.
/// Warm hospitality palette:
/// - Terracotta & camel tones
/// - Warm cream backgrounds
/// - Charcoal accents
class AppColors {
  AppColors._();

  // --- Main brand colors ---
  /// Terracotta / Primary: #C44D28
  static const Color primary = Color(0xFFC44D28);
  /// Terracotta light: #D86642
  static const Color primaryLight = Color(0xFFD86642);
  /// Terracotta dark: #7A3723
  static const Color primaryDark = Color(0xFF7A3723);
  /// Header tint (mapped to Terracotta dark for warm, rich headers)
  static const Color headerBlue = Color(0xFF7A3723);

  /// Warm camel / secondary: #8A5B36
  static const Color secondary = Color(0xFF8A5B36);
  /// Camel light: #B27642
  static const Color secondaryLight = Color(0xFFB27642);
  /// Camel dark: #654126
  static const Color secondaryDark = Color(0xFF654126);

  /// Charcoal / accent: #4E4E52
  static const Color accent = Color(0xFF4E4E52);
  /// Charcoal light: #76767B
  static const Color accentLight = Color(0xFF76767B);
  /// Charcoal dark: #2F2F33
  static const Color accentDark = Color(0xFF2F2F33);

  // --- Backgrounds ---
  /// Warm cream background: #FFF4EC
  static const Color mainBackground = Color(0xFFFFF4EC);
  /// Background secondary: #FFF9F5
  static const Color backgroundSecondary = Color(0xFFFFF9F5);
  /// White surface: #FFFFFF
  static const Color surface = Color(0xFFFFFFFF);
  /// Surface muted: #FFF9F5
  static const Color surfaceMuted = Color(0xFFFFF9F5);

  // --- Text ---
  /// Primary text: #2B2B2B
  static const Color textPrimary = Color(0xFF2B2B2B);
  /// Secondary text: #5A5A5A
  static const Color textSecondary = Color(0xFF5A5A5A);
  /// Muted text: #7D7D7D
  static const Color textMuted = Color(0xFF7D7D7D);
  /// Light text: #A3A3A3
  static const Color textLight = Color(0xFFA3A3A3);

  // --- Borders ---
  /// Border: #DDD6CE
  static const Color border = Color(0xFFDDD6CE);
  /// Border light: #EAE5E0
  static const Color borderLight = Color(0xFFEAE5E0);
  /// Border primary: #D86642
  static const Color borderPrimary = Color(0xFFD86642);
  /// Border accent: #76767B
  static const Color borderAccent = Color(0xFF76767B);

  // --- Status colors ---
  /// Success: #2E7D32
  static const Color successGreen = Color(0xFF2E7D32);
  /// Warning: #C17817
  static const Color warningOrange = Color(0xFFC17817);
  /// Error: #C62828
  static const Color cancelledRed = Color(0xFFC62828);
  static const Color errorRed = Color(0xFFC62828);
  /// Info / Pending: #1565C0
  static const Color pendingBlue = Color(0xFF1565C0);

  // --- Supporting tokens ---
  /// Soft terracotta tint for badges, selected pills & wash surfaces
  static const Color primarySoft = Color(0xFFFBECE6);
  /// Soft camel tint
  static const Color secondarySoft = Color(0xFFF6EDE6);
  /// Warm shadow
  static const Color shadow = Color(0xFF2F2F33);

  // --- Gradients ---
  /// Terracotta into Warm Camel
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  /// Hero headers: deep terracotta into warm terracotta and terracotta light
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
    stops: [0.0, 0.55, 1.0],
  );

  /// Buttons: terracotta into terracotta light
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryLight],
  );

  static final List<BoxShadow> softShadow = [
    BoxShadow(
      color: shadow.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}
