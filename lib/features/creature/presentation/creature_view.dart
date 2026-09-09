import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../shared/theme/app_colors.dart';
import '../data/creature_models.dart';

/// The creature — the app's centerpiece. Procedural placeholder for now (soft
/// mint blob with a face); swap-ready for real art.
///
/// SWAP POINT: when the generated PNGs land, replace `_body` with
/// `Image.asset('assets/creature/creature_<mood>.png')` per mood. Nothing else
/// on the home screen changes.
class CreatureView extends StatelessWidget {
  const CreatureView({super.key, required this.mood, this.size = 200});

  final CreatureMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Mood tuning (procedural stand-ins for the future art states).
    final (glow, breatheTo, eyesClosed, sparkles) = switch (mood) {
      CreatureMood.resting => (0.18, 1.02, true, false),
      CreatureMood.content => (0.30, 1.05, false, false),
      CreatureMood.thriving => (0.45, 1.07, false, true),
    };

    Widget creature = _body(glow, eyesClosed);

    // Gentle, slow breathing + a soft float bob.
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

  Widget _body(double glowOpacity, bool eyesClosed) {
    final eyeW = size * 0.09;
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4), // light from upper-left
          radius: 1.05,
          colors: [Color(0xFFCDEFE0), AppColors.mintSoft, AppColors.mint],
          stops: [0.0, 0.45, 1.0],
        ),
        boxShadow: [
          // wide ambient glow
          BoxShadow(
            color: AppColors.mint.withValues(alpha: glowOpacity),
            blurRadius: size * 0.55,
            spreadRadius: size * 0.06,
          ),
          // tighter inner glow for depth
          BoxShadow(
            color: AppColors.mint.withValues(alpha: glowOpacity * 0.6),
            blurRadius: size * 0.18,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // top sheen highlight
          Align(
            alignment: const Alignment(-0.35, -0.55),
            child: Container(
              height: size * 0.34,
              width: size * 0.42,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          // cream belly
          Align(
            alignment: const Alignment(0, 0.35),
            child: Container(
              height: size * 0.4,
              width: size * 0.5,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF6EC).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          // eyes
          Align(
            alignment: const Alignment(0, -0.1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _eye(eyeW, eyesClosed),
                SizedBox(width: size * 0.16),
                _eye(eyeW, eyesClosed),
              ],
            ),
          ),
          // rosy cheeks
          Align(
            alignment: const Alignment(0, 0.08),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cheek(),
                SizedBox(width: size * 0.34),
                _cheek(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye(double w, bool closed) {
    if (closed) {
      // peaceful closed eye (a soft downward arc)
      return Container(
        width: w,
        height: w * 0.35,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(w),
        ),
      );
    }
    return Container(
      width: w,
      height: w,
      decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
      child: Align(
        alignment: const Alignment(-0.3, -0.4),
        child: Container(
          width: w * 0.32,
          height: w * 0.32,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _cheek() {
    return Container(
      width: size * 0.12,
      height: size * 0.08,
      decoration: BoxDecoration(
        color: const Color(0xFFF6A6A0).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(size),
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
