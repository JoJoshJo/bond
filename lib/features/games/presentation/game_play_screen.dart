import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/game_controller.dart';
import '../data/game_definitions.dart';

/// Plays a game session: answer your current round, reveal each round once both
/// have answered it, and a result summary + XP when both finish. Async-first.
class GamePlayScreen extends ConsumerWidget {
  const GamePlayScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider(sessionId));
    final controller = ref.read(gameControllerProvider(sessionId).notifier);
    final def = state.definition;

    return BondScaffold(
      title: def?.title ?? 'Game',
      showBack: true,
      scrollable: true,
      child: state.loading || def == null
          ? const Padding(
              padding: EdgeInsets.only(top: AppSpacing.huge),
              child: BondLoader(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                if (state.bothFinished) _result(context, state, def),
                if (!state.bothFinished) ...[
                  _progress(state, def),
                  const SizedBox(height: AppSpacing.lg),
                  if (!state.iFinished)
                    _currentRound(state, def, controller)
                  else
                    _waitingForPartner(),
                ],
                const SizedBox(height: AppSpacing.xl),
                _revealList(state, def),
                const SizedBox(height: AppSpacing.huge),
              ],
            ),
    );
  }

  Widget _progress(GameState state, GameDefinition def) {
    return Row(
      children: [
        BondChip(
          label: 'Round ${state.myCurrentRound.clamp(0, def.roundCount) + (state.iFinished ? 0 : 1)} of ${def.roundCount}',
          tone: BondChipTone.mint,
        ),
      ],
    );
  }

  Widget _currentRound(
      GameState state, GameDefinition def, GameController controller) {
    final i = state.myCurrentRound;
    if (i >= def.roundCount) return const SizedBox.shrink();
    final round = def.rounds[i];
    return BondCard(
      color: AppColors.mintWash,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(round.question, style: AppText.headline),
          const SizedBox(height: AppSpacing.lg),
          for (var k = 0; k < round.options.length; k++) ...[
            _optionButton(round.options[k], () => controller.submitMove(i, k)),
            if (k < round.options.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    ).animate(key: ValueKey(i)).fadeIn(duration: 250.ms);
  }

  Widget _optionButton(String label, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _waitingForPartner() {
    return BondCard(
      child: Row(
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('You\'re done — waiting for your partner to finish.',
                style: AppText.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _revealList(GameState state, GameDefinition def) {
    // Rounds I've answered, newest first.
    final answered = state.myByRound.keys.toList()..sort();
    if (answered.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('YOUR ROUNDS',
            style: AppText.bodySmall.copyWith(
                color: AppColors.mintDeep,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: AppSpacing.sm),
        for (final r in answered) ...[
          _revealRow(state, def, r),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _revealRow(GameState state, GameDefinition def, int round) {
    final myChoice = state.myByRound[round]!;
    final revealed = state.isRevealed(round);
    final partnerChoice = state.partnerByRound[round];
    final opts = def.rounds[round].options;
    final matched = revealed && myChoice == partnerChoice;

    return BondCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(def.rounds[round].question, style: AppText.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _pill('You', opts[myChoice], true)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: revealed
                    ? _pill('Them', opts[partnerChoice!], false, matched)
                    : _pill('Them', 'Waiting…', false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String who, String value, bool mine, [bool matched = false]) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: matched
            ? AppColors.mintWash
            : (mine ? AppColors.surfaceAlt : AppColors.surface),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: matched ? AppColors.mint : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(who, style: AppText.bodySmall.copyWith(color: AppColors.inkMuted)),
          Text(value, style: AppText.bodyMedium),
        ],
      ),
    );
  }

  Widget _result(BuildContext context, GameState state, GameDefinition def) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BondCard(
          color: AppColors.mintWash,
          elevated: false,
          child: Column(
            children: [
              const Icon(Icons.celebration_rounded,
                  size: 40, color: AppColors.mint),
              const SizedBox(height: AppSpacing.md),
              Text('You matched ${state.matches} of ${def.roundCount}',
                  textAlign: TextAlign.center, style: AppText.headline),
              const SizedBox(height: AppSpacing.xs),
              if (state.newScore != null)
                Text('+${def.xp} bond XP  ·  score ${state.newScore}',
                    textAlign: TextAlign.center,
                    style:
                        AppText.bodyMedium.copyWith(color: AppColors.mintDeep)),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scaleXY(begin: 0.95, end: 1, duration: 400.ms),
        const SizedBox(height: AppSpacing.lg),
        BondButton(
          label: 'Back to games',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
