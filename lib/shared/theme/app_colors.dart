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
    this.anchor,
    this.accent,
    this.chatMine,
    this.onChatMine,
    this.doodle,
    this.doodleOpacity,
    this.gameTints,
    this.accentWash,
    this.onAccentWash,
    this.usTints,
    this.usMembership,
  });

  final Color bg, bgAlt, surface, surfaceAlt;
  final Color border, borderSoft;
  final Color mint, mintSoft, mintWash, mintDeep, onMint;
  final Color ink, inkMuted, inkFaint;
  final Color success, successBg, warning, warningBg, error, errorBg;

  /// True for a dark-brightness palette (drives ThemeData.brightness etc.).
  final bool dark;

  /// Optional deep tone for headings/anchors (stronger hierarchy). Themes that
  /// don't set it fall back to [ink].
  final Color? anchor;

  /// Optional warm accent used sparingly (~10%) — e.g. the bond flame + meter
  /// fill. Themes that don't set it fall back to [warning].
  final Color? accent;

  /// Optional partner-chat "my bubble" fill + its text color, chosen so text
  /// clears WCAG 4.5:1. Themes that don't set them keep [mint] / [onMint].
  final Color? chatMine;
  final Color? onChatMine;

  /// Optional stroke color for the chat doodle background. Null = that theme
  /// shows no doodles (keeps its existing plain look).
  final Color? doodle;

  /// Optional doodle strength (dark themes draw fainter, light-on-dark
  /// strokes). Null = [DoodleBackground.defaultOpacity].
  final double? doodleOpacity;

  /// Optional soft pastel tints for the Games grid (each game gets a stable
  /// one). Null = game tiles keep the plain [surface] look.
  final List<Color>? gameTints;

  /// Optional pale accent wash + its readable text color, for small "your turn"
  /// callouts (the solid [accent] is too light to carry text). Fallbacks:
  /// [warningBg] / [ink].
  final Color? accentWash;
  final Color? onAccentWash;

  /// Optional whisper-faint card fills for the "Us" settings sections, keyed
  /// by section (planning, privacy, personalize, spicy, neutral). Null = the
  /// cards stay [surface].
  final UsTints? usTints;

  /// Optional light-gold two-stop fill for the Membership standout card.
  final List<Color>? usMembership;
}

/// Faint per-section card fills for the "Us" screen.
@immutable
class UsTints {
  const UsTints({
    required this.planning,
    required this.privacy,
    required this.personalize,
    required this.spicy,
    required this.neutral,
  });

  final Color planning, privacy, personalize, spicy, neutral;
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
  inkMuted: Color(0xFF66766E), // deepened from 6B7B74 → WCAG 4.5:1 on white
  inkFaint: Color(0xFF9AAAA3),
  success: Color(0xFF3FA981),
  successBg: Color(0xFFE6F4EE),
  warning: Color(0xFFCF9A3C),
  warningBg: Color(0xFFF8EFDD),
  error: Color(0xFFD9695E),
  errorBg: Color(0xFFF7E5E2),
  dark: false,
  anchor: Color(0xFF1F4D3A), // deep forest green — headings (≥8.6:1)
  accent: Color(0xFFC0821A), // gold — flame + meter fill (3.3:1 on white)
  chatMine: Color(0xFF2F7D62), // brand green; white text on it = 4.96:1
  onChatMine: Color(0xFFFFFFFF),
  doodle: Color(0xFF3B9274), // drawn at low opacity behind the partner chat
  // Games grid pastels. Titles/icons (anchor) ≥8.0:1, taglines (ink) ≥11.5:1
  // on every one.
  gameTints: [
    Color(0xFFE4F3EA), // 0 soft green
    Color(0xFFFBEEDB), // 1 warm peach / gold
    Color(0xFFF9E6E8), // 2 blush
    Color(0xFFE4EEF8), // 3 soft blue
  ],
  accentWash: Color(0xFFF6E7C8), // pale gold
  onAccentWash: Color(0xFF7A4E08), // dark gold text on it = 5.88:1
  // "Us" section cards. ink ≥12.3:1 on each (inkMuted fails: ≤4.42 — so
  // text on these uses ink).
  usTints: UsTints(
    planning: Color(0xFFF0F7F2), // faint green
    privacy: Color(0xFFEFF3FA), // faint blue
    personalize: Color(0xFFFAF1F2), // faint blush
    spicy: Color(0xFFFCF4EC), // faint warm
    neutral: Color(0xFFF4F6F5), // settings / developer / legal
  ),
  // Membership standout: light gold, ink ≥10.7:1 across the gradient.
  usMembership: [Color(0xFFFCEFD3), Color(0xFFF7E1B8)],
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
  // Ported designs, spicy dark: blush-white hierarchy, warm gold accent, wine bubbles (white 7.6:1), faint light doodles; tints ink ≥10.6:1, anchor ≥12:1.
  anchor: Color(0xFFFAEEEE),
  accent: Color(0xFFD9A866),
  chatMine: Color(0xFF8A3A46),
  onChatMine: Color(0xFFFFFFFF),
  doodle: Color(0xFFD79AA0),
  doodleOpacity: 0.1,
  gameTints: [
    Color(0xFF3A2530),
    Color(0xFF33282A),
    Color(0xFF382B22),
    Color(0xFF2E2636),
  ],
  accentWash: Color(0xFF3D2C1E),
  onAccentWash: Color(0xFFEDC78F),
  usTints: UsTints(
    planning: Color(0xFF30252A),
    privacy: Color(0xFF2C2530),
    personalize: Color(0xFF35262B),
    spicy: Color(0xFF3B2527),
    neutral: Color(0xFF312729),
  ),
  usMembership: [Color(0xFF46331F), Color(0xFF553D22)],
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

  /// Deep heading/anchor tone (forest green on mint; [ink] elsewhere).
  static Color get anchor => active.anchor ?? active.ink;

  /// Sparing warm accent (gold on mint; [warning] elsewhere).
  static Color get accent => active.accent ?? active.warning;

  /// Partner-chat "my bubble" fill + text (white on green on mint).
  static Color get chatMine => active.chatMine ?? active.mint;
  static Color get onChatMine => active.onChatMine ?? active.onMint;

  /// Chat doodle stroke color, or null when the theme has no doodles.
  static Color? get doodle => active.doodle;

  /// Chat doodle strength for the active theme (null = widget default).
  static double? get doodleOpacity => active.doodleOpacity;

  /// Games-grid tints, or null when the theme keeps plain tiles.
  static List<Color>? get gameTints => active.gameTints;

  /// Pale accent wash + readable text on it (e.g. the "Your turn" callouts).
  static Color get accentWash => active.accentWash ?? active.warningBg;
  static Color get onAccentWash => active.onAccentWash ?? active.ink;

  /// "Us" section card fill, or [surface] on themes without tints.
  static Color usTint(Color Function(UsTints t) pick) {
    final t = active.usTints;
    return t == null ? active.surface : pick(t);
  }

  /// True when the "Us" cards are tinted (their text must then use [ink]).
  static bool get usTinted => active.usTints != null;

  /// Membership gold gradient, or null (plain [surface]) on other themes.
  static List<Color>? get usMembership => active.usMembership;
}
