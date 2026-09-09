import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';

/// 🏀 Free Throws — a marker sweeps up/down a power bar (linear, ping-pong; no
/// physics). Tap in the sweet zone to shoot; the ball follows a scripted arc to
/// the hoop on a make. [shots] attempts → total via [onFinished] with per-shot
/// points.
///
/// Dead-center = Swish (2) · within make-zone = In (1) · else Miss (0).
/// Max = shots × 2.
class FreeThrowsGame extends StatefulWidget {
  const FreeThrowsGame({
    super.key,
    required this.shots,
    required this.onFinished,
  });

  final int shots;
  final void Function(int score, List<int> perShot) onFinished;

  @override
  State<FreeThrowsGame> createState() => _FreeThrowsGameState();
}

class _FreeThrowsGameState extends State<FreeThrowsGame>
    with TickerProviderStateMixin {
  late final AnimationController _meter; // sweeping marker (0..1, ping-pong)
  late final AnimationController _flight; // ball flight for one shot

  final _perShot = <int>[];
  int? _lastPoints;
  bool _shooting = false; // ball in flight; meter frozen

  // Zone half-widths around center (0.5), as fraction of the bar.
  static const _swishHalf = 0.055;
  static const _makeHalf = 0.16;

  @override
  void initState() {
    super.initState();
    _meter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _meter.dispose();
    _flight.dispose();
    super.dispose();
  }

  int get _shotsTaken => _perShot.length;
  int get _total => _perShot.fold(0, (a, b) => a + b);
  int get _made => _perShot.where((p) => p > 0).length;

  int _pointsFor(double v) {
    final d = (v - 0.5).abs();
    if (d <= _swishHalf) return 2;
    if (d <= _makeHalf) return 1;
    return 0;
  }

  Future<void> _shoot() async {
    if (_shooting || _shotsTaken >= widget.shots) return;
    final v = _meter.value;
    final pts = _pointsFor(v);
    setState(() {
      _shooting = true;
      _lastPoints = pts;
      _perShot.add(pts);
    });
    _meter.stop();
    await _flight.forward(from: 0);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    if (_shotsTaken >= widget.shots) {
      widget.onFinished(_total, List.of(_perShot));
      return;
    }
    setState(() {
      _shooting = false;
      _lastPoints = null;
    });
    _meter.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final made = _lastPoints != null && _lastPoints! > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _scoreHeader(),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(builder: (context, constraints) {
          final w = math.min(constraints.maxWidth, 320.0);
          final h = w * 1.05;
          return GestureDetector(
            onTap: _shoot,
            child: SizedBox(
              width: w,
              height: h,
              child: AnimatedBuilder(
                animation: Listenable.merge([_meter, _flight]),
                builder: (context, _) => CustomPaint(
                  painter: _CourtPainter(
                    meter: _meter.value,
                    flight: _shooting ? _flight.value : 0,
                    shooting: _shooting,
                    made: made,
                    swishHalf: _swishHalf,
                    makeHalf: _makeHalf,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 34,
          child: _lastPoints == null
              ? Text(
                  _shooting ? '' : 'Tap in the green to shoot',
                  style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
                )
              : Text(
                  _lastPoints == 2
                      ? 'Swish! +2'
                      : _lastPoints == 1
                          ? 'In! +1'
                          : 'Miss',
                  key: ValueKey(_shotsTaken),
                  style: AppText.title.copyWith(
                    color: made ? AppColors.mintDeep : AppColors.inkMuted,
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
        Text('$_total pts · $_made/${widget.shots}',
            style: AppText.headline.copyWith(color: AppColors.mintDeep)),
      ],
    );
  }
}

class _CourtPainter extends CustomPainter {
  _CourtPainter({
    required this.meter,
    required this.flight,
    required this.shooting,
    required this.made,
    required this.swishHalf,
    required this.makeHalf,
  });

  final double meter; // 0..1 marker position
  final double flight; // 0..1 ball flight progress
  final bool shooting;
  final bool made;
  final double swishHalf;
  final double makeHalf;

  @override
  void paint(Canvas canvas, Size size) {
    // Backdrop.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      Paint()..color = AppColors.surfaceAlt,
    );

    final hoopY = size.height * 0.16;
    final hoopCx = size.width / 2;
    final rimW = size.width * 0.22;

    // Backboard.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(hoopCx, hoopY - 26), width: rimW * 1.5, height: 40),
        const Radius.circular(6),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.inkFaint,
    );
    // Rim.
    canvas.drawLine(
      Offset(hoopCx - rimW / 2, hoopY),
      Offset(hoopCx + rimW / 2, hoopY),
      Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.mintDeep,
    );

    // ---- Power meter (vertical bar on the right) ----
    final barX = size.width * 0.86;
    final barTop = size.height * 0.30;
    final barBot = size.height * 0.92;
    final barH = barBot - barTop;
    final barRect = Rect.fromLTWH(barX - 9, barTop, 18, barH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(9)),
      Paint()..color = AppColors.mintWash,
    );
    // Make zone (lighter) + swish zone (mint) centered.
    double yForV(double v) => barTop + (1 - v) * barH; // v=1 top
    Rect zone(double half) => Rect.fromLTRB(
        barX - 9, yForV(0.5 + half), barX + 9, yForV(0.5 - half));
    canvas.drawRRect(
      RRect.fromRectAndRadius(zone(makeHalf), const Radius.circular(9)),
      Paint()..color = AppColors.mintSoft,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(zone(swishHalf), const Radius.circular(6)),
      Paint()..color = AppColors.mint,
    );
    // Sweeping marker.
    final markerY = yForV(meter);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(barX, markerY), width: 34, height: 8),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.ink,
    );

    // ---- Ball ----
    final startPos = Offset(size.width * 0.30, size.height * 0.86);
    final ballR = size.width * 0.055;
    Offset ballPos;
    if (!shooting) {
      ballPos = startPos;
    } else if (made) {
      // Scripted arc to the hoop, then drop through.
      final endPos = Offset(hoopCx, hoopY + 4);
      final p = Curves.easeOut.transform(flight);
      final x = startPos.dx + (endPos.dx - startPos.dx) * p;
      // Parabolic lift: peaks above the rim mid-flight.
      final baseY = startPos.dy + (endPos.dy - startPos.dy) * p;
      final lift = math.sin(p * math.pi) * size.height * 0.20;
      ballPos = Offset(x, baseY - lift);
    } else {
      // Miss: short arc that falls off to the side of the rim.
      final endPos = Offset(hoopCx + rimW * 0.9, hoopY + size.height * 0.34);
      final x = startPos.dx + (endPos.dx - startPos.dx) * flight;
      final baseY = startPos.dy + (endPos.dy - startPos.dy) * flight;
      final lift = math.sin(flight * math.pi) * size.height * 0.16;
      ballPos = Offset(x, baseY - lift);
    }
    final ballPaint = Paint()..color = const Color(0xFFE8894A); // basketball orange
    canvas.drawCircle(ballPos, ballR, ballPaint);
    canvas.drawCircle(
      ballPos,
      ballR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x33000000),
    );
    // Seam.
    canvas.drawLine(
      Offset(ballPos.dx - ballR, ballPos.dy),
      Offset(ballPos.dx + ballR, ballPos.dy),
      Paint()
        ..strokeWidth = 1.5
        ..color = const Color(0x55000000),
    );
  }

  @override
  bool shouldRepaint(_CourtPainter old) =>
      old.meter != meter ||
      old.flight != flight ||
      old.shooting != shooting ||
      old.made != made;
}
