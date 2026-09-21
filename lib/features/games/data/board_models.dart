import 'package:flutter/foundation.dart';

/// A raw game move with arbitrary move_data, used by the board games.
@immutable
class RawMove {
  const RawMove({required this.userId, required this.data, this.createdAt});

  final String userId;
  final Map<String, dynamic> data;

  /// When the move was made (null for optimistic local moves).
  final DateTime? createdAt;

  factory RawMove.fromRow(Map<String, dynamic> row) {
    final ts = row['created_at'];
    return RawMove(
      userId: row['user_id'] as String,
      data: (row['move_data'] as Map).cast<String, dynamic>(),
      createdAt: ts is String ? DateTime.tryParse(ts) : null,
    );
  }
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
