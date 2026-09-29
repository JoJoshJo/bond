import 'package:flutter/foundation.dart';
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
    } catch (e) {
      // Table not deployed yet / transient error → treat as free (fail-locked).
      // MUST be logged: this is how a paying couple can silently read as free.
      debugPrint('entitlement read failed (treated as free): $e');
      return entitlementFree;
    }
  }

  /// Realtime on the couple's `subscriptions` row, so the RC webhook writing the
  /// couple's entitlement reaches BOTH partners within seconds (Partner B flips
  /// to premium without reopening). Member SELECT RLS permits this.
  RealtimeChannel channel(String coupleId, {required void Function() onChange}) {
    return _client.channel('subscriptions_$coupleId').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: (_) => onChange(),
        );
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);
}
