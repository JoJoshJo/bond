import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_providers.dart';
import '../data/board_models.dart';
import '../data/engines/connect_four_engine.dart';
import '../data/engines/dots_and_boxes_engine.dart';
import '../data/engines/tic_tac_toe_engine.dart';
import '../data/game_definitions.dart';
import 'game_controller.dart' show gameRepositoryProvider;

/// A game where it's the signed-in user's move, from REAL persisted state.
@immutable
class GameTurn {
  const GameTurn({required this.definition, this.partnerLastPlayed});

  final GameDefinition definition;

  /// When the partner last moved in this match (null if unknown).
  final DateTime? partnerLastPlayed;
}

/// Games where it's MY move, keyed by game type — derived from the couple's
/// unfinished sessions and their stored moves (no stored "whose turn" column
/// exists; every game's turn is derivable from its moves):
///
/// * Board games (strict turns): the same engine `replay()` the play screen
///   uses → my turn when `currentPlayer == myIndex` and the game isn't over.
///   A brand-new board with no moves yet is NOT flagged (nobody's waiting).
/// * Round games (both answer independently): my turn when my partner has
///   answered a round I haven't.
/// * Skill games (one score each): my turn when my partner has played and I
///   haven't.
///
/// Read-only and fail-quiet: any error → no turns (the hub still works).
final myGameTurnsProvider =
    FutureProvider.autoDispose<Map<String, GameTurn>>((ref) async {
  try {
    final membership = await ref.watch(myMembershipProvider.future);
    if (membership == null || !membership.isLinked) return const {};
    final repo = ref.watch(gameRepositoryProvider);
    final me = repo.currentUserId;
    if (me == null) return const {};

    final sessions = await repo.unfinishedSessions(membership.coupleId);
    if (sessions.isEmpty) return const {};
    final players = await repo.memberIds(membership.coupleId);
    if (players.length < 2) return const {};

    final loaded = await Future.wait(sessions.map(
        (s) async => (session: s, moves: await repo.fetchRawMoves(s.id))));

    final turns = <String, GameTurn>{};
    for (final (:session, :moves) in loaded) {
      if (turns.containsKey(session.gameType)) continue; // one per game type
      final def = GameCatalog.all
          .where((g) => g.type == session.gameType)
          .firstOrNull;
      if (def == null) continue;
      if (!_isMyTurn(def, moves, players, me)) continue;

      DateTime? last;
      for (final m in moves) {
        final at = m.createdAt;
        if (m.userId != me && at != null && (last == null || at.isAfter(last))) {
          last = at;
        }
      }
      turns[def.type] = GameTurn(definition: def, partnerLastPlayed: last);
    }
    return turns;
  } catch (e, st) {
    debugPrint('game turns load failed: $e\n$st');
    return const {};
  }
});

bool _isMyTurn(
    GameDefinition def, List<RawMove> moves, List<String> players, String me) {
  if (def.board) {
    if (moves.isEmpty) return false;
    final myIndex = players.indexOf(me);
    if (myIndex < 0) return false;
    final result = switch (def.type) {
      'four_in_a_row' => ConnectFour.replay(moves, players).result,
      'tic_tac_toe' => TicTacToe.replay(moves, players).result,
      'dots_and_boxes' => DotsAndBoxes.replay(moves, players).result,
      _ => null,
    };
    return result != null && !result.isOver && result.currentPlayer == myIndex;
  }
  if (def.skill) {
    final iPlayed = moves.any((m) => m.userId == me);
    final partnerPlayed = moves.any((m) => m.userId != me);
    return partnerPlayed && !iPlayed;
  }
  // Round games: move_data {round, choice}.
  final mine = <int>{};
  final theirs = <int>{};
  for (final m in moves) {
    final round = (m.data['round'] as num?)?.toInt();
    if (round == null) continue;
    (m.userId == me ? mine : theirs).add(round);
  }
  return theirs.any((r) => !mine.contains(r));
}
