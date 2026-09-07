import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A user's couple membership + the couple's current status, used for routing.
class CoupleMembership {
  const CoupleMembership({
    required this.coupleId,
    required this.coupleName,
    required this.status,
  });

  final String coupleId;
  final String coupleName;
  final String status; // pending | active | sealed | winding_down

  bool get isPending => status == 'pending';
  bool get isLinked => status == 'active' || status == 'sealed';
}

/// The active invite for a pending couple (shown on the waiting screen).
class CoupleInvite {
  const CoupleInvite({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  /// The shareable/QR URL. Deep-link auto-open lands with the OAuth task;
  /// until then the token is also entered/pasted manually.
  String get inviteUrl => 'https://bond.app/invite/$token';
}

/// Result of a join attempt, mirroring the join_couple() jsonb contract.
class JoinResult {
  const JoinResult({required this.ok, this.reason, this.coupleId});

  final bool ok;
  final String? reason; // invalid|expired|consumed|revoked|already_complete|already_in_couple|not_authenticated
  final String? coupleId;
}

/// All couple-linking data access. RPCs are the vetted server-side path;
/// direct table reads are RLS-guarded to the user's own couple.
class CoupleRepository {
  CoupleRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  /// The current user's membership, or null if they aren't in a couple yet.
  Future<CoupleMembership?> getMyMembership() async {
    final uid = _uid;
    if (uid == null) return null;

    final row = await _client
        .from('couple_members')
        .select('couple_id, couples(name, status)')
        .eq('user_id', uid)
        .maybeSingle();

    if (row == null) return null;
    final couple = row['couples'] as Map<String, dynamic>?;
    if (couple == null) return null;

    return CoupleMembership(
      coupleId: row['couple_id'] as String,
      coupleName: (couple['name'] as String?) ?? 'Us',
      status: (couple['status'] as String?) ?? 'pending',
    );
  }

  /// The active invite for a couple, if any (re-fetched when A returns to the
  /// waiting screen).
  Future<CoupleInvite?> getActiveInvite(String coupleId) async {
    final row = await _client
        .from('couple_invites')
        .select('token, expires_at')
        .eq('couple_id', coupleId)
        .eq('token_status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return CoupleInvite(
      token: row['token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  /// Create a couple (pending), become member #1, generate the first invite.
  Future<CoupleInvite> createCouple(String coupleName) async {
    final rows = await _client.rpc(
      'create_couple',
      params: {'p_name': coupleName},
    ) as List<dynamic>;
    final row = rows.first as Map<String, dynamic>;
    return CoupleInvite(
      token: row['invite_token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  /// Revoke the active token and mint a fresh one.
  Future<CoupleInvite> regenerateInvite() async {
    final rows = await _client.rpc('regenerate_invite') as List<dynamic>;
    final row = rows.first as Map<String, dynamic>;
    return CoupleInvite(
      token: row['invite_token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  /// Partner B joins via the token. Server enforces every rule atomically.
  Future<JoinResult> joinCouple(String token) async {
    final res = await _client.rpc(
      'join_couple',
      params: {'p_token': token},
    ) as Map<String, dynamic>;
    return JoinResult(
      ok: res['ok'] == true,
      reason: res['reason'] as String?,
      coupleId: res['couple_id'] as String?,
    );
  }

  /// Live stream of a couple's `status`. Partner A watches this while waiting;
  /// when B joins, join_couple flips status → 'active' and this emits it,
  /// driving the simultaneous unlock.
  Stream<String> watchCoupleStatus(String coupleId) {
    final controller = StreamController<String>();
    final channel = _client.channel('couple_status_$coupleId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: coupleId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != null) controller.add(status);
          },
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }
}
