import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum BondChipTone { mint, neutral, success, warning, error }

/// Small pill for statuses/tags. Soft tinted background + darker label.
class BondChip extends StatelessWidget {
  const BondChip({super.key, required this.label, this.tone = BondChipTone.mint, this.icon});

  final String label;
  final BondChipTone tone;
  final IconData? icon;

  ({Color bg, Color fg}) get _colors => switch (tone) {
        BondChipTone.mint => (bg: AppColors.mintWash, fg: AppColors.mintDeep),
        BondChipTone.neutral => (bg: AppColors.surfaceAlt, fg: AppColors.inkMuted),
        BondChipTone.success => (bg: AppColors.successBg, fg: AppColors.success),
        BondChipTone.warning => (bg: AppColors.warningBg, fg: AppColors.warning),
        BondChipTone.error => (bg: AppColors.errorBg, fg: AppColors.error),
      };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c.fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: AppText.bodySmall.copyWith(color: c.fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
