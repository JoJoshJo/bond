import 'package:supabase_flutter/supabase_flutter.dart';

import 'spicy_models.dart';

/// Talks to the server-side spicy-mode gate. All timing/entitlement decisions
/// live in the SECURITY DEFINER RPCs (`spicy_status`, `activate_spicy_mode`) —
/// the client only reads the result. Fail-safe: any error → inert/empty status.
class SpicyRepository {
  SpicyRepository(this._client);

  final SupabaseClient _client;

  /// Current authoritative state (called on load / when opening the toggle).
  Future<SpicyStatus> status() async {
    try {
      final rows = await _client.rpc('spicy_status') as List<dynamic>;
      if (rows.isEmpty) return SpicyStatus.empty;
      return SpicyStatus.fromRow(rows.first as Map<String, dynamic>);
    } catch (_) {
      return SpicyStatus.empty;
    }
  }

  /// Ask the server to start (or resume) a spicy session. The server decides
  /// based on its own clock + stored timestamps + entitlement.
  Future<SpicyActivation> activate() async {
    final rows = await _client.rpc('activate_spicy_mode') as List<dynamic>;
    return SpicyActivation.fromRow(rows.first as Map<String, dynamic>);
  }
}
