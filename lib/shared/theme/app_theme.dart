import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the design tokens into a single [ThemeData]. This is the single
/// source of truth; components read tokens (AppColors/AppSpacing/AppText) and
/// Material widgets inherit from here. Dark mode is future work (would move
/// tokens into a ThemeExtension then).
class AppTheme {
  const AppTheme._();

  /// Backwards-compatible alias — builds from whatever palette is active.
  static ThemeData get light => build();

  /// Builds the theme from the currently active palette ([AppColors.active]),
  /// so a spicy-mode palette swap re-themes everything, dark brightness included.
  static ThemeData build() {
    final brightness =
        AppColors.active.dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.mint,
      primary: AppColors.mint,
      onPrimary: AppColors.onMint,
      surface: AppColors.surface,
      error: AppColors.error,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: AppText.textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
