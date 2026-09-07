import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// The signature soft, rounded surface with a gentle shadow. The warm building
/// block most content sits on. Optional tap for interactive cards.
class BondCard extends StatelessWidget {
  const BondCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
    this.color,
    this.radius = AppRadius.lg,
    this.border = false,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool border;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: borderRadius,
        border: border ? Border.all(color: AppColors.border) : null,
        boxShadow: elevated ? AppShadows.card : null,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
