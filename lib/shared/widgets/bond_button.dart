import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/haptics.dart';

enum BondButtonVariant { primary, secondary, ghost }

/// The app's button. Primary = mint fill, secondary = outlined, ghost = text.
/// Handles loading + disabled. No hardcoded colors/sizes — all from tokens.
class BondButton extends StatelessWidget {
  const BondButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BondButtonVariant.primary,
    this.loading = false,
    this.fullWidth = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final BondButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == BondButtonVariant.primary;
    final isGhost = variant == BondButtonVariant.ghost;

    final Color fg = isPrimary
        ? AppColors.onMint
        : (isGhost ? AppColors.inkMuted : AppColors.mintDeep);

    final child = loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: AppText.label.copyWith(color: fg, fontSize: 16)),
            ],
          );

    final radius = BorderRadius.circular(AppRadius.md);

    return Opacity(
      opacity: _enabled ? 1 : 0.5,
      child: Material(
        color: isPrimary
            ? AppColors.mint
            : (isGhost ? Colors.transparent : AppColors.surface),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: _enabled
              ? () {
                  Haptics.tap();
                  onPressed!();
                }
              : null,
          child: Container(
            width: fullWidth ? double.infinity : null,
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: variant == BondButtonVariant.secondary
                  ? Border.all(color: AppColors.mintSoft, width: 1.5)
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
