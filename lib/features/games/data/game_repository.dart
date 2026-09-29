import 'package:supabase_flutter/supabase_flutter.dart';

import 'board_models.dart';
import 'game_models.dart';

/// Data access for the game engine. Session create/complete go through vetted
/// SECURITY DEFINER RPCs; moves are plain member-scoped inserts/reads (RLS).
class GameRepository {
  GameRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Start a new session for this game type, or resume the couple's unfinished
  /// one (pause/resume = resume-unfinished-session).
  Future<GameSession> startOrResume(String gameType) async {
    final rows = await _client.rpc('start_or_resume_game',
        params: {'p_game_type': gameType}) as List<dynamic>;
    return GameSession.fromRow(rows.first as Map<String, dynamic>);
  }

  /// The couple's UNFINISHED sessions — READ-ONLY (never creates one, unlike
  /// [startOrResume]). Used by the hub to work out whose move it is.
  Future<List<GameSession>> unfinishedSessions(String coupleId) async {
    final rows = await _client
        .from('game_sessions')
        .select('id, game_type, mode, status')
        .eq('couple_id', coupleId)
        .neq('status', 'completed');
    return (rows as List<dynamic>)
        .map((r) => GameSession.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<GameSession?> fetchSession(String sessionId) async {
    final row = await _client
        .from('game_sessions')
        .select('id, game_type, mode, status')
        .eq('id', sessionId)
        .maybeSingle();
    return row == null ? null : GameSession.fromRow(row);
  }

  Future<List<GameMove>> fetchMoves(String sessionId) async {
    final rows = await _client
        .from('game_moves')
        .select('user_id, move_data')
        .eq('session_id', sessionId);
    return (rows as List<dynamic>)
        .map((r) => GameMove.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitMove({
    required String sessionId,
    required String userId,
    required int round,
    required int choice,
  }) async {
    await _client.from('game_moves').insert({
      'session_id': sessionId,
      'user_id': userId,
      'move_data': {'round': round, 'choice': choice},
    });
  }

  // ---- Board games: generic move_data, ordered replay, member ids ----

  /// The couple's two member user ids (sorted) — deterministic player order.
  Future<List<String>> memberIds(String coupleId) async {
    final rows = await _client
        .from('couple_members')
        .select('user_id')
        .eq('couple_id', coupleId);
    final ids = (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
        .toList()
      ..sort();
    return ids;
  }

  /// All moves for a session in play order (created_at), with raw move_data.
  Future<List<RawMove>> fetchRawMoves(String sessionId) async {
    final rows = await _client
        .from('game_moves')
        .select('user_id, move_data, created_at')
        .eq('session_id', sessionId)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((r) => RawMove.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Insert a board move with arbitrary move_data.
  Future<void> submitRawMove({
    required String sessionId,
    required String userId,
    required Map<String, dynamic> moveData,
  }) async {
    await _client.from('game_moves').insert({
      'session_id': sessionId,
      'user_id': userId,
      'move_data': moveData,
    });
  }

  /// The couple that owns a session (to resolve member ids).
  Future<String?> coupleIdForSession(String sessionId) async {
    final row = await _client
        .from('game_sessions')
        .select('couple_id')
        .eq('id', sessionId)
        .maybeSingle();
    return row?['couple_id'] as String?;
  }

  /// Idempotent completion + monotonic XP award. Returns the new bond_score.
  Future<int> complete(String sessionId, int xp) async {
    final res = await _client.rpc('complete_game_session',
        params: {'p_session_id': sessionId, 'p_xp': xp});
    return (res as num).toInt();
  }

  RealtimeChannel channel(
    String sessionId, {
    required void Function() onMoveChange,
    required void Function() onSessionChange,
  }) {
    return _client
        .channel('game_$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_moves',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (_) => onMoveChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (_) => onSessionChange(),
        );
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);
}
