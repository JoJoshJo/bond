import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../creature/application/creature_controller.dart';
import '../data/board_models.dart';
import '../data/game_repository.dart';
import 'game_controller.dart' show gameRepositoryProvider;

class BoardGameState {
  const BoardGameState({
    this.loading = true,
    this.gameType = '',
    this.players = const [],
    this.moves = const [],
    this.newScore,
    this.error,
  });

  final bool loading;
  final String gameType;
  final List<String> players; // sorted uids; players[0] moves first
  final List<RawMove> moves;
  final int? newScore; // set once completed + XP awarded
  final String? error;

  BoardGameState copyWith({
    bool? loading,
    String? gameType,
    List<String>? players,
    List<RawMove>? moves,
    Object? newScore = _s,
    Object? error = _s,
  }) =>
      BoardGameState(
        loading: loading ?? this.loading,
        gameType: gameType ?? this.gameType,
        players: players ?? this.players,
        moves: moves ?? this.moves,
        newScore: newScore == _s ? this.newScore : newScore as int?,
        error: error == _s ? this.error : error as String?,
      );

  static const _s = Object();
}

/// Drives a turn-based board game over the existing game backend. Win-logic is
/// game-specific (in the pure engines); this owns moves, realtime, and XP.
class BoardGameController extends StateNotifier<BoardGameState> {
  BoardGameController(this._repo, this._sessionId, {this.onCompleted})
      : super(const BoardGameState()) {
    _init();
  }

  final GameRepository _repo;
  final String _sessionId;
  final void Function()? onCompleted;
  RealtimeChannel? _channel;
  bool _finishing = false;

  String get me => _repo.currentUserId ?? '';

  Future<void> _init() async {
    try {
      final session = await _repo.fetchSession(_sessionId);
      if (!mounted) return;
      if (session == null) {
        state = state.copyWith(loading: false, error: 'Couldn\'t load the game.');
        return;
      }
      final coupleId = await _repo.coupleIdForSession(_sessionId);
      final players =
          coupleId == null ? <String>[] : await _repo.memberIds(coupleId);
      final moves = await _repo.fetchRawMoves(_sessionId);
      if (!mounted) return;
      // loading is done once we know the session/players/moves — even with
      // only 1 member (the screen shows a "needs your partner" state then).
      state = state.copyWith(
        loading: false,
        gameType: session.gameType,
        players: players,
        moves: moves,
      );
      _channel = _repo.channel(
        _sessionId,
        onMoveChange: _refresh,
        onSessionChange: _refresh,
      )..subscribe();
    } catch (e, st) {
      debugPrint('board game load failed: $e\n$st');
      if (mounted) {
        state = state.copyWith(loading: false, error: 'Couldn\'t load the game.');
      }
    }
  }

  Future<void> _refresh() async {
    final moves = await _repo.fetchRawMoves(_sessionId);
    if (!mounted) return;
    state = state.copyWith(moves: moves);
  }

  /// My player index (0/1), or -1 if unknown yet.
  int get myIndex => state.players.indexOf(me);

  /// Submit a move (widget already checked it's my turn + legal). Optimistic.
  Future<void> submit(Map<String, dynamic> moveData) async {
    state = state.copyWith(moves: [
      ...state.moves,
      RawMove(userId: me, data: moveData),
    ]);
    try {
      await _repo.submitRawMove(
          sessionId: _sessionId, userId: me, moveData: moveData);
      await _refresh();
    } catch (_) {
      await _refresh(); // reconcile on failure
    }
  }

  /// Called by the board when it detects a terminal state. Idempotent: awards
  /// couple XP once (server + local guard) and pings the creature.
  Future<void> finish(int xp) async {
    if (_finishing || state.newScore != null) return;
    _finishing = true;
    try {
      final newScore = await _repo.complete(_sessionId, xp);
      if (!mounted) return;
      state = state.copyWith(newScore: newScore);
      onCompleted?.call();
    } finally {
      _finishing = false;
    }
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) _repo.removeChannel(ch);
    super.dispose();
  }
}

final boardGameControllerProvider = StateNotifierProvider.autoDispose
    .family<BoardGameController, BoardGameState, String>((ref, sessionId) {
  return BoardGameController(
    ref.watch(gameRepositoryProvider),
    sessionId,
    onCompleted: () => ref.read(creatureReactionProvider.notifier).state++,
  );
});
