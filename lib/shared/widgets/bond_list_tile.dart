import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Soft list row for settings/lists. Optional leading icon + trailing widget.
class BondListTile extends StatelessWidget {
  const BondListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.subtitleColor,
    this.badgeColor,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Optional overrides (e.g. ink subtitles on a tinted card, a gold badge).
  final Color? subtitleColor;
  final Color? badgeColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: badgeColor ?? AppColors.mintWash,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(leadingIcon, size: 20, color: iconColor ?? AppColors.mint),
                ),
                const SizedBox(width: AppSpacing.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyLarge),
                    if (subtitle case final s?)
                      Text(s,
                          style: AppText.bodySmall
                              .copyWith(color: subtitleColor)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
