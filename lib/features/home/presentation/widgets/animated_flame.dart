import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../shared/utils/haptics.dart';

/// The flame icon + bond-score number. When the score INCREASES, the number
/// counts up and the flame gives a single satisfying pulse with a haptic — the
/// core reward moment. Honors the platform "reduce motion" setting (falls back
/// to the plain value, but keeps the haptic).
class AnimatedFlame extends StatefulWidget {
  const AnimatedFlame({super.key, required this.number, required this.lit});

  final int number;
  final bool lit;

  @override
  State<AnimatedFlame> createState() => _AnimatedFlameState();
}

class _AnimatedFlameState extends State<AnimatedFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didUpdateWidget(covariant AnimatedFlame old) {
    super.didUpdateWidget(old);
    if (widget.number > old.number) {
      Haptics.success(); // the reward buzz
      if (!_reduceMotion) _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion;

    final icon = AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        // Smooth 1.0 → 1.3 → 1.0 pulse.
        final scale = reduce ? 1.0 : 1 + 0.3 * math.sin(math.pi * _pulse.value);
        return Transform.scale(scale: scale, child: child);
      },
      child: Icon(
        Icons.local_fire_department_rounded,
        color: widget.lit ? AppColors.accent : AppColors.inkFaint, // gold accent
        size: 32,
      ),
    );

    final Widget number = reduce
        ? Text('${widget.number}', style: AppText.title)
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(end: widget.number.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text('${v.round()}', style: AppText.title),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            number,
            Text('bond score', style: AppText.bodySmall),
          ],
        ),
      ],
    );
  }
}
