import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../calendar/application/calendar_providers.dart';
import '../../../calendar/data/calendar_models.dart';
import '../../../calendar/presentation/calendar_screen.dart';
import '../../../creature/data/creature_persona.dart';
import '../../../creature/presentation/creature_chat_sheet.dart';
import '../../../memories/application/memory_controller.dart';
import '../../../memories/application/memory_resurface.dart';
import '../../../memories/data/memory_models.dart';
import '../../../memories/presentation/memory_viewer_screen.dart';
import '../../../prompts/application/prompt_controller.dart';
import '../../../prompts/data/prompt_models.dart';
import '../../../prompts/presentation/daily_prompt_screen.dart';
import '../../../prompts/presentation/widgets/prompt_banner.dart';

/// The home bento: two squares (talk to the creature · today's question) over
/// one wide contextual slot (next date → resurfaced memory → plan CTA).
class HomeBento extends StatelessWidget {
  const HomeBento({super.key, required this.coupleId});

  final String coupleId;

  static const _gap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Square at the default text size, but free to GROW with large
            // accessibility text instead of clipping (min, not fixed, height).
            final side = (constraints.maxWidth - _gap) / 2;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: side),
                      child: _TalkToCreatureTile(coupleId: coupleId),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: side),
                      child: _TodaysQuestionTile(coupleId: coupleId),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: _gap),
        _ContextualSlot(coupleId: coupleId),
      ],
    );
  }
}

/// Square-tile title: a touch smaller than [AppText.title] so "Talk to Usora"
/// stays on one line and the tile stays square at the default text size.
/// Inner padding for the two squares — tight enough that they stay square at
/// the default text size on a 360pt-wide phone.
const double _tilePad = 14;

TextStyle get _tileTitle =>
    AppText.label.copyWith(color: AppColors.anchor, fontSize: 17);

// ---------------------------------------------------------------------------
// Square: Talk to the creature — the SAME destination as the floating sparkle
// FAB (CreatureChatSheet.open). A second entry point to the AI creature, not
// the partner "Chat" tab.
// ---------------------------------------------------------------------------
class _TalkToCreatureTile extends StatelessWidget {
  const _TalkToCreatureTile({required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    return BondCard(
      color: AppColors.mintWash,
      padding: const EdgeInsets.all(_tilePad),
      onTap: () => CreatureChatSheet.open(context, coupleId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconBadge(icon: Icons.auto_awesome, onWash: true, size: 36),
          const Spacer(),
          const SizedBox(height: AppSpacing.sm),
          Text('Talk to ${CreaturePersona.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _tileTitle),
          const SizedBox(height: 2),
          // ink (not inkMuted): inkMuted is only 4.3:1 on the pale-green tile.
          Text('Ask for a movie, a spot nearby, or just chat.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySmall.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Square: Today's question — reuses the existing daily-prompt controller, its
// phase copy (promptPhaseCopy) and its tap target (DailyPromptScreen).
// ---------------------------------------------------------------------------
class _TodaysQuestionTile extends ConsumerWidget {
  const _TodaysQuestionTile({required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(promptControllerProvider(coupleId));
    final (label, cta, _) = promptPhaseCopy(state.phase);
    final question = state.prompt?.content;
    // Answer phase → the call to action; waiting/revealed → the status line.
    final footer = state.phase == PromptPhase.answer ? cta : label;
    final showFooter =
        state.phase != PromptPhase.loading && footer.trim().isNotEmpty;

    return BondCard(
      padding: const EdgeInsets.all(_tilePad),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DailyPromptScreen(coupleId: coupleId)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.phase == PromptPhase.revealed
                    ? Icons.auto_awesome
                    : Icons.wb_sunny_outlined,
                size: 18,
                color: AppColors.anchor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text('Today\'s question',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(color: AppColors.anchor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (question != null && question.trim().isNotEmpty)
                ? question
                : 'A new question for you two is on its way.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyMedium.copyWith(color: AppColors.ink, fontSize: 14),
          ),
          const Spacer(),
          if (showFooter) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySmall.copyWith(
                  color: AppColors.anchor, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wide contextual slot. ONE slot, three states, by priority:
//   1. an upcoming calendar date within the next 7 days
//   2. else a memory from this calendar day in a previous year (± a few days)
//   3. else a gentle "Plan your next date →" CTA
// It is never empty: while data is still loading it shows the CTA, then
// crossfades to the richer state once one is found.
// ---------------------------------------------------------------------------
class _ContextualSlot extends ConsumerWidget {
  const _ContextualSlot({required this.coupleId});

  final String coupleId;

  static const _dateWindowDays = 7;
  static const _memoryWindowDays = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(calendarControllerProvider(coupleId));
    final vault = ref.watch(memoryVaultProvider(coupleId));
    final now = DateTime.now();

    final Widget child;
    final next = calendar.loading ? null : _nextDate(calendar, now);
    final memory = (next != null || vault.loading)
        ? null
        : resurfaceMemory(vault.groups.expand((g) => g.memories), now,
            windowDays: _memoryWindowDays);

    if (next != null) {
      child = _DateCard(
        key: const ValueKey('date'),
        event: next.event,
        when: next.when,
        onTap: () => _openCalendar(context),
      );
    } else if (memory != null) {
      child = _MemoryCard(
        key: ValueKey('memory-${memory.memory.id}'),
        found: memory,
        signUrl: ref.read(memoryVaultProvider(coupleId).notifier).signedUrl,
      );
    } else {
      child = _PlanCta(
        key: const ValueKey('cta'),
        onTap: () => _openCalendar(context),
      );
    }

    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      child: child,
    );
  }

  void _openCalendar(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CalendarScreen(coupleId: coupleId)),
      );

  /// Soonest occurrence (recurring events expanded) from today through
  /// today + [_dateWindowDays].
  static ({CoupleEvent event, DateTime when})? _nextDate(
      CalendarState calendar, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: _dateWindowDays));
    for (final u in calendar.upcoming(limit: 5)) {
      if (!u.when.isAfter(limit)) return u;
    }
    return null;
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard(
      {super.key, required this.event, required this.when, required this.onTap});

  final CoupleEvent event;
  final DateTime when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      _dayLabel(when),
      if (event.time != null)
        MaterialLocalizations.of(context).formatTimeOfDay(event.time!),
      event.label.trim().isEmpty ? 'Something planned' : event.label.trim(),
    ];
    return _WideCard(
      onTap: onTap,
      leading: _IconBadge(icon: EventType.fromKey(event.type).icon),
      eyebrow: 'Next date',
      title: parts.join(' · '),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({super.key, required this.found, required this.signUrl});

  final ResurfacedMemory found;
  final Future<String> Function(String path) signUrl;

  @override
  Widget build(BuildContext context) {
    return _WideCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            MemoryViewerScreen(memory: found.memory, signUrl: signUrl),
      )),
      leading: _MemoryThumb(memory: found.memory, signUrl: signUrl),
      eyebrow: found.eyebrow,
      title: found.title,
    );
  }
}

class _PlanCta extends StatelessWidget {
  const _PlanCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _WideCard(
      onTap: onTap,
      leading: const _IconBadge(icon: Icons.event_available_rounded),
      eyebrow: 'Nothing planned yet',
      title: 'Plan your next date →',
      showChevron: false,
    );
  }
}

/// Shared wide-rectangle chrome: leading visual · eyebrow + title · chevron.
class _WideCard extends StatelessWidget {
  const _WideCard({
    required this.onTap,
    required this.leading,
    required this.eyebrow,
    required this.title,
    this.showChevron = true,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String eyebrow;
  final String title;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return BondCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(eyebrow,
                    style: AppText.bodySmall.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(
                        color: AppColors.anchor, fontSize: 16)),
              ],
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: AppColors.inkMuted),
          ],
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.onWash = false, this.size = 44});

  final IconData icon;
  final double size;

  /// On the pale-green tile the badge flips to white so it still stands out.
  final bool onWash;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: onWash ? AppColors.surface : AppColors.mintWash,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.anchor, size: size / 2),
    );
  }
}

/// Memory thumbnail (photo, or a video's generated first-frame thumb). The
/// signed-URL future is created once per memory, not on every rebuild.
class _MemoryThumb extends StatefulWidget {
  const _MemoryThumb({required this.memory, required this.signUrl});

  final Memory memory;
  final Future<String> Function(String path) signUrl;

  @override
  State<_MemoryThumb> createState() => _MemoryThumbState();
}

class _MemoryThumbState extends State<_MemoryThumb> {
  late Future<String> _url = _load();

  Future<String> _load() => widget.signUrl(
      widget.memory.isVideo ? widget.memory.thumbPath : widget.memory.mediaPath);

  @override
  void didUpdateWidget(covariant _MemoryThumb old) {
    super.didUpdateWidget(old);
    if (old.memory.id != widget.memory.id) _url = _load();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.mintWash,
      child: Icon(
        widget.memory.isVideo ? Icons.play_circle_fill : Icons.photo_rounded,
        color: AppColors.anchor,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: 56,
        width: 56,
        child: FutureBuilder<String>(
          future: _url,
          builder: (context, snap) {
            if (!snap.hasData) return placeholder;
            return Image.network(
              snap.data!,
              fit: BoxFit.cover,
              // Older videos may have no stored thumb — degrade gracefully.
              errorBuilder: (_, _, _) => placeholder,
            );
          },
        ),
      ),
    );
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _dayLabel(DateTime when) {
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  final day = DateTime.utc(when.year, when.month, when.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return _weekdays[when.weekday - 1];
}
