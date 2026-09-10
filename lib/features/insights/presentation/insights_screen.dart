import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../premium/presentation/premium_gate.dart';
import '../application/insights_providers.dart';
import '../data/insights_models.dart';

/// Relationship Insights — a Usora+ "look at us" reflection: warm stats + a
/// generated narrative in the creature's voice. Free users see the paywall lock.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    return BondScaffold(
      title: 'Insights',
      showBack: true,
      scrollable: true,
      child: PremiumGate(
        featureName: 'Relationship insights',
        blurb: 'See your bond over time — a Usora+ feature.',
        child: _InsightsBody(coupleId: coupleId),
      ),
    );
  }
}

class _InsightsBody extends ConsumerStatefulWidget {
  const _InsightsBody({required this.coupleId});
  final String coupleId;

  @override
  ConsumerState<_InsightsBody> createState() => _InsightsBodyState();
}

class _InsightsBodyState extends ConsumerState<_InsightsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(insightsNarrativeProvider.notifier).ensure());
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(insightsStatsProvider);

    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.huge),
        child: BondLoader(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.huge),
        child: Center(
          child: Text('Couldn\'t load your insights right now.',
              style: AppText.bodyLarge, textAlign: TextAlign.center),
        ),
      ),
      data: (stats) => _content(stats),
    );
  }

  Widget _content(InsightsStats stats) {
    final upcoming =
        ref.watch(calendarControllerProvider(widget.coupleId)).upcoming(limit: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _hero(stats),
        const SizedBox(height: AppSpacing.xl),
        _narrativeCard(stats),
        const SizedBox(height: AppSpacing.xl),
        Text('Your story in numbers',
            style: AppText.bodySmall.copyWith(
                color: AppColors.mintDeep,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: AppSpacing.md),
        _statGrid(stats),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Coming up',
              style: AppText.bodySmall.copyWith(
                  color: AppColors.mintDeep,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.sm),
          for (final u in upcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text('${u.event.label} · ${_relative(u.when)}',
                  style: AppText.bodyMedium),
            ),
        ],
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }

  Widget _hero(InsightsStats stats) {
    final days = stats.daysTogether;
    return Column(
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
              color: AppColors.mintWash, shape: BoxShape.circle),
          child: Icon(Icons.favorite_rounded,
              color: AppColors.mintDeep, size: 36),
        ).animate().scaleXY(
            begin: 0.7, end: 1, duration: 420.ms, curve: Curves.easeOutBack),
        const SizedBox(height: AppSpacing.md),
        if (days != null)
          Text.rich(
            TextSpan(
              style: AppText.headline,
              children: [
                const TextSpan(text: 'You two have been building your bond for\n'),
                TextSpan(
                    text: '$days days',
                    style: TextStyle(color: AppColors.mintDeep)),
                const TextSpan(text: ' 🤍'),
              ],
            ),
            textAlign: TextAlign.center,
          )
        else
          Text('Your bond, so far 🤍',
              textAlign: TextAlign.center, style: AppText.headline),
      ],
    );
  }

  Widget _narrativeCard(InsightsStats stats) {
    final narrative = ref.watch(insightsNarrativeProvider);
    return BondCard(
      color: AppColors.mintWash,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('A note from your creature',
                    style: AppText.bodySmall.copyWith(color: AppColors.mintDeep)),
              ),
              if (!narrative.loading)
                GestureDetector(
                  onTap: () =>
                      ref.read(insightsNarrativeProvider.notifier).refresh(),
                  child: Icon(Icons.refresh_rounded,
                      size: 20, color: AppColors.mintDeep),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (narrative.loading)
            Row(
              children: [
                SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.mint)),
                const SizedBox(width: AppSpacing.sm),
                Text('Reflecting on you two…',
                    style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
              ],
            )
          else if (narrative.text != null)
            Text(narrative.text!, style: AppText.bodyLarge)
                .animate()
                .fadeIn(duration: 400.ms)
          else
            Text(
              'Your reflection\'s a little foggy right now — tap refresh to try again.',
              style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
            ),
        ],
      ),
    );
  }

  Widget _statGrid(InsightsStats stats) {
    final tiles = <Widget>[
      if (stats.daysTogether != null)
        _statTile(Icons.calendar_today_rounded, '${stats.daysTogether}', 'days'),
      _statTile(Icons.local_fire_department_rounded, '${stats.bondScore}', 'bond'),
      _statTile(Icons.auto_awesome_rounded, stats.stageLabel, 'stage'),
      _statTile(Icons.photo_library_rounded, '${stats.memoriesCount}', 'memories'),
      _statTile(Icons.sports_esports_rounded, '${stats.gamesPlayed}', 'games'),
      _statTile(Icons.question_answer_rounded, '${stats.promptsAnswered}', 'prompts'),
      _statTile(Icons.forum_rounded, '${stats.messagesCount}', 'messages'),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: tiles,
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return SizedBox(
      width: 104,
      child: BondCard(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, color: AppColors.mint, size: 22),
            const SizedBox(height: AppSpacing.xs),
            Text(value,
                style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label,
                style: AppText.bodySmall.copyWith(color: AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime when) {
    final now = DateTime.now();
    final days = DateTime(when.year, when.month, when.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days < 0) return 'past';
    return 'in $days days';
  }
}
