import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/app_colors.dart';

/// The real creature art on a soft mint glow, gently breathing. Shown on the
/// invite-waiting and daily-prompt screens; every screen that uses
/// [CreaturePlaceholder] gets the art for free.
class CreaturePlaceholder extends StatelessWidget {
  const CreaturePlaceholder({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    final creature = SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft mint glow behind the creature.
          Container(
            height: size * 0.9,
            width: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFCDEFE0).withValues(alpha: 0.55),
                  AppColors.mintWash.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mint.withValues(alpha: 0.28),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
          ),
          // The real creature art — dead center, contained, no overflow.
          Padding(
            padding: EdgeInsets.all(size * 0.04),
            child: Image.asset(
              'assets/creature/usora_creature.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );

    // Tasteful slow breathing: gentle scale loop.
    return creature
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 0.96,
          end: 1.05,
          duration: 2400.ms,
          curve: Curves.easeInOut,
        );
  }
}
