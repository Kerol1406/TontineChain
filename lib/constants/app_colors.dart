import 'package:flutter/material.dart';

/// Couleurs principales de l'application
class AppColors {
  // Palette officielle de la maquette
  static const Color primary = Color(0xFF003527);
  static const Color primaryDark = Color(0xFF002117);
  static const Color primaryLight = Color(0xFF0B513D);

  static const Color secondary = Color(0xFFD4AF37);
  static const Color secondaryDark = Color(0xFF9A7F1F);
  static const Color secondaryLight = Color(0xFFF0D67A);

  static const Color tertiary = Color(0xFF735C00);
  static const Color tertiaryDark = Color(0xFF574500);
  static const Color tertiaryLight = Color(0xFFA8891C);

  static const Color neutral = Color(0xFFFDFBF7);
  static const Color background = neutral;
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color textPrimary = Color(0xFF1B1C1A);
  static const Color textSecondary = Color(0xFF404944);
  static const Color textHint = Color(0xFF707974);
  
  static const Color success = Color(0xFF2B6954);
  static const Color warning = secondary;
  static const Color error = Color(0xFFBA1A1A);
  
  static const Color border = Color(0xFFBFC9C3);
  static const Color divider = Color(0xFFE4E2DE);
  
  static const Color disabled = Color(0xFFB7B8B2);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
