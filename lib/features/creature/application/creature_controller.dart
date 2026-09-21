import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_providers.dart';
import '../data/creature_models.dart';
import '../data/creature_repository.dart';

final creatureRepositoryProvider = Provider<CreatureRepository>(
  (ref) => CreatureRepository(ref.watch(supabaseClientProvider)),
);

/// Bumped when a game completes (and any future creature-worthy moment). The
/// creature state watches it, so Home refreshes + can celebrate. This is the
/// concrete wiring of the old `// TODO(creature)` hook.
final creatureReactionProvider = StateProvider<int>((ref) => 0);

/// The couple's creature state — derived, zero-guilt, ungameable. Never throws
/// to the UI: on any error (e.g. RPC not yet deployed) it falls back to a calm
/// neutral creature rather than an error.
final creatureStateProvider =
    FutureProvider.autoDispose.family<CreatureState, String>((ref, coupleId) async {
  // Recompute when a reaction fires (e.g. bond_score changed after a game).
  ref.watch(creatureReactionProvider);

  ConnectionSnapshot snap;
  try {
    snap = await ref.watch(creatureRepositoryProvider).fetchSnapshot();
  } catch (_) {
    snap = ConnectionSnapshot.neutral;
  }
  return _derive(snap, DateTime.now());
});

/// Pure function: snapshot + now → creature state. Zero-guilt guardrails:
/// warm floor, rests-never-suffers, flame never burns down, no day-counting.
CreatureState _derive(ConnectionSnapshot s, DateTime now) {
  final last = s.lastConnectedAt;
  final hoursSince =
      last == null ? double.infinity : now.difference(last).inHours.toDouble();
  final connectedToday = hoursSince <= 24;
  final quiet = hoursSince > 72; // > ~3 days

  final CreatureMood mood;
  if (connectedToday && s.activeDays7 >= 3) {
    mood = CreatureMood.thriving;
  } else if (quiet) {
    mood = CreatureMood.resting;
  } else {
    mood = CreatureMood.content;
  }

  final CreatureStage stage;
  if (s.bondScore < kGrowingAtScore) {
    stage = CreatureStage.hatchling;
  } else if (s.bondScore < kFlourishingAtScore) {
    stage = CreatureStage.growing;
  } else {
    stage = CreatureStage.flourishing;
  }

  // Warm "missed you" ONLY on return after a gap — never while away, never
  // counting days at the user. Computed only now (on open).
  final returnedAfterGap = last != null && hoursSince >= 72;

  final String greeting;
  if (returnedAfterGap) {
    greeting = 'I missed you two 🤍';
  } else if (mood == CreatureMood.thriving) {
    greeting = 'You two are glowing today ✨';
  } else if (mood == CreatureMood.resting) {
    greeting = 'Resting cozy — glad you\'re here 🤍';
  } else {
    greeting = 'Hi again 🤍';
  }

  return CreatureState(
    mood: mood,
    stage: stage,
    flameNumber: s.bondScore, // monotonic — never burns down
    flameLit: last != null && hoursSince <= 48, // brightness only
    greeting: greeting,
  );
}
