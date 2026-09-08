import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../creature/application/creature_controller.dart';
import '../../creature/data/creature_models.dart';
import '../../creature/presentation/assistant_stub.dart';
import '../../creature/presentation/creature_chat_sheet.dart';
import '../../creature/presentation/creature_view.dart';
import '../../prompts/presentation/widgets/prompt_banner.dart';

/// The emotional home: the creature front-and-center, the couple name, the BOND
/// flame + score, and today's question. First thing you see on open.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.coupleId, required this.coupleName});

  final String coupleId;
  final String coupleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatureAsync = ref.watch(creatureStateProvider(coupleId));
    final creature = creatureAsync.asData?.value;
    final showAssistant = ref.watch(assistantFloatingEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton:
          showAssistant ? AssistantButton(coupleId: coupleId) : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(creatureStateProvider(coupleId)),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPad),
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(coupleName,
                  textAlign: TextAlign.center, style: AppText.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                creature?.greeting ?? ' ',
                textAlign: TextAlign.center,
                style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: GestureDetector(
                  onTap: () => CreatureChatSheet.open(context, coupleId),
                  child: CreatureView(
                      mood: creature?.mood ?? CreatureMood.content),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _flameRow(creature),
              const SizedBox(height: AppSpacing.xxl),
              PromptBanner(coupleId: coupleId),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flameRow(CreatureState? creature) {
    final lit = creature?.flameLit ?? false;
    final number = creature?.flameNumber ?? 0;
    final stage = creature?.stageLabel ?? '';
    return BondCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: lit ? AppColors.mint : AppColors.inkFaint,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number', style: AppText.title),
              Text('bond score', style: AppText.bodySmall),
            ],
          ),
          if (stage.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.lg),
            BondChip(label: stage, tone: BondChipTone.mint),
          ],
        ],
      ),
    );
  }
}
