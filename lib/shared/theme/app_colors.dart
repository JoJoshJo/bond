import 'package:flutter/material.dart';

/// Minimal color tokens for the locked "Modern & Fresh" White + Mint scheme.
///
/// Layer 1 scaffold only — the full design system (shades, states, dark mode)
/// is built in Layer 2. Keep additions here small until then.
class AppColors {
  const AppColors._();

  /// Primary mint accent.
  static const Color mint = Color(0xFF3FD6A8);

  /// Softer mint for fills/tints.
  static const Color mintSoft = Color(0xFFE6FAF3);

  /// Base white background.
  static const Color white = Color(0xFFFFFFFF);

  /// Near-white surface for cards, kept soft (not clinical).
  static const Color surface = Color(0xFFF7FBF9);

  /// Primary text.
  static const Color ink = Color(0xFF14201B);

  /// Muted/secondary text.
  static const Color inkMuted = Color(0xFF6B7B74);
}
