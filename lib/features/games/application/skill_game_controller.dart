import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/utils/haptics.dart';
import '../../creature/application/creature_controller.dart';
import '../data/board_models.dart';
import '../data/game_repository.dart';
import 'game_controller.dart' show gameRepositoryProvider;

/// State for a solo-scored skill game (Target Shot, Free Throws). Each player
/// takes their shots independently and records ONE move: `{score, shots}`. When
/// both moves exist we compare scores → higher wins (equal = tie). XP is shared
/// and awarded once (zero-guilt: you played together).
class SkillGameState {
  const SkillGameState({
    this.loading = true,
    this.gameType = '',
    this.players = const [],
    this.moves = const [],
    this.submitting = false,
    this.newScore,
    this.error,
  });

  final bool loading;
  final String gameType;
  final List<String> players; // couple member uids (may be <2 pre-link)
  final List<RawMove> moves; // ≤2: one score-move per player
  final bool submitting; // recording my score
  final int? newScore; // set once completed + XP awarded
  final String? error;

  SkillGameState copyWith({
    bool? loading,
    String? gameType,
    List<String>? players,
    List<RawMove>? moves,
    bool? submitting,
    Object? newScore = _s,
    Object? error = _s,
  }) =>
      SkillGameState(
        loading: loading ?? this.loading,
        gameType: gameType ?? this.gameType,
        players: players ?? this.players,
        moves: moves ?? this.moves,
        submitting: submitting ?? this.submitting,
        newScore: newScore == _s ? this.newScore : newScore as int?,
        error: error == _s ? this.error : error as String?,
      );

  static const _s = Object();

  RawMove? moveFor(String uid) {
    for (final m in moves) {
      if (m.userId == uid) return m;
    }
    return null;
  }

  static int scoreOf(RawMove m) => (m.data['score'] as num?)?.toInt() ?? 0;
}

/// Drives a skill game over the existing game backend: load session/players,
/// record my score as a single move, and — once both have played — complete
/// the session (idempotent) and ping the creature.
class SkillGameController extends StateNotifier<SkillGameState> {
  SkillGameController(this._repo, this._sessionId, {this.onCompleted})
      : super(const SkillGameState()) {
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
      debugPrint('skill game load failed: $e\n$st');
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

  /// True once I've recorded my shots this session.
  bool get iHavePlayed => state.moveFor(me) != null;

  /// Record my run for this session as a single move. No-op if I already played.
  Future<void> recordScore(int score, List<int> shots) async {
    if (iHavePlayed || state.submitting) return;
    final moveData = <String, dynamic>{'score': score, 'shots': shots};
    // Optimistic: show my score immediately.
    state = state.copyWith(
      submitting: true,
      moves: [...state.moves, RawMove(userId: me, data: moveData)],
    );
    try {
      await _repo.submitRawMove(
          sessionId: _sessionId, userId: me, moveData: moveData);
      await _refresh();
    } catch (e) {
      debugPrint('skill game move rejected: $e');
      await _refresh(); // reconcile on failure
    } finally {
      if (mounted) state = state.copyWith(submitting: false);
    }
  }

  /// Award shared couple XP once, when both players have a recorded score.
  /// Idempotent (server RPC + local guard). Pings the creature.
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

final skillGameControllerProvider = StateNotifierProvider.autoDispose
    .family<SkillGameController, SkillGameState, String>((ref, sessionId) {
  return SkillGameController(
    ref.watch(gameRepositoryProvider),
    sessionId,
    onCompleted: () {
      Haptics.success();
      ref.read(creatureReactionProvider.notifier).state++;
    },
  );
});
