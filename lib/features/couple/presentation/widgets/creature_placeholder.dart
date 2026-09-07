import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/app_colors.dart';

/// A soft, breathing mint orb standing in for the future creature.
///
/// SWAP POINT: when the real creature lands (a later layer), replace the body
/// of this widget with the creature view — every screen that shows
/// [CreaturePlaceholder] gets it for free, no other changes needed.
class CreaturePlaceholder extends StatelessWidget {
  const CreaturePlaceholder({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    final orb = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppColors.mintSoft, AppColors.mint],
          stops: [0.15, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.mint.withValues(alpha: 0.35),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.04,
          ),
        ],
      ),
      // A soft highlight to keep it warm, not flat.
      child: Align(
        alignment: const Alignment(-0.35, -0.4),
        child: Container(
          height: size * 0.28,
          width: size * 0.28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ),
    );

    // Tasteful slow breathing: gentle scale loop (the glow lives in the shadow).
    return orb
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 0.96,
          end: 1.05,
          duration: 2400.ms,
          curve: Curves.easeInOut,
        );
  }
}
