import 'package:flutter/foundation.dart';

/// A raw game move with arbitrary move_data, used by the board games.
@immutable
class RawMove {
  const RawMove({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  factory RawMove.fromRow(Map<String, dynamic> row) => RawMove(
        userId: row['user_id'] as String,
        data: (row['move_data'] as Map).cast<String, dynamic>(),
      );
}

/// The computed state of a board after replaying moves.
/// [winner]: -1 ongoing · 0/1 that player · 2 draw.
@immutable
class BoardResult {
  const BoardResult({required this.currentPlayer, required this.winner});
  final int currentPlayer; // whose turn (0 or 1); ignored once over
  final int winner; // -1 ongoing, 0/1 winner, 2 draw
  bool get isOver => winner != -1;
}
