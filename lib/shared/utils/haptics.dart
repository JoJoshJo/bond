import 'package:flutter/services.dart';

/// Tiny wrapper over [HapticFeedback] so haptics are consistent and named by
/// INTENT rather than platform primitive. Used at meaningful moments only
/// (sends, confirmations, rewards, pickers) — never on every tap.
class Haptics {
  const Haptics._();

  /// A light tap — primary buttons, sends, copies.
  static void tap() => HapticFeedback.lightImpact();

  /// A discrete selection change — toggles, pickers, game moves.
  static void select() => HapticFeedback.selectionClick();

  /// A satisfying confirmation — purchase success, join success, prompt reveal,
  /// game win, bond-score increase (the reward moments).
  static void success() => HapticFeedback.mediumImpact();

  /// A heavier, attention-getting buzz — destructive confirmations only.
  static void warning() => HapticFeedback.heavyImpact();
}
