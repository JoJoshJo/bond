import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';

/// 🎯 Target Shot — a reticle wanders across a ringed target on a smooth
/// two-frequency sine path (pure trig, no physics). Tap to release; score by
/// radial distance from center. [shots] releases → total is reported via
/// [onFinished] with the per-shot points.
///
/// Rings (fraction of radius → points): ≤.11 bullseye 10 · ≤.30 = 8 · ≤.50 = 6
/// ≤.72 = 4 · ≤.92 = 2 · else 0. Max = shots × 10.
class TargetShotGame extends StatefulWidget {
  const TargetShotGame({
    super.key,
    required this.shots,
    required this.onFinished,
  });

  final int shots;
  final void Function(int score, List<int> perShot) onFinished;

  @override
  State<TargetShotGame> createState() => _TargetShotGameState();
}

class _TargetShotGameState extends State<TargetShotGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _perShot = <int>[];
  final _marks = <_Mark>[]; // landed shots (normalized offset from center)
  int? _lastPoints; // for the +N flash
  bool _locked = false; // brief freeze between shots

  // Path shape: different X/Y frequencies + phase → a roving, non-repeating feel.
  static const _ampX = 0.82, _ampY = 0.82, _freqX = 1.0, _freqY = 1.63;
  final _phaseX = math.Random().nextDouble() * math.pi * 2;
  final _phaseY = math.Random().nextDouble() * math.pi * 2;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _shotsTaken => _perShot.length;
  int get _total => _perShot.fold(0, (a, b) => a + b);

  /// Normalized reticle offset from center in [-1, 1] on each axis.
  Offset _reticleAt(double t) => Offset(
        _ampX * math.sin(2 * math.pi * _freqX * t + _phaseX),
        _ampY * math.sin(2 * math.pi * _freqY * t + _phaseY),
      );

  int _pointsFor(double r) {
    if (r <= 0.11) return 10;
    if (r <= 0.30) return 8;
    if (r <= 0.50) return 6;
    if (r <= 0.72) return 4;
    if (r <= 0.92) return 2;
    return 0;
  }

  Future<void> _release() async {
    if (_locked || _shotsTaken >= widget.shots) return;
    final pos = _reticleAt(_ctrl.value);
    final r = pos.distance.clamp(0.0, 1.0);
    final pts = _pointsFor(r);
    setState(() {
      _locked = true;
      _lastPoints = pts;
      _marks.add(_Mark(pos, pts));
      _perShot.add(pts);
    });
    _ctrl.stop();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (_shotsTaken >= widget.shots) {
      widget.onFinished(_total, List.of(_perShot));
      return;
    }
    setState(() {
      _locked = false;
      _lastPoints = null;
    });
    _ctrl.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _scoreHeader(),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, 300.0);
          return GestureDetector(
            onTap: _release,
            child: SizedBox(
              width: side,
              height: side,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final reticle = _locked && _marks.isNotEmpty
                      ? _marks.last.pos
                      : _reticleAt(_ctrl.value);
                  return CustomPaint(
                    painter: _TargetPainter(
                      reticle: reticle,
                      marks: _marks,
                      locked: _locked,
                    ),
                  );
                },
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 34,
          child: _lastPoints == null
              ? Text(
                  _locked ? '' : 'Tap to release',
                  style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
                )
              : Text(
                  _lastPoints == 10
                      ? 'Bullseye! +10'
                      : _lastPoints == 0
                          ? 'Missed the target'
                          : '+$_lastPoints',
                  key: ValueKey(_shotsTaken),
                  style: AppText.title.copyWith(
                    color: _lastPoints == 0 ? AppColors.inkMuted : AppColors.mintDeep,
                  ),
                )
                  .animate()
                  .fadeIn(duration: 180.ms)
                  .scaleXY(begin: 0.6, end: 1, curve: Curves.easeOutBack),
        ),
      ],
    );
  }

  Widget _scoreHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Shot ${math.min(_shotsTaken + 1, widget.shots)} / ${widget.shots}',
            style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
        Text('$_total',
            style: AppText.headline.copyWith(color: AppColors.mintDeep)),
      ],
    );
  }
}

class _Mark {
  const _Mark(this.pos, this.points);
  final Offset pos; // normalized [-1,1]
  final int points;
}

class _TargetPainter extends CustomPainter {
  _TargetPainter({
    required this.reticle,
    required this.marks,
    required this.locked,
  });

  final Offset reticle; // normalized [-1,1]
  final List<_Mark> marks;
  final bool locked;

  // Ring boundaries (outer→in) as fraction of radius, with fill tints.
  static const _rings = <double>[1.0, 0.92, 0.72, 0.50, 0.30, 0.11];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.width / 2;

    // Backdrop.
    final bg = Paint()..color = AppColors.surfaceAlt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      bg,
    );

    // Concentric rings, alternating mint tints (lighter outside, deeper in).
    for (var i = 0; i < _rings.length; i++) {
      final frac = _rings[i];
      final t = i / (_rings.length - 1); // 0 outer → 1 center
      final color = Color.lerp(AppColors.mintWash, AppColors.mintSoft, t)!;
      canvas.drawCircle(c, radius * frac, Paint()..color = color);
      canvas.drawCircle(
        c,
        radius * frac,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.border,
      );
    }
    // Bullseye dot.
    canvas.drawCircle(c, radius * 0.04, Paint()..color = AppColors.mintDeep);

    // Landed marks.
    for (final m in marks) {
      final p = c + Offset(m.pos.dx * radius, m.pos.dy * radius);
      final hit = m.points > 0;
      canvas.drawCircle(p, 6, Paint()..color = hit ? AppColors.mintDeep : AppColors.inkFaint);
      canvas.drawCircle(
        p,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }

    // Live reticle (crosshair) — hidden isn't needed; drawn on top.
    final rp = c + Offset(reticle.dx * radius, reticle.dy * radius);
    final reticlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = locked ? AppColors.mintDeep : AppColors.ink;
    canvas.drawCircle(rp, 12, reticlePaint);
    canvas.drawLine(rp + const Offset(-16, 0), rp + const Offset(-6, 0), reticlePaint);
    canvas.drawLine(rp + const Offset(6, 0), rp + const Offset(16, 0), reticlePaint);
    canvas.drawLine(rp + const Offset(0, -16), rp + const Offset(0, -6), reticlePaint);
    canvas.drawLine(rp + const Offset(0, 6), rp + const Offset(0, 16), reticlePaint);
  }

  @override
  bool shouldRepaint(_TargetPainter old) =>
      old.reticle != reticle || old.marks.length != marks.length || old.locked != locked;
}
