import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/skill_game_controller.dart';
import '../data/board_models.dart';
import '../data/game_definitions.dart';
import 'skill/free_throws_game.dart';
import 'skill/target_shot_game.dart';

/// Shared shell for solo-scored skill games: take your shots → wait for your
/// partner → compare. Zero-guilt: shared XP once both have played, winner or
/// tie. Switches on game_type for the actual mini-game.
class SkillGamePlayScreen extends ConsumerWidget {
  const SkillGamePlayScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(skillGameControllerProvider(sessionId));
    final controller = ref.read(skillGameControllerProvider(sessionId).notifier);
    final def = GameCatalog.byType(state.gameType);

    if (state.loading) {
      return BondScaffold(
        title: def.title,
        showBack: true,
        child: const Padding(
          padding: EdgeInsets.only(top: AppSpacing.huge),
          child: BondLoader(),
        ),
      );
    }
    if (state.error != null) {
      return BondScaffold(
        title: def.title,
        showBack: true,
        child: _notice(Icons.cloud_off_rounded, state.error!),
      );
    }

    final me = controller.me;
    final myMove = state.moveFor(me);
    RawMove? partnerMove;
    for (final m in state.moves) {
      if (m.userId != me) partnerMove = m;
    }

    // Not played yet → play the mini-game.
    if (myMove == null) {
      return BondScaffold(
        title: def.title,
        showBack: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: _game(def, controller),
        ),
      );
    }

    final myScore = SkillGameState.scoreOf(myMove);

    // Played, waiting for partner.
    if (partnerMove == null) {
      return BondScaffold(
        title: def.title,
        showBack: true,
        child: _waiting(context, def, myScore),
      );
    }

    // Both played → compare + award XP once.
    final partnerScore = SkillGameState.scoreOf(partnerMove);
    if (state.newScore == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => controller.finish(def.xp));
    }
    return BondScaffold(
      title: def.title,
      showBack: true,
      child: _result(context, def, myScore, partnerScore, state.newScore != null),
    );
  }

  Widget _game(GameDefinition def, SkillGameController controller) {
    void onFinished(int score, List<int> shots) =>
        controller.recordScore(score, shots);
    switch (def.type) {
      case 'target_shot':
        return TargetShotGame(shots: def.shots, onFinished: onFinished);
      case 'free_throws':
        return FreeThrowsGame(shots: def.shots, onFinished: onFinished);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _waiting(BuildContext context, GameDefinition def, int myScore) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        _scoreBadge('Your score', myScore, def),
        const SizedBox(height: AppSpacing.xl),
        _notice(Icons.hourglass_bottom_rounded,
            'Nice shooting! Waiting for your partner to take their shots — you\'ll see who won once they play. 🤍'),
        const SizedBox(height: AppSpacing.lg),
        BondButton(
          label: 'Back to games',
          variant: BondButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _result(BuildContext context, GameDefinition def, int myScore,
      int partnerScore, bool xpAwarded) {
    final String headline;
    if (myScore > partnerScore) {
      headline = 'You won 🎉';
    } else if (myScore < partnerScore) {
      headline = 'Your partner won 💛';
    } else {
      headline = 'It\'s a tie 🤝';
    }
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(child: _scoreBadge('You', myScore, def)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _scoreBadge('Partner', partnerScore, def)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        BondCard(
          color: AppColors.mintWash,
          elevated: false,
          child: Column(
            children: [
              Text(headline,
                  textAlign: TextAlign.center, style: AppText.headline),
              const SizedBox(height: AppSpacing.xs),
              Text(
                xpAwarded
                    ? '+${def.xp} bond XP  ·  you played together 🤍'
                    : 'you played together 🤍',
                textAlign: TextAlign.center,
                style: AppText.bodyMedium.copyWith(color: AppColors.mintDeep),
              ),
              const SizedBox(height: AppSpacing.md),
              BondButton(
                label: 'Back to games',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).scaleXY(begin: 0.96, end: 1),
      ],
    );
  }

  Widget _scoreBadge(String label, int score, GameDefinition def) {
    return BondCard(
      child: Column(
        children: [
          Text(label, style: AppText.bodySmall.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text('$score', style: AppText.displayMedium.copyWith(color: AppColors.mintDeep)),
        ],
      ),
    );
  }

  Widget _notice(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.inkFaint),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: AppText.bodyLarge),
          ],
        ),
      ),
    );
  }
}
