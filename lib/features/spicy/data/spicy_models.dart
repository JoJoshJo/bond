import 'package:flutter/foundation.dart';

/// The authoritative spicy-mode state, as returned by the server RPCs
/// (`spicy_status` / `activate_spicy_mode`). All timing is server-clock based;
/// the client never decides the window.
@immutable
class SpicyStatus {
  const SpicyStatus({
    required this.active,
    required this.unlimited,
    this.sessionExpiresAt,
    this.cooldownUntil,
  });

  /// Free tier: currently inside an active 3-hour session. (Premium: always
  /// false here — premium controls on/off locally; see [unlimited].)
  final bool active;

  /// Premium (BOND+): unlimited, anytime — no server window or cooldown.
  final bool unlimited;

  /// When the current free session ends (server time).
  final DateTime? sessionExpiresAt;

  /// When the 2-week cooldown ends and spicy can be re-activated (server time).
  final DateTime? cooldownUntil;

  factory SpicyStatus.fromRow(Map<String, dynamic> row) => SpicyStatus(
        active: (row['active'] as bool?) ?? false,
        unlimited: (row['unlimited'] as bool?) ?? false,
        sessionExpiresAt: _parse(row['session_expires_at']),
        cooldownUntil: _parse(row['cooldown_until']),
      );

  static DateTime? _parse(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String)?.toLocal();

  static const empty = SpicyStatus(active: false, unlimited: false);
}

/// The result of trying to activate spicy mode.
@immutable
class SpicyActivation {
  const SpicyActivation({
    required this.allowed,
    required this.unlimited,
    this.sessionExpiresAt,
    this.cooldownUntil,
  });

  final bool allowed;
  final bool unlimited;
  final DateTime? sessionExpiresAt;
  final DateTime? cooldownUntil; // set when denied (still in cooldown)

  factory SpicyActivation.fromRow(Map<String, dynamic> row) => SpicyActivation(
        allowed: (row['allowed'] as bool?) ?? false,
        unlimited: (row['unlimited'] as bool?) ?? false,
        sessionExpiresAt: SpicyStatus._parse(row['session_expires_at']),
        cooldownUntil: SpicyStatus._parse(row['cooldown_until']),
      );
}
