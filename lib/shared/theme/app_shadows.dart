import 'package:flutter/material.dart';

/// Soft, low-opacity elevation tokens — the "gentle shadow" signature.
/// No hard edges; shadows are diffuse and barely-there to keep the warmth.
class AppShadows {
  const AppShadows._();

  /// Resting card shadow.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F1E3A2E), // ~6% ink-green
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  /// Slightly raised (buttons, active cards).
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x141E3A2E), // ~8%
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  /// Mint-tinted glow (for accent moments — the creature, primary CTAs).
  static const List<BoxShadow> mintGlow = [
    BoxShadow(
      color: Color(0x334CAF8E), // ~20% mint
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
