import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Every text style defined once. Space Grotesk (display/headings),
/// DM Sans (body/UI), JetBrains Mono (timestamps/code). Components use these —
/// never call GoogleFonts directly elsewhere.
class AppText {
  const AppText._();

  static TextStyle _grotesk({
    required double size,
    required double height,
    FontWeight weight = FontWeight.w600,
    double spacing = -0.2,
    Color color = AppColors.ink,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color,
      );

  static TextStyle _dmSans({
    required double size,
    required double height,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    Color color = AppColors.ink,
  }) =>
      GoogleFonts.dmSans(
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color,
      );

  // ---- Display / headings (Space Grotesk) ----
  static TextStyle get displayLarge =>
      _grotesk(size: 40, height: 1.08, weight: FontWeight.w700);
  static TextStyle get displayMedium =>
      _grotesk(size: 32, height: 1.12, weight: FontWeight.w700);
  static TextStyle get headline =>
      _grotesk(size: 26, height: 1.18, weight: FontWeight.w600);
  static TextStyle get title =>
      _grotesk(size: 20, height: 1.25, weight: FontWeight.w600);

  // ---- Body / UI (DM Sans) ----
  static TextStyle get bodyLarge => _dmSans(size: 17, height: 1.45);
  static TextStyle get bodyMedium => _dmSans(size: 15, height: 1.45);
  static TextStyle get bodySmall =>
      _dmSans(size: 13, height: 1.4, color: AppColors.inkMuted);
  static TextStyle get label =>
      _dmSans(size: 14, height: 1.2, weight: FontWeight.w600);

  // ---- Mono (JetBrains Mono) ----
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        height: 1.3,
        color: AppColors.inkMuted,
      );

  /// Builds a Material TextTheme from the styles above.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: headline,
        headlineMedium: headline,
        headlineSmall: title,
        titleLarge: title,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: label,
      );
}
