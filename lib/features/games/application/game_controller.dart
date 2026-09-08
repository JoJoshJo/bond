import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../../creature/application/creature_controller.dart';
import '../data/game_definitions.dart';
import '../data/game_models.dart';
import '../data/game_repository.dart';

final gameRepositoryProvider = Provider<GameRepository>(
  (ref) => GameRepository(ref.watch(supabaseClientProvider)),
);

class GameState {
  const GameState({
    this.loading = true,
    this.session,
    this.definition,
    this.myByRound = const {},
    this.partnerByRound = const {},
    this.newScore,
  });

  final bool loading;
  final GameSession? session;
  final GameDefinition? definition;
  final Map<int, int> myByRound; // round -> choice
  final Map<int, int> partnerByRound;
  final int? newScore; // set once completed + XP awarded

  int get roundCount => definition?.roundCount ?? 0;
  bool get iFinished => myByRound.length >= roundCount && roundCount > 0;
  bool get partnerFinished =>
      partnerByRound.length >= roundCount && roundCount > 0;
  bool get bothFinished => iFinished && partnerFinished;

  /// First round I haven't answered yet (or roundCount if done).
  int get myCurrentRound {
    for (var i = 0; i < roundCount; i++) {
      if (!myByRound.containsKey(i)) return i;
    }
    return roundCount;
  }

  /// A round is revealed only if I've also answered it (app-level gating).
  bool isRevealed(int round) =>
      myByRound.containsKey(round) && partnerByRound.containsKey(round);

  int get matches {
    var m = 0;
    for (var i = 0; i < roundCount; i++) {
      if (myByRound[i] != null && myByRound[i] == partnerByRound[i]) m++;
    }
    return m;
  }

  GameState copyWith({
    bool? loading,
    GameSession? session,
    GameDefinition? definition,
    Map<int, int>? myByRound,
    Map<int, int>? partnerByRound,
    Object? newScore = _s,
  }) {
    return GameState(
      loading: loading ?? this.loading,
      session: session ?? this.session,
      definition: definition ?? this.definition,
      myByRound: myByRound ?? this.myByRound,
      partnerByRound: partnerByRound ?? this.partnerByRound,
      newScore: newScore == _s ? this.newScore : newScore as int?,
    );
  }

  static const _s = Object();
}

class GameController extends StateNotifier<GameState> {
  GameController(this._repo, this._sessionId, {this.onCompleted})
      : super(const GameState()) {
    _init();
  }

  final GameRepository _repo;
  final String _sessionId;
  final VoidCallback? onCompleted;
  RealtimeChannel? _channel;
  bool _completing = false;

  String get _me => _repo.currentUserId ?? '';

  Future<void> _init() async {
    final session = await _repo.fetchSession(_sessionId);
    if (!mounted || session == null) return;
    final def = GameCatalog.byType(session.gameType);
    state = state.copyWith(session: session, definition: def, loading: false);
    await _refreshMoves();
    _channel = _repo.channel(
      _sessionId,
      onMoveChange: _refreshMoves,
      onSessionChange: _refreshMoves,
    )..subscribe();
  }

  Future<void> _refreshMoves() async {
    final moves = await _repo.fetchMoves(_sessionId);
    if (!mounted) return;
    final mine = <int, int>{};
    final partner = <int, int>{};
    for (final mv in moves) {
      (mv.userId == _me ? mine : partner)[mv.round] = mv.choice;
    }
    state = state.copyWith(myByRound: mine, partnerByRound: partner);
    _maybeComplete();
  }

  Future<void> submitMove(int round, int choice) async {
    if (state.myByRound.containsKey(round)) return;
    // Optimistic: reflect my choice immediately.
    state = state.copyWith(myByRound: {...state.myByRound, round: choice});
    try {
      await _repo.submitMove(
          sessionId: _sessionId, userId: _me, round: round, choice: choice);
      await _refreshMoves();
    } catch (_) {
      await _refreshMoves(); // reconcile on failure
    }
  }

  Future<void> _maybeComplete() async {
    if (_completing) return;
    if (!state.bothFinished) return;
    if (state.session?.isCompleted == true && state.newScore != null) return;
    _completing = true;
    try {
      final def = state.definition;
      if (def == null) return;
      final newScore = await _repo.complete(_sessionId, def.xp);
      if (!mounted) return;
      state = state.copyWith(newScore: newScore);
      // Creature reaction hook: bond_score changed → nudge the creature state so
      // Home reflects the new connection (and can celebrate).
      onCompleted?.call();
    } finally {
      _completing = false;
    }
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) _repo.removeChannel(ch);
    super.dispose();
  }
}

final gameControllerProvider = StateNotifierProvider.autoDispose
    .family<GameController, GameState, String>((ref, sessionId) {
  return GameController(
    ref.watch(gameRepositoryProvider),
    sessionId,
    onCompleted: () =>
        ref.read(creatureReactionProvider.notifier).state++,
  );
});
