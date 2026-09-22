import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Outcome of redeeming a promo code.
enum PromoOutcome {
  ok,
  invalid,
  inactive,
  expired,
  alreadyRedeemed,
  alreadyPremium,
  notLinked,
  error,
}

@immutable
class PromoResult {
  const PromoResult(this.outcome, {this.expiresAt, this.days});

  final PromoOutcome outcome;

  /// When the granted (or existing) Usora+ ends.
  final DateTime? expiresAt;
  final int? days;
}

/// Promo-code redemption. The app sends ONLY the code text; the
/// `redeem_promo_code` SECURITY DEFINER function validates it and writes the
/// couple's `subscriptions` row server-side (the app can't write that table).
class PromoRepository {
  PromoRepository(this._client);

  final SupabaseClient _client;

  Future<PromoResult> redeem(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return const PromoResult(PromoOutcome.invalid);
    try {
      final raw = await _client
          .rpc('redeem_promo_code', params: {'p_code': trimmed});
      final r = (raw as Map).cast<String, dynamic>();
      final expires = r['expires_at'] is String
          ? DateTime.tryParse(r['expires_at'] as String)
          : null;
      final days = (r['days'] as num?)?.toInt();
      if (r['ok'] == true) {
        return PromoResult(PromoOutcome.ok, expiresAt: expires, days: days);
      }
      final outcome = switch (r['reason']) {
        'invalid' => PromoOutcome.invalid,
        'inactive' => PromoOutcome.inactive,
        'expired' => PromoOutcome.expired,
        'already_redeemed' => PromoOutcome.alreadyRedeemed,
        'already_premium' => PromoOutcome.alreadyPremium,
        'not_linked' => PromoOutcome.notLinked,
        _ => PromoOutcome.error,
      };
      return PromoResult(outcome, expiresAt: expires);
    } catch (e, st) {
      debugPrint('redeem_promo_code failed: $e\n$st');
      return const PromoResult(PromoOutcome.error);
    }
  }
}
