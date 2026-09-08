import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/direction.dart';
import '../../theme/palette.dart';
import 'arrow_glyph.dart';

/// One arrow drifting in the hero.
class _Drifter {
  const _Drifter({
    required this.x,
    required this.y,
    required this.depth,
    required this.phase,
    required this.speed,
    required this.dir,
  });

  /// Position as a fraction of the hero box.
  final double x;
  final double y;

  /// 0 is closest to the viewer, 1 is furthest. Drives size, opacity and how
  /// far the arrow travels — near things move more, which is what sells depth.
  final double depth;

  final double phase;
  final double speed;
  final Direction dir;
}

/// A slow, three-dimensional drift of arrows sitting under the wordmark.
///
/// Everything runs off one ticker: each arrow derives its motion from the
/// shared clock plus its own phase, so the whole field never repeats visibly
/// but costs a single animation.
class FloatingArrows extends StatefulWidget {
  const FloatingArrows({super.key});

  /// Positions stay inside the margins below so no arrow is ever sliced by a
  /// screen edge — a half-drawn arrow reads as a rendering bug, not as depth.
  static const double _marginX = 0.20;
  static const double _marginY = 0.16;

  static const List<_Drifter> _field = [
    _Drifter(x: 0.26, y: 0.30, depth: 0.05, phase: 0.0, speed: 1.00, dir: Direction.right),
    _Drifter(x: 0.76, y: 0.24, depth: 0.30, phase: 1.9, speed: 0.82, dir: Direction.up),
    _Drifter(x: 0.52, y: 0.60, depth: 0.00, phase: 3.4, speed: 1.15, dir: Direction.left),
    _Drifter(x: 0.30, y: 0.76, depth: 0.55, phase: 0.9, speed: 0.70, dir: Direction.down),
    _Drifter(x: 0.78, y: 0.70, depth: 0.72, phase: 2.6, speed: 0.62, dir: Direction.right),
    _Drifter(x: 0.60, y: 0.13, depth: 0.85, phase: 4.7, speed: 0.55, dir: Direction.left),
    _Drifter(x: 0.24, y: 0.52, depth: 0.90, phase: 5.5, speed: 0.48, dir: Direction.up),
  ];

  @override
  State<FloatingArrows> createState() => _FloatingArrowsState();
}

class _FloatingArrowsState extends State<FloatingArrows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    // Long and prime-ish against the per-arrow speeds so the field does not
    // visibly loop.
    duration: const Duration(seconds: 17),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final clock = _clock.value * 2 * math.pi;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Soft light so the arrows feel lit rather than pasted on.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(gradient: Palette.heroGlow),
                  ),
                ),
                for (final d in FloatingArrows._field)
                  _buildDrifter(d, clock, w, h),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDrifter(_Drifter d, double clock, double w, double h) {
    final t = clock * d.speed + d.phase;

    // Near arrows are bigger, brighter and travel further.
    final near = 1 - d.depth;
    final glyph = h * (0.13 + near * 0.10);
    final travel = h * (0.025 + near * 0.045);

    final bob = math.sin(t) * travel;
    final sway = math.cos(t * 0.63) * travel * 0.7;

    // Keep the whole glyph, including its drift, inside the safe margins.
    final halfW = glyph / 2 + travel;
    final halfH = glyph / 2 + travel;
    final cx = (d.x * w).clamp(
      math.max(halfW, FloatingArrows._marginX * w),
      math.min(w - halfW, w * (1 - FloatingArrows._marginX) + halfW),
    );
    final cy = (d.y * h).clamp(
      math.max(halfH, FloatingArrows._marginY * h),
      math.min(h - halfH, h),
    );

    // Gentle tumble. Kept small — this should read as a drift, not a spin.
    final rotY = math.sin(t * 0.78) * 0.42;
    final rotX = math.cos(t * 0.54) * 0.26;
    final rotZ = math.sin(t * 0.41) * 0.10;

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0014) // perspective
      ..rotateX(rotX)
      ..rotateY(rotY)
      ..rotateZ(rotZ);

    return Positioned(
      left: cx - glyph / 2 + sway,
      top: cy - glyph / 2 + bob,
      width: glyph,
      height: glyph,
      child: Transform(
        alignment: Alignment.center,
        transform: transform,
        // A shader ignores Paint.color, so depth fading is applied here
        // rather than on the stroke itself. Kept dim overall: this is a
        // backdrop, and it must never out-shout the Play button.
        child: Opacity(
          opacity: 0.10 + near * 0.45,
          child: CustomPaint(painter: _DrifterPainter(dir: d.dir)),
        ),
      ),
    );
  }
}

class _DrifterPainter extends CustomPainter {
  const _DrifterPainter({required this.dir});

  final Direction dir;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(dir.turns * 2 * math.pi);

    final bounds = Rect.fromCenter(center: Offset.zero, width: s, height: s);

    canvas.drawPath(
      buildArrowPath(s),
      Paint()
        ..shader = Palette.arrowShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = arrowStroke(s)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DrifterPainter old) => old.dir != dir;
}
