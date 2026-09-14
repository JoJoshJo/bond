import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../couple/presentation/widgets/creature_placeholder.dart';
import '../application/prompt_controller.dart';
import '../data/prompt_models.dart';

const _answerReactions = ['❤️', '🥹', '😂', '😮', '🙏', '🔥'];

/// The daily prompt experience: answer privately → wait → simultaneous reveal.
class DailyPromptScreen extends ConsumerStatefulWidget {
  const DailyPromptScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  ConsumerState<DailyPromptScreen> createState() => _DailyPromptScreenState();
}

class _DailyPromptScreenState extends ConsumerState<DailyPromptScreen> {
  final _answer = TextEditingController();
  final _edit = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _answer.dispose();
    _edit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(promptControllerProvider(widget.coupleId));
    final controller =
        ref.read(promptControllerProvider(widget.coupleId).notifier);

    return BondScaffold(
      title: 'Today\'s question',
      showBack: true,
      scrollable: true,
      child: state.error != null
          ? _errorView(state.error!)
          : switch (state.phase) {
        PromptPhase.loading => const BondSkeletonCards(count: 2, height: 120),
        PromptPhase.answer => _answerView(state, controller),
        PromptPhase.waiting => _waitingView(state, controller),
        PromptPhase.revealed => _revealView(state, controller),
      },
    );
  }

  Widget _errorView(String error) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: BondCard(
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.inkFaint),
            const SizedBox(height: AppSpacing.md),
            Text(error,
                textAlign: TextAlign.center, style: AppText.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Pull down to try again.',
                textAlign: TextAlign.center, style: AppText.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _promptCard(PromptState state) {
    return BondCard(
      color: AppColors.mintWash,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BondChip(label: state.prompt?.category ?? '', tone: BondChipTone.mint),
          const SizedBox(height: AppSpacing.md),
          Text(state.prompt?.content ?? '', style: AppText.headline),
        ],
      ),
    );
  }

  Widget _answerView(PromptState state, PromptController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _promptCard(state),
        const SizedBox(height: AppSpacing.xl),
        Text('Answer privately — you\'ll both reveal together.',
            style: AppText.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _answer,
          minLines: 4,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Your honest answer…',
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        BondButton(
          label: 'Submit answer',
          loading: state.submitting,
          onPressed: () => controller.submit(_answer.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        BondButton(
          label: state.requesting ? 'Finding another…' : 'Request a new one',
          variant: BondButtonVariant.ghost,
          loading: state.requesting,
          onPressed: controller.requestNew,
        ),
      ],
    );
  }

  Widget _waitingView(PromptState state, PromptController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _promptCard(state),
        const SizedBox(height: AppSpacing.xxl),
        Center(child: const CreaturePlaceholder(size: 120))
            .animate()
            .fadeIn(duration: 500.ms),
        const SizedBox(height: AppSpacing.xl),
        Text('Answer submitted 💛',
            textAlign: TextAlign.center, style: AppText.title),
        const SizedBox(height: AppSpacing.sm),
        Text('Waiting for your partner to answer. You\'ll both see each '
            'other\'s answers the moment they do.',
            textAlign: TextAlign.center,
            style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpacing.xl),
        BondCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('YOUR ANSWER',
                        style: AppText.bodySmall.copyWith(
                            color: AppColors.mintDeep,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  if (!_editing)
                    TextButton(
                      onPressed: () {
                        _edit.text = state.myResponse?.response ?? '';
                        setState(() => _editing = true);
                      },
                      child: const Text('Edit answer'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_editing) ...[
                TextField(
                  controller: _edit,
                  minLines: 3,
                  maxLines: 8,
                  autofocus: true,
                  style: AppText.bodyMedium,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: BondButton(
                        label: 'Save',
                        loading: state.submitting,
                        onPressed: () async {
                          await controller.editAnswer(_edit.text);
                          if (mounted) setState(() => _editing = false);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: BondButton(
                        label: 'Cancel',
                        variant: BondButtonVariant.ghost,
                        onPressed: () => setState(() => _editing = false),
                      ),
                    ),
                  ],
                ),
              ] else
                Text(state.myResponse?.response ?? '', style: AppText.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }

  Widget _revealView(PromptState state, PromptController controller) {
    final me = ref.read(promptRepositoryProvider).currentUserId ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _promptCard(state),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: AppColors.mint, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text('You both answered', style: AppText.title),
          ],
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: AppSpacing.xl),
        _answerCard(
          label: 'THEIR ANSWER',
          text: state.partnerResponse?.response ?? '',
          delayMs: 100,
        ),
        _reactionRow(state, controller, me),
        const SizedBox(height: AppSpacing.lg),
        _answerCard(
          label: 'YOUR ANSWER',
          text: state.myResponse?.response ?? '',
          delayMs: 260,
        ),
        const SizedBox(height: AppSpacing.xxl),
        BondButton(
          label: 'Talk about it',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _answerCard(
      {required String label, required String text, required int delayMs}) {
    return BondCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.bodySmall.copyWith(
                  color: AppColors.mintDeep,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.sm),
          Text(text, style: AppText.bodyLarge),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: delayMs.ms, duration: 450.ms)
        .scaleXY(begin: 0.96, end: 1, delay: delayMs.ms, duration: 450.ms);
  }

  Widget _reactionRow(
      PromptState state, PromptController controller, String me) {
    final partner = state.partnerResponse;
    if (partner == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: _answerReactions.map((e) {
          final active = partner.reactions
              .any((r) => r.userId == me && r.emoji == e);
          return GestureDetector(
            onTap: () => controller.toggleReaction(partner.id, e),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: active ? AppColors.mintWash : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: active ? AppColors.mint : AppColors.border),
              ),
              child: Text(e, style: const TextStyle(fontSize: 18)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
