import 'package:flutter/foundation.dart';

/// A game session row.
@immutable
class GameSession {
  const GameSession({
    required this.id,
    required this.gameType,
    required this.mode,
    required this.status,
  });

  final String id;
  final String gameType;
  final String mode; // live | async
  final String status; // waiting | active | paused | completed

  bool get isCompleted => status == 'completed';

  factory GameSession.fromRow(Map<String, dynamic> row) => GameSession(
        id: row['id'] as String,
        gameType: row['game_type'] as String,
        mode: (row['mode'] as String?) ?? 'async',
        status: (row['status'] as String?) ?? 'active',
      );
}

/// A single move: one player's choice for one round.
@immutable
class GameMove {
  const GameMove({
    required this.userId,
    required this.round,
    required this.choice,
  });

  final String userId;
  final int round;
  final int choice;

  factory GameMove.fromRow(Map<String, dynamic> row) {
    final data = row['move_data'] as Map<String, dynamic>;
    return GameMove(
      userId: row['user_id'] as String,
      round: (data['round'] as num).toInt(),
      choice: (data['choice'] as num).toInt(),
    );
  }
}
