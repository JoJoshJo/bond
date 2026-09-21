import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';

/// The level pill ("Hatchling") upgraded into a bond meter: the same label, with
/// a gold fill showing progress through the current stage toward the next one.
/// Gold is the screen's single sparing accent. At the final stage it reads full.
class BondMeterPill extends StatelessWidget {
  const BondMeterPill({
    super.key,
    required this.label,
    required this.progress,
    this.nextLabel,
  });

  final String label;

  /// 0–1 through the current stage.
  final double progress;

  /// The next stage's name (null at the final stage) — used for semantics.
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final percent = (p * 100).round();

    return Semantics(
      label: nextLabel == null
          ? '$label, top level'
          : '$label, $percent percent of the way to $nextLabel',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.mintWash,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.mintSoft),
            ),
            child: Stack(
              children: [
                // Gold progress fill, animated when the score moves.
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: p),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        heightFactor: 1,
                        child: ColoredBox(
                          color: AppColors.accent.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text(
                    label,
                    style: AppText.label.copyWith(color: AppColors.anchor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
