import 'package:flutter/material.dart';

/// Color tokens for the locked "Modern & Fresh" White + Mint scheme.
///
/// Locked values: mint #4CAF8E + soft #A8D8C4, bg #FCFDFC / #F0F6F3,
/// ink #22302B. Everything is tuned SOFT — low saturation, warm — to avoid the
/// clinical/medical trap. No component should hardcode a color; use these.
class AppColors {
  const AppColors._();

  // ---- Backgrounds & surfaces ----
  /// Primary app background (bright, minimal white).
  static const Color bg = Color(0xFFFCFDFC);

  /// Alt background for subtle zoning / sheets.
  static const Color bgAlt = Color(0xFFF0F6F3);

  /// Card / surface color (near-white, a touch of warmth).
  static const Color surface = Color(0xFFFFFFFF);

  /// Slightly raised/tinted surface (chips, wells).
  static const Color surfaceAlt = Color(0xFFF4F9F6);

  // ---- Borders ----
  static const Color border = Color(0xFFE1EAE5);
  static const Color borderSoft = Color(0xFFEDF3F0);

  // ---- Mint (signature accent) ----
  static const Color mint = Color(0xFF4CAF8E);

  /// Soft mint for fills/tints/backgrounds behind mint content.
  static const Color mintSoft = Color(0xFFA8D8C4);

  /// Very light mint wash for subtle fills.
  static const Color mintWash = Color(0xFFEAF5F0);

  /// Deeper mint for pressed/active states.
  static const Color mintDeep = Color(0xFF3B9274);

  /// Foreground color to place ON mint surfaces (kept dark for warmth/contrast).
  static const Color onMint = Color(0xFF12261F);

  // ---- Text (ink) ----
  static const Color ink = Color(0xFF22302B);
  static const Color inkMuted = Color(0xFF6B7B74);
  static const Color inkFaint = Color(0xFF9AAAA3);

  // ---- Semantic (soft/warm variants, not harsh) ----
  static const Color success = Color(0xFF3FA981);
  static const Color successBg = Color(0xFFE6F4EE);
  static const Color warning = Color(0xFFCF9A3C);
  static const Color warningBg = Color(0xFFF8EFDD);
  static const Color error = Color(0xFFD9695E); // warm coral, not fire-engine
  static const Color errorBg = Color(0xFFF7E5E2);
}
