import 'package:flutter/foundation.dart';

/// The creature's emotional state — warm floor, never sad/sick. Difference is
/// "peacefully resting vs joyfully thriving", never "happy vs sad".
enum CreatureMood { resting, content, thriving }

/// Life stage, tied to bond_score thresholds (monotonic → never regresses).
enum CreatureStage { hatchling, growing, flourishing }

/// bond_score at which the creature reaches each stage (single source of truth
/// for both the stage derivation and the home bond meter).
const int kGrowingAtScore = 50;
const int kFlourishingAtScore = 200;

/// Raw connection snapshot from get_connection_snapshot() (all derived data).
@immutable
class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.bondScore,
    required this.lastConnectedAt,
    required this.activeDays7,
  });

  final int bondScore;
  final DateTime? lastConnectedAt;
  final int activeDays7;

  factory ConnectionSnapshot.fromRow(Map<String, dynamic> row) {
    final ts = row['last_connected_at'];
    return ConnectionSnapshot(
      bondScore: (row['bond_score'] as num?)?.toInt() ?? 0,
      lastConnectedAt: ts == null ? null : DateTime.parse(ts as String),
      activeDays7: (row['active_days_7'] as num?)?.toInt() ?? 0,
    );
  }

  /// Neutral fallback (e.g. before the RPC exists or on a transient error) —
  /// a calm content creature, never an error state on the home screen.
  static const neutral =
      ConnectionSnapshot(bondScore: 0, lastConnectedAt: null, activeDays7: 0);
}

/// The computed, display-ready creature state. All plain code — no AI.
@immutable
class CreatureState {
  const CreatureState({
    required this.mood,
    required this.stage,
    required this.flameNumber,
    required this.flameLit,
    required this.greeting,
  });

  final CreatureMood mood;
  final CreatureStage stage;
  final int flameNumber; // = bond_score, monotonic, never burns down
  final bool flameLit; // brightness from recency (never changes the number)
  final String greeting;

  /// Progress (0–1) through the current stage toward the next one, from the
  /// bond score. Flourishing is the final stage, so it reads as full.
  double get stageProgress => switch (stage) {
        CreatureStage.hatchling =>
          (flameNumber / kGrowingAtScore).clamp(0.0, 1.0),
        CreatureStage.growing => ((flameNumber - kGrowingAtScore) /
                (kFlourishingAtScore - kGrowingAtScore))
            .clamp(0.0, 1.0),
        CreatureStage.flourishing => 1.0,
      };

  /// The next stage's label, or null at the final stage.
  String? get nextStageLabel => switch (stage) {
        CreatureStage.hatchling => 'Growing',
        CreatureStage.growing => 'Flourishing',
        CreatureStage.flourishing => null,
      };

  String get stageLabel => switch (stage) {
        CreatureStage.hatchling => 'Hatchling',
        CreatureStage.growing => 'Growing',
        CreatureStage.flourishing => 'Flourishing',
      };
}
