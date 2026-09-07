import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Minimal Layer 1 theme for the "Modern & Fresh" White + Mint direction.
///
/// Headings: Space Grotesk. Body: DM Sans. Both via google_fonts (no bundled
/// ttf files). This is a scaffold only — the full design system lands in Layer 2.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.mint,
        primary: AppColors.mint,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.white,
    );

    // DM Sans for body text, Space Grotesk applied to display/headline/title.
    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.displayLarge),
      displayMedium: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.displayMedium),
      displaySmall: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.displaySmall),
      headlineLarge: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.headlineLarge),
      headlineMedium: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.headlineMedium),
      headlineSmall: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.headlineSmall),
      titleLarge: GoogleFonts.spaceGrotesk(textStyle: base.textTheme.titleLarge),
    );

    return base.copyWith(
      textTheme: textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
    );
  }
}
