import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_shadows.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/widgets/widgets.dart';
import '../../spicy/application/spicy_providers.dart';
import '../application/game_controller.dart';
import '../application/game_turns_provider.dart';
import '../data/game_definitions.dart';
import 'board_game_play_screen.dart';
import 'game_play_screen.dart';
import 'skill_game_play_screen.dart';

/// The Games hub: the launch catalog. Tapping a game starts a fresh session or
/// resumes the couple's unfinished one, then opens play.
class GamesHubScreen extends ConsumerStatefulWidget {
  const GamesHubScreen({super.key});

  @override
  ConsumerState<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends ConsumerState<GamesHubScreen> {
  String? _starting;

  Future<void> _open(GameDefinition def) async {
    setState(() => _starting = def.type);
    try {
      final session =
          await ref.read(gameRepositoryProvider).startOrResume(def.type);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => def.skill
            ? SkillGamePlayScreen(sessionId: session.id)
            : def.board
                ? BoardGamePlayScreen(sessionId: session.id)
                : GamePlayScreen(sessionId: session.id),
      ));
    } catch (error, stack) {
      // Keep the real error in logs; show the user a clean message.
      debugPrint('start_or_resume_game failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      // Back from the game: turns may have changed.
      ref.invalidate(myGameTurnsProvider);
      if (mounted) setState(() => _starting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = GameCatalog.forHub(spicy: ref.watch(spicyActiveProvider));
    final allTurns = ref.watch(myGameTurnsProvider).value ?? const {};
    // Only surface turns for games actually shown in the hub right now.
    final turns = [
      for (final g in games)
        if (allTurns[g.type] != null) allTurns[g.type]!,
    ];
    final turnTypes = {for (final t in turns) t.definition.type};

    return BondScaffold(
      title: 'Games',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text('Play together — on your own time.',
              style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.lg),
          if (turns.isNotEmpty) ...[
            _YourMoveStrip(
              turns: turns,
              onTap: _starting == null ? () => _open(turns.first.definition) : null,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Rows of two (the scaffold already scrolls — no nested GridView).
          for (var i = 0; i < games.length; i += 2) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - AppSpacing.md) / 2;
              Widget tile(GameDefinition d) => _GameTile(
                    def: d,
                    minHeight: w,
                    yourTurn: turnTypes.contains(d.type),
                    starting: _starting == d.type,
                    onTap: _starting == null ? () => _open(d) : null,
                  );
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tile(games[i])),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: i + 1 < games.length
                            ? tile(games[i + 1])
                            : const SizedBox.shrink()),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Stable per-game pastel. Fixed assignments so neighbours differ; unknown
/// types hash into the palette. Themes without tints use mintWash.
Color _tintFor(String type) {
  final tints = AppColors.gameTints;
  if (tints == null || tints.isEmpty) return AppColors.mintWash;
  const fixed = {
    'would_you_rather': 0,
    'this_or_that': 1,
    'couple_quiz': 2,
    'four_in_a_row': 3,
    'tic_tac_toe': 1,
    'dots_and_boxes': 0,
    'target_shot': 3,
    'free_throws': 1,
    'spicy_would_you_rather': 2,
    'spicy_this_or_that': 0,
    'heat_check': 1,
  };
  final idx = fixed[type] ??
      type.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return tints[idx % tints.length];
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.def,
    required this.minHeight,
    required this.yourTurn,
    required this.starting,
    required this.onTap,
  });

  final GameDefinition def;
  final double minHeight;
  final bool yourTurn;
  final bool starting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = _tintFor(def.type);
    final radius = BorderRadius.circular(AppRadius.xl);
    return Semantics(
      button: true,
      label: yourTurn ? '${def.title}, your turn' : def.title,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: radius,
            // Gold ring is decoration only; the "Your turn" text carries it.
            border: Border.all(
                color: yourTurn ? AppColors.accent : Colors.transparent,
                width: 2),
            boxShadow: AppShadows.card,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: starting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.anchor),
                                )
                              : Icon(def.icon,
                                  color: AppColors.anchor, size: 24),
                        ),
                        const Spacer(),
                        if (yourTurn) const _TurnPill(),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.md),
                    Text(def.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(
                            color: AppColors.anchor, height: 1.15)),
                    const SizedBox(height: 2),
                    Text(def.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.bodySmall.copyWith(color: AppColors.ink)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TurnPill extends StatelessWidget {
  const _TurnPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentWash,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('Your turn',
          style: AppText.bodySmall.copyWith(
              color: AppColors.onAccentWash,
              fontSize: 11.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// Gold "Your move" strip — shown only when real async turn state says a
/// partner is waiting on you.
class _YourMoveStrip extends StatelessWidget {
  const _YourMoveStrip({required this.turns, required this.onTap});

  final List<GameTurn> turns;
  final VoidCallback? onTap;

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final first = turns.first;
    final at = first.partnerLastPlayed;
    final fg = AppColors.onAccentWash;
    final more = turns.length - 1;
    return Material(
      color: AppColors.accentWash,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(first.definition.icon, color: fg),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR MOVE',
                        style: AppText.bodySmall.copyWith(
                            color: fg,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                    Text(first.definition.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(color: fg)),
                    Text(
                        [
                          if (at != null) 'Your partner played ${_ago(at)}',
                          if (more > 0) '+$more more waiting',
                        ].join(' · ').ifEmpty('Your partner is waiting'),
                        style: AppText.bodySmall.copyWith(color: fg)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
