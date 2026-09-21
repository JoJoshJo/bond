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
import '../../calendar/application/calendar_providers.dart';
import '../../creature/presentation/creature_view.dart';
import '../../memories/application/memory_controller.dart';
import 'widgets/animated_flame.dart';
import 'widgets/bond_meter_pill.dart';
import 'widgets/home_bento.dart';

/// The emotional home: the creature front-and-center, the couple name, the Usora
/// flame + bond meter, then a bento of quick actions (talk to the creature,
/// today's question) over a contextual slot (next date / a memory from this day
/// / plan a date). First thing you see on open.
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
      // Tinted ground so the white cards + tiles read with soft depth instead
      // of white-on-white.
      backgroundColor: AppColors.bgAlt,
      floatingActionButton:
          showAssistant ? AssistantButton(coupleId: coupleId) : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(creatureStateProvider(coupleId));
            ref.invalidate(calendarControllerProvider(coupleId));
            ref.invalidate(memoryVaultProvider(coupleId));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPad),
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(coupleName,
                  textAlign: TextAlign.center,
                  style: AppText.displayMedium
                      .copyWith(color: AppColors.anchor)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                creature?.greeting ?? ' ',
                textAlign: TextAlign.center,
                // ink, not inkMuted: inkMuted is only 4.38:1 on the tinted bgAlt.
                style: AppText.bodyMedium.copyWith(color: AppColors.ink),
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
              const SizedBox(height: AppSpacing.lg),
              HomeBento(coupleId: coupleId),
              // Room to scroll the last card clear of the floating FAB.
              const SizedBox(height: AppSpacing.huge + 56),
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
          AnimatedFlame(number: number, lit: lit),
          if (stage.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.lg),
            BondMeterPill(
              label: stage,
              progress: creature?.stageProgress ?? 0,
              nextLabel: creature?.nextStageLabel,
            ),
          ],
        ],
      ),
    );
  }
}
