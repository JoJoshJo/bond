import 'package:supabase_flutter/supabase_flutter.dart';

import 'creature_models.dart';

/// Reads the couple's derived connection snapshot (bond_score + recent activity)
/// via the get_connection_snapshot RPC. No AI — pure state.
class CreatureRepository {
  CreatureRepository(this._client);

  final SupabaseClient _client;

  Future<ConnectionSnapshot> fetchSnapshot() async {
    final rows = await _client.rpc('get_connection_snapshot') as List<dynamic>;
    if (rows.isEmpty) return ConnectionSnapshot.neutral;
    return ConnectionSnapshot.fromRow(rows.first as Map<String, dynamic>);
  }
}
