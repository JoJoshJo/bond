import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A selectable app theme (a full [BondPalette] + display metadata). Mint is the
/// free default; the rest are Usora+. The red-room palette is NOT here — spicy
/// mode owns it and overrides any chosen theme while active.
@immutable
class BondTheme {
  const BondTheme({
    required this.key,
    required this.label,
    required this.palette,
    this.premium = true,
  });

  final String key; // persisted in SharedPreferences
  final String label;
  final BondPalette palette;
  final bool premium;
}

// ---- Sunset — warm peach / terracotta (light) ----
const _sunset = BondPalette(
  bg: Color(0xFFFFF8F3),
  bgAlt: Color(0xFFFDEEE3),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFFDF0E7),
  border: Color(0xFFF1DDCE),
  borderSoft: Color(0xFFF7E9DE),
  mint: Color(0xFFE8825B),
  mintSoft: Color(0xFFF0B9A0),
  mintWash: Color(0xFFFCEBE0),
  mintDeep: Color(0xFFC75F3B),
  onMint: Color(0xFF2A130B),
  ink: Color(0xFF3A2A22),
  inkMuted: Color(0xFF8A7266),
  inkFaint: Color(0xFFB7A093),
  success: Color(0xFF3FA981),
  successBg: Color(0xFFE9F4EE),
  warning: Color(0xFFCF9A3C),
  warningBg: Color(0xFFF8EFDD),
  error: Color(0xFFD9695E),
  errorBg: Color(0xFFF9E7E2),
  dark: false,
  // Ported designs: deep terracotta hierarchy, gold accent, terracotta bubbles (white 5.2:1); tints ink ≥11.2:1, anchor ≥8.5:1.
  anchor: Color(0xFF6A2E16),
  accent: Color(0xFFC0821A),
  chatMine: Color(0xFFB24E2B),
  onChatMine: Color(0xFFFFFFFF),
  doodle: Color(0xFFC75F3B),
  gameTints: [
    Color(0xFFFCEADF),
    Color(0xFFFBF1D9),
    Color(0xFFF9E4E6),
    Color(0xFFEAF1E6),
  ],
  accentWash: Color(0xFFF6E7C8),
  onAccentWash: Color(0xFF7A4E08),
  usTints: UsTints(
    planning: Color(0xFFFDF2EA),
    privacy: Color(0xFFF8F1EC),
    personalize: Color(0xFFFBEFEF),
    spicy: Color(0xFFFCF5E8),
    neutral: Color(0xFFF8F4F1),
  ),
  usMembership: [Color(0xFFFCEFD3), Color(0xFFF7E1B8)],
);

// ---- Ocean — calm teal / blue (light) ----
const _ocean = BondPalette(
  bg: Color(0xFFF6FAFB),
  bgAlt: Color(0xFFE8F1F4),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFEEF6F8),
  border: Color(0xFFD5E4E9),
  borderSoft: Color(0xFFE4EFF2),
  mint: Color(0xFF2E9CB8),
  mintSoft: Color(0xFF9AD0DD),
  mintWash: Color(0xFFE4F2F5),
  mintDeep: Color(0xFF1F7A93),
  onMint: Color(0xFF06222A),
  ink: Color(0xFF21343A),
  inkMuted: Color(0xFF5F757D),
  inkFaint: Color(0xFF92A6AC),
  success: Color(0xFF3FA981),
  successBg: Color(0xFFE3F3EC),
  warning: Color(0xFFCF9A3C),
  warningBg: Color(0xFFF6EEDA),
  error: Color(0xFFD9695E),
  errorBg: Color(0xFFF6E5E2),
  dark: false,
  // Ported designs: deep teal hierarchy, gold accent, teal bubbles (white 5.7:1); tints ink ≥10.8:1, anchor ≥8.7:1.
  anchor: Color(0xFF0E4555),
  accent: Color(0xFFC0821A),
  chatMine: Color(0xFF1C6F86),
  onChatMine: Color(0xFFFFFFFF),
  doodle: Color(0xFF1F7A93),
  gameTints: [
    Color(0xFFE2F2F5),
    Color(0xFFFBEEDB),
    Color(0xFFE7EAF8),
    Color(0xFFE4F3EA),
  ],
  accentWash: Color(0xFFF6E7C8),
  onAccentWash: Color(0xFF7A4E08),
  usTints: UsTints(
    planning: Color(0xFFEEF6F4),
    privacy: Color(0xFFEEF3FA),
    personalize: Color(0xFFF4F1FA),
    spicy: Color(0xFFFBF4EC),
    neutral: Color(0xFFF3F6F7),
  ),
  usMembership: [Color(0xFFFCEFD3), Color(0xFFF7E1B8)],
);

// ---- Lavender — soft dusk lilac / violet (light) ----
const _lavender = BondPalette(
  bg: Color(0xFFFBF8FD),
  bgAlt: Color(0xFFF1EAF8),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF5EFFA),
  border: Color(0xFFE4D9F0),
  borderSoft: Color(0xFFEFE7F7),
  mint: Color(0xFF8E6FC7),
  mintSoft: Color(0xFFC3AEE6),
  mintWash: Color(0xFFF0E9F9),
  mintDeep: Color(0xFF6E4FA8),
  onMint: Color(0xFF1A1030),
  ink: Color(0xFF2E2540),
  inkMuted: Color(0xFF6F6484),
  inkFaint: Color(0xFFA79DBA),
  success: Color(0xFF3FA981),
  successBg: Color(0xFFE9F2EE),
  warning: Color(0xFFCF9A3C),
  warningBg: Color(0xFFF5EEDD),
  error: Color(0xFFD9695E),
  errorBg: Color(0xFFF6E6EC),
  dark: false,
  // Ported designs: deep violet hierarchy, honey accent, violet bubbles (white 6.7:1), rose-gold membership; tints ink ≥12:1, anchor ≥10.5:1.
  anchor: Color(0xFF3A2766),
  accent: Color(0xFFB7791F),
  chatMine: Color(0xFF6A4BA3),
  onChatMine: Color(0xFFFFFFFF),
  doodle: Color(0xFF6E4FA8),
  gameTints: [
    Color(0xFFEFE8F9),
    Color(0xFFF9E6EE),
    Color(0xFFE6EEF8),
    Color(0xFFFBF0DC),
  ],
  accentWash: Color(0xFFF6E7C8),
  onAccentWash: Color(0xFF7A4E08),
  usTints: UsTints(
    planning: Color(0xFFF4F0FA),
    privacy: Color(0xFFEFF1FA),
    personalize: Color(0xFFFAF0F5),
    spicy: Color(0xFFFBF3EE),
    neutral: Color(0xFFF5F3F8),
  ),
  usMembership: [Color(0xFFFBEBDD), Color(0xFFF4D9C4)],
);

// ---- Charcoal — warm dark mono (dark) ----
const _charcoal = BondPalette(
  bg: Color(0xFF1C1B1A),
  bgAlt: Color(0xFF242322),
  surface: Color(0xFF2A2827),
  surfaceAlt: Color(0xFF322F2E),
  border: Color(0xFF403D3B),
  borderSoft: Color(0xFF35322F),
  mint: Color(0xFFBFB3A6),
  mintSoft: Color(0xFF8F8578),
  mintWash: Color(0xFF2E2B28),
  mintDeep: Color(0xFFD8CCBE),
  onMint: Color(0xFF1A1714),
  ink: Color(0xFFEDE9E4),
  inkMuted: Color(0xFFB0A89F),
  inkFaint: Color(0xFF7C756D),
  success: Color(0xFF6FB496),
  successBg: Color(0xFF243029),
  warning: Color(0xFFD6A972),
  warningBg: Color(0xFF33291D),
  error: Color(0xFFD98A83),
  errorBg: Color(0xFF352220),
  dark: true,
  // Ported designs, dark: bright warm-white hierarchy, sand-gold accent, taupe bubbles (white 6.2:1), faint light doodles; tints ink ≥11:1, anchor ≥12:1.
  anchor: Color(0xFFF7F3EE),
  accent: Color(0xFFD6A972),
  chatMine: Color(0xFF6B5F54),
  onChatMine: Color(0xFFFFFFFF),
  doodle: Color(0xFFD8CCBE),
  doodleOpacity: 0.1,
  gameTints: [
    Color(0xFF332E27),
    Color(0xFF2C302C),
    Color(0xFF322A2C),
    Color(0xFF2A2E33),
  ],
  accentWash: Color(0xFF3B301F),
  onAccentWash: Color(0xFFEBC690),
  usTints: UsTints(
    planning: Color(0xFF2B2D2A),
    privacy: Color(0xFF292B30),
    personalize: Color(0xFF302A2B),
    spicy: Color(0xFF302B25),
    neutral: Color(0xFF2E2C2A),
  ),
  usMembership: [Color(0xFF43351F), Color(0xFF52401F)],
);

/// The theme catalog. Mint is free + default; the rest are Usora+.
const List<BondTheme> bondThemes = [
  BondTheme(key: 'mint', label: 'Mint', palette: mintPalette, premium: false),
  BondTheme(key: 'sunset', label: 'Sunset', palette: _sunset),
  BondTheme(key: 'ocean', label: 'Ocean', palette: _ocean),
  BondTheme(key: 'lavender', label: 'Lavender', palette: _lavender),
  BondTheme(key: 'charcoal', label: 'Charcoal', palette: _charcoal),
];

/// The palette for a saved theme key; unknown/missing → mint.
BondPalette paletteForKey(String? key) {
  for (final t in bondThemes) {
    if (t.key == key) return t.palette;
  }
  return mintPalette;
}

/// The [BondTheme] for a key (unknown → the mint entry).
BondTheme bondThemeForKey(String? key) {
  for (final t in bondThemes) {
    if (t.key == key) return t;
  }
  return bondThemes.first;
}
