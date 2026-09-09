import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A selectable app theme (a full [BondPalette] + display metadata). Mint is the
/// free default; the rest are BOND+. The red-room palette is NOT here — spicy
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
);

/// The theme catalog. Mint is free + default; the rest are BOND+.
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
