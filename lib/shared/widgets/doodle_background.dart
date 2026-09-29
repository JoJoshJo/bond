import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Where a doodle field fades out, as fractions (0–1) of the field's extent
/// along [direction]: full strength up to [start], linearly (smoothstepped) to
/// fully transparent at [end], and NOTHING is painted past [end].
@immutable
class DoodleFade {
  const DoodleFade({
    this.direction = AxisDirection.down,
    this.start = 0.12,
    this.end = 0.62,
  }) : assert(start >= 0 && end <= 1 && start < end);

  /// The direction the doodles fade *toward*. `down` = strong at the top,
  /// gone by [end] of the height.
  final AxisDirection direction;
  final double start;
  final double end;

  /// No fade: uniform strength everywhere.
  static const none = DoodleFade(start: 0.999, end: 1.0);

  // Value equality so the painter only repaints when the fade actually changes.
  @override
  bool operator ==(Object other) =>
      other is DoodleFade &&
      other.direction == direction &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(direction, start, end);
}

/// A full-bleed, tiled field of small hollow line-art doodles (the creature
/// glyph + couple-themed motifs), painted over a solid [base] color and faded
/// along [fade].
///
/// Tuning lives here: [color] + [opacity] set the strength, [fade] sets the
/// direction and start/end. Pass `color: null` to render just the plain base
/// (how themes without a doodle token keep their existing look).
///
/// Performance: one [CustomPainter] inside a [RepaintBoundary]. Glyph paths are
/// built once (static), each doodle is a translate/rotate + one stroked path,
/// and the fade is baked into each doodle's alpha — no full-screen saveLayer /
/// ShaderMask. Place it OUTSIDE the scrolling content (e.g. behind a
/// transparent Scaffold) so it's painted once and cached while the list
/// scrolls and while the keyboard animates.
class DoodleBackground extends StatelessWidget {
  const DoodleBackground({
    super.key,
    required this.base,
    required this.color,
    this.opacity = defaultOpacity,
    this.fade = const DoodleFade(),
    this.cell = 40,
    this.strokeWidth = 1.0,
  });

  /// Default doodle strength — subtle by design.
  static const double defaultOpacity = 0.16;

  final Color base;
  final Color? color;
  final double opacity;
  final DoodleFade fade;

  /// Grid pitch in logical px (smaller = denser).
  final double cell;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color;
    return RepaintBoundary(
      child: ColoredBox(
        color: base,
        child: c == null
            ? const SizedBox.expand()
            : CustomPaint(
                size: Size.infinite,
                painter: _DoodlePainter(
                  color: c,
                  opacity: opacity,
                  fade: fade,
                  cell: cell,
                  strokeWidth: strokeWidth,
                ),
              ),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({
    required this.color,
    required this.opacity,
    required this.fade,
    required this.cell,
    required this.strokeWidth,
  });

  final Color color;
  final double opacity;
  final DoodleFade fade;
  final double cell;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    final glyphs = _Glyphs.all;

    for (var r = 0; r < rows; r++) {
      // Staggered (brick) rows so the tiling doesn't read as a stiff grid.
      final xOffset = r.isOdd ? cell / 2 : 0.0;
      for (var c = 0; c < cols; c++) {
        final center = Offset(c * cell + xOffset + cell / 2, r * cell + cell / 2);
        final strength = _fadeAt(center, size);
        if (strength <= 0) continue; // past the fade end: paint nothing
        final h = _hash(r, c);
        paint.color = color.withValues(alpha: opacity * strength);
        canvas
          ..save()
          ..translate(center.dx, center.dy)
          // Gentle, deterministic tilt (±20°) for a hand-drawn feel.
          ..rotate(((h % 41) - 20) * math.pi / 180);
        canvas.drawPath(glyphs[h % glyphs.length], paint);
        canvas.restore();
      }
    }
  }

  /// 1 = full strength, 0 = fully faded, smoothstepped between start and end.
  double _fadeAt(Offset p, Size size) {
    final t = switch (fade.direction) {
      AxisDirection.down => p.dy / size.height,
      AxisDirection.up => 1 - p.dy / size.height,
      AxisDirection.right => p.dx / size.width,
      AxisDirection.left => 1 - p.dx / size.width,
    };
    if (t <= fade.start) return 1;
    if (t >= fade.end) return 0;
    final x = 1 - (t - fade.start) / (fade.end - fade.start);
    return x * x * (3 - 2 * x);
  }

  static int _hash(int r, int c) {
    var h = r * 73856093 ^ c * 19349663;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) =>
      old.color != color ||
      old.opacity != opacity ||
      old.fade != fade ||
      old.cell != cell ||
      old.strokeWidth != strokeWidth;
}

/// The doodle set — outline paths centered on (0,0), ~16px across. Built once.
abstract final class _Glyphs {
  static final List<Path> all = [
    _creature(),
    _heart(),
    _moon(),
    _ring(),
    _coffee(),
    _star(),
    _bubble(),
    _plane(),
    _heart(), // hearts appear a little more often
  ];

  /// The creature: round body, two ears, dot eyes, a small smile.
  static Path _creature() => Path()
    ..addOval(Rect.fromCenter(center: const Offset(0, 1.5), width: 14, height: 13))
    ..addOval(Rect.fromCircle(center: const Offset(-5, -5), radius: 2.2))
    ..addOval(Rect.fromCircle(center: const Offset(5, -5), radius: 2.2))
    ..addOval(Rect.fromCircle(center: const Offset(-2.4, 0.5), radius: 0.6))
    ..addOval(Rect.fromCircle(center: const Offset(2.4, 0.5), radius: 0.6))
    ..moveTo(-1.8, 3.2)
    ..quadraticBezierTo(0, 4.8, 1.8, 3.2);

  static Path _heart() => Path()
    ..moveTo(0, 6)
    ..cubicTo(-9, 0, -5, -8, 0, -3)
    ..cubicTo(5, -8, 9, 0, 0, 6)
    ..close();

  static Path _moon() => Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 6.5)),
        Path()..addOval(Rect.fromCircle(center: const Offset(3.2, -2.4), radius: 5.6)),
      );

  /// A ring with a small diamond.
  static Path _ring() => Path()
    ..addOval(Rect.fromCircle(center: const Offset(0, 2.5), radius: 5))
    ..moveTo(0, -2.5)
    ..lineTo(-2.4, -5)
    ..lineTo(0, -7.5)
    ..lineTo(2.4, -5)
    ..close();

  /// A coffee cup with a handle and two wisps of steam.
  static Path _coffee() => Path()
    ..addRRect(RRect.fromRectAndCorners(
      const Rect.fromLTWH(-6, -1, 9, 8),
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    ))
    ..addArc(Rect.fromCircle(center: const Offset(3.4, 2.6), radius: 2.4),
        -math.pi / 2, math.pi)
    ..moveTo(-3.5, -3)
    ..quadraticBezierTo(-2, -5, -3.5, -7)
    ..moveTo(0, -3)
    ..quadraticBezierTo(1.5, -5, 0, -7);

  static Path _star() {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? 7.0 : 3.0;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(radius * math.cos(a), radius * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  /// A little chat bubble with a tail.
  static Path _bubble() => Path()
    ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -6, 14, 10), const Radius.circular(4)))
    ..moveTo(-3, 4)
    ..lineTo(-4.5, 7.5)
    ..lineTo(0, 4);

  /// A paper plane with its center fold.
  static Path _plane() => Path()
    ..moveTo(-7, -1)
    ..lineTo(7, -6)
    ..lineTo(2, 7)
    ..lineTo(-1, 1.5)
    ..close()
    ..moveTo(-1, 1.5)
    ..lineTo(7, -6);
}
