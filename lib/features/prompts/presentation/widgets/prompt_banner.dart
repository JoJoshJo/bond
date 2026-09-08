import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../application/prompt_controller.dart';
import '../../data/prompt_models.dart';
import '../daily_prompt_screen.dart';

/// Slim, tappable "Today's question" banner pinned at the top of chat. Its label
/// reflects the daily-prompt phase and it opens the full experience on tap.
class PromptBanner extends ConsumerWidget {
  const PromptBanner({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(promptControllerProvider(coupleId));

    final (label, cta, highlight) = switch (state.phase) {
      PromptPhase.loading => ('Today\'s question', '', false),
      PromptPhase.answer => ('Today\'s question', 'Tap to answer', true),
      PromptPhase.waiting =>
        ('Answered · waiting for your partner', 'Tap to view', false),
      PromptPhase.revealed => ('Revealed — see your answers', 'Tap to open', true),
    };

    return Material(
      color: highlight ? AppColors.mintWash : AppColors.surfaceAlt,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DailyPromptScreen(coupleId: coupleId),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
          ),
          child: Row(
            children: [
              Icon(
                state.phase == PromptPhase.revealed
                    ? Icons.auto_awesome
                    : Icons.wb_sunny_outlined,
                size: 18,
                color: AppColors.mintDeep,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppText.label.copyWith(color: AppColors.ink)),
                    if (cta.isNotEmpty)
                      Text(cta,
                          style: AppText.bodySmall
                              .copyWith(color: AppColors.mintDeep)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
