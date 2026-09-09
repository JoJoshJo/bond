import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../ai/application/ai_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../couple/application/couple_providers.dart';
import '../data/insights_models.dart';
import '../data/insights_repository.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => InsightsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(aiRepositoryProvider),
  ),
);

/// The couple's stats (RPC resolves the couple from the JWT). Auto-disposed —
/// cheap to refetch when the screen reopens.
final insightsStatsProvider = FutureProvider.autoDispose<InsightsStats>(
  (ref) => ref.watch(insightsRepositoryProvider).fetchStats(),
);

class NarrativeState {
  const NarrativeState({this.loading = false, this.text, this.failed = false});

  final bool loading;
  final String? text;
  final bool failed;

  NarrativeState copyWith({bool? loading, String? text, bool? failed}) =>
      NarrativeState(
        loading: loading ?? this.loading,
        text: text ?? this.text,
        failed: failed ?? this.failed,
      );
}

/// Owns the generated reflection. NOT auto-disposed, so the narrative is cached
/// for the session (navigating away and back doesn't re-spend a generation);
/// [refresh] forces a new one.
class InsightsNarrativeController extends StateNotifier<NarrativeState> {
  InsightsNarrativeController(this._ref) : super(const NarrativeState());

  final Ref _ref;

  /// Generate once if we don't already have a reflection cached.
  Future<void> ensure() async {
    if (state.text != null || state.loading) return;
    await _generate();
  }

  /// Force a fresh reflection.
  Future<void> refresh() => _generate();

  Future<void> _generate() async {
    state = state.copyWith(loading: true, failed: false);
    try {
      final stats = await _ref.read(insightsStatsProvider.future);
      final coupleName =
          _ref.read(myMembershipProvider).asData?.value?.coupleName ?? 'you two';
      final text = await _ref
          .read(insightsRepositoryProvider)
          .generateNarrative(stats, coupleName);
      if (!mounted) return;
      state = NarrativeState(
        loading: false,
        text: text.isEmpty ? null : text,
        failed: text.isEmpty,
      );
    } catch (e, st) {
      debugPrint('insights narrative failed: $e\n$st');
      if (mounted) state = state.copyWith(loading: false, failed: true);
    }
  }
}

final insightsNarrativeProvider =
    StateNotifierProvider<InsightsNarrativeController, NarrativeState>(
  (ref) => InsightsNarrativeController(ref),
);
