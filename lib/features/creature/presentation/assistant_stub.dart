import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// Whether the floating assistant shows. On by default; toggled in Us settings.
/// (Session-only for now; persistence lands with the real assistant.)
final assistantFloatingEnabledProvider = StateProvider<bool>((ref) => true);

/// Floating quick-access entry to the creature-as-assistant. Stubbed for now —
/// the real natural-language tool-use (via the ai-router) is the next task.
/// Tap-only, never interrupts (per the interaction model).
class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.mint,
      foregroundColor: AppColors.onMint,
      onPressed: () => _openStub(context),
      child: const Icon(Icons.auto_awesome),
    );
  }

  void _openStub(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask BOND', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Soon you\'ll be able to ask your creature to find you a date, '
              'pull up a memory, and more — type or hold to speak. Coming next.',
              style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
