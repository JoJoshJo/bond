import 'package:flutter/material.dart';

/// The full set of color tokens as a swappable palette. Two instances exist:
/// [mintPalette] (the default White + Mint scheme) and [redRoomPalette] (the
/// Spicy-mode "red room"). The active palette is chosen at runtime.
///
/// Token names are SEMANTIC — `mint` means "the signature accent", `bg` the app
/// background, `ink` the primary text — so red-room can reuse every name with
/// different values, and the app's 290+ `AppColors.*` call sites never change.
@immutable
class BondPalette {
  const BondPalette({
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderSoft,
    required this.mint,
    required this.mintSoft,
    required this.mintWash,
    required this.mintDeep,
    required this.onMint,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.dark,
  });

  final Color bg, bgAlt, surface, surfaceAlt;
  final Color border, borderSoft;
  final Color mint, mintSoft, mintWash, mintDeep, onMint;
  final Color ink, inkMuted, inkFaint;
  final Color success, successBg, warning, warningBg, error, errorBg;

  /// True for a dark-brightness palette (drives ThemeData.brightness etc.).
  final bool dark;
}

/// The locked "Modern & Fresh" White + Mint scheme — soft, warm, low-saturation.
const BondPalette mintPalette = BondPalette(
  bg: Color(0xFFFCFDFC),
  bgAlt: Color(0xFFF0F6F3),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF4F9F6),
  border: Color(0xFFE1EAE5),
  borderSoft: Color(0xFFEDF3F0),
  mint: Color(0xFF4CAF8E),
  mintSoft: Color(0xFFA8D8C4),
  mintWash: Color(0xFFEAF5F0),
  mintDeep: Color(0xFF3B9274),
  onMint: Color(0xFF12261F),
  ink: Color(0xFF22302B),
  inkMuted: Color(0xFF6B7B74),
  inkFaint: Color(0xFF9AAAA3),
  success: Color(0xFF3FA981),
  successBg: Color(0xFFE6F4EE),
  warning: Color(0xFFCF9A3C),
  warningBg: Color(0xFFF8EFDD),
  error: Color(0xFFD9695E),
  errorBg: Color(0xFFF7E5E2),
  dark: false,
);

/// Spicy mode's "red room" — deep warm reds, sultry dark, a luminous rose accent.
/// Same semantic tokens: `mint` here is the rose/crimson accent, `ink` is warm
/// off-white text on the dark ground.
const BondPalette redRoomPalette = BondPalette(
  bg: Color(0xFF17090C),        // deep dark wine (richer, higher-contrast base)
  bgAlt: Color(0xFF200D11),
  surface: Color(0xFF2C2023),   // gentle warm card, low contrast on bg
  surfaceAlt: Color(0xFF352629),
  border: Color(0xFF3E2E31),
  borderSoft: Color(0xFF33262A),
  mint: Color(0xFFC97F87),      // muted dusty rose accent (not hot pink)
  mintSoft: Color(0xFF9E6A72),
  mintWash: Color(0xFF2F2225),  // soft rose wash for fills
  mintDeep: Color(0xFFD79AA0),  // gently lifted rose for text on dark
  onMint: Color(0xFF20140F),
  ink: Color(0xFFEDE0E1),       // warm off-white, softened (not pure white)
  inkMuted: Color(0xFFBBA3A7),
  inkFaint: Color(0xFF8A7377),
  success: Color(0xFF6FB496),
  successBg: Color(0xFF223029),
  warning: Color(0xFFD6A972),
  warningBg: Color(0xFF33281D),
  error: Color(0xFFD98A83),
  errorBg: Color(0xFF35201F),
  dark: true,
);

/// Runtime color accessor. Keeps the original static API (`AppColors.mint`,
/// `AppColors.bg`, …) but resolves each token from the currently [active]
/// palette, so flipping [active] and rebuilding re-themes the whole app.
///
/// No component should hardcode a color; use these tokens.
class AppColors {
  const AppColors._();

  /// The palette every token reads from. Swapped by the theme layer (spicy mode).
  static BondPalette active = mintPalette;

  static Color get bg => active.bg;
  static Color get bgAlt => active.bgAlt;
  static Color get surface => active.surface;
  static Color get surfaceAlt => active.surfaceAlt;

  static Color get border => active.border;
  static Color get borderSoft => active.borderSoft;

  static Color get mint => active.mint;
  static Color get mintSoft => active.mintSoft;
  static Color get mintWash => active.mintWash;
  static Color get mintDeep => active.mintDeep;
  static Color get onMint => active.onMint;

  static Color get ink => active.ink;
  static Color get inkMuted => active.inkMuted;
  static Color get inkFaint => active.inkFaint;

  static Color get success => active.success;
  static Color get successBg => active.successBg;
  static Color get warning => active.warning;
  static Color get warningBg => active.warningBg;
  static Color get error => active.error;
  static Color get errorBg => active.errorBg;
}
