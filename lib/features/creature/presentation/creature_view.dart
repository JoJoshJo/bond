import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../shared/theme/app_colors.dart';
import '../data/creature_models.dart';

/// The creature — the app's centerpiece. The real art (a mint kawaii creature)
/// centered on a soft, mood-driven mint glow, gently breathing.
///
/// The PNG is pre-cropped to the creature's opaque bounding box and centered on
/// a square canvas, so `BoxFit.contain` + `Alignment.center` render it dead
/// center with no runtime offset needed.
class CreatureView extends StatelessWidget {
  const CreatureView({super.key, required this.mood, this.size = 200});

  final CreatureMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Mood tuning: glow intensity, breathing amplitude, and the celebratory
    // sparkles (thriving only).
    final (glow, breatheTo, sparkles) = switch (mood) {
      CreatureMood.resting => (0.14, 1.02, false),
      CreatureMood.content => (0.24, 1.05, false),
      CreatureMood.thriving => (0.42, 1.07, true),
    };

    // Mood-driven aura tint — warmer & sunlit when thriving, cooler & calmer
    // when resting. Stays in the mint family so the identity never shifts.
    final Color auraTint = switch (mood) {
      CreatureMood.resting => const Color(0xFFC4E7E7), // cool, restful
      CreatureMood.content => const Color(0xFFCDEFE0), // neutral mint
      CreatureMood.thriving => const Color(0xFFE3F3C9), // warm, sunlit
    };

    Widget creature = _body(glow, auraTint);

    // Gentle, slow breathing + a soft float bob (unchanged idle animation).
    creature = creature
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 0.98, end: breatheTo, duration: 3000.ms, curve: Curves.easeInOut)
        .moveY(begin: 4, end: -6, duration: 3000.ms, curve: Curves.easeInOut);

    if (sparkles) {
      creature = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          creature,
          _sparkle(-0.7, -0.6, 0),
          _sparkle(0.75, -0.4, 400),
          _sparkle(0.2, -0.85, 800),
        ],
      );
    }

    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // soft grounding shadow
          Align(
            alignment: const Alignment(0, 0.72),
            child: Container(
              height: size * 0.09,
              width: size * 0.62,
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          creature,
        ],
      ),
    );
  }

  Widget _body(double glowOpacity, Color auraTint) {
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Mood-driven mint glow/aura BEHIND the creature — a soft radial
          // tint plus a wide ambient bloom. No hard disc; reads as a halo.
          Container(
            height: size * 0.9,
            width: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  auraTint.withValues(alpha: 0.55),
                  AppColors.mintWash.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mint.withValues(alpha: glowOpacity),
                  blurRadius: size * 0.5,
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
  }

  Widget _sparkle(double ax, double ay, int delayMs) {
    return Align(
      alignment: Alignment(ax, ay),
      child: Icon(Icons.auto_awesome, size: size * 0.12, color: AppColors.mint)
          .animate(onPlay: (c) => c.repeat())
          .fadeIn(delay: delayMs.ms, duration: 700.ms)
          .then()
          .fadeOut(duration: 700.ms),
    );
  }
}
