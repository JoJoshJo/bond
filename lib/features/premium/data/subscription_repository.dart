import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the couple's entitlement from the `subscriptions` table.
///
/// LOCKED RULE: the app NEVER writes this table — it is written ONLY by the
/// (future) RevenueCat webhook Edge Function. This repository is read-only.
///
/// Fail-safe: any error, missing row, or not-yet-deployed table resolves to
/// `'free'`, so gating degrades to locked rather than crashing.
class SubscriptionRepository {
  SubscriptionRepository(this._client);

  final SupabaseClient _client;

  static const entitlementFree = 'free';
  static const entitlementPlus = 'bond_plus';

  /// The active entitlement for a couple: `'bond_plus'` only when a row is
  /// `bond_plus` + `active` + unexpired; otherwise `'free'`.
  Future<String> entitlementFor(String coupleId) async {
    try {
      final row = await _client
          .from('subscriptions')
          .select('entitlement, status, expires_at')
          .eq('couple_id', coupleId)
          .maybeSingle();
      if (row == null) return entitlementFree;

      final entitlement = row['entitlement'] as String?;
      final status = row['status'] as String?;
      if (entitlement != entitlementPlus || status != 'active') {
        return entitlementFree;
      }

      final expiresRaw = row['expires_at'] as String?;
      if (expiresRaw != null) {
        final expires = DateTime.tryParse(expiresRaw);
        if (expires != null && expires.isBefore(DateTime.now())) {
          return entitlementFree;
        }
      }
      return entitlementPlus;
    } catch (_) {
      // Table not deployed yet / transient error → treat as free (fail-locked).
      return entitlementFree;
    }
  }
}
