import 'package:flutter/foundation.dart';

/// The couple's relationship stats, from the extended `get_connection_snapshot`
/// RPC. Read-only; premium-gated at the screen.
@immutable
class InsightsStats {
  const InsightsStats({
    required this.bondScore,
    required this.activeDays7,
    this.relationshipStartDate,
    this.daysTogether,
    required this.memoriesCount,
    required this.promptsAnswered,
    required this.gamesPlayed,
    required this.messagesCount,
  });

  final int bondScore;
  final int activeDays7;
  final DateTime? relationshipStartDate;
  final int? daysTogether;
  final int memoriesCount;
  final int promptsAnswered;
  final int gamesPlayed;
  final int messagesCount;

  /// Life stage from bond_score (same thresholds as the creature: monotonic).
  String get stageLabel {
    if (bondScore < 50) return 'Hatchling';
    if (bondScore < 200) return 'Growing';
    return 'Flourishing';
  }

  factory InsightsStats.fromRow(Map<String, dynamic> row) {
    final startRaw = row['relationship_start_date'];
    return InsightsStats(
      bondScore: (row['bond_score'] as num?)?.toInt() ?? 0,
      activeDays7: (row['active_days_7'] as num?)?.toInt() ?? 0,
      relationshipStartDate:
          startRaw == null ? null : DateTime.tryParse(startRaw as String),
      daysTogether: (row['days_together'] as num?)?.toInt(),
      memoriesCount: (row['memories_count'] as num?)?.toInt() ?? 0,
      promptsAnswered: (row['prompts_answered'] as num?)?.toInt() ?? 0,
      gamesPlayed: (row['games_played'] as num?)?.toInt() ?? 0,
      messagesCount: (row['messages_count'] as num?)?.toInt() ?? 0,
    );
  }
}
