import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/direction.dart';
import '../../theme/palette.dart';
import 'arrow_glyph.dart';

/// One blurred arrow drifting behind the board.
class _Ghost {
  const _Ghost({
    required this.x,
    required this.y,
    required this.depth,
    required this.phase,
    required this.speed,
    required this.dir,
  });

  final double x;
  final double y;

  /// 0 is nearest, 1 furthest. Drives size, blur and how far it drifts.
  final double depth;

  final double phase;
  final double speed;
  final Direction dir;
}

/// A soft, out-of-focus drift of arrows behind the playfield.
///
/// It thins out as the board is cleared: [intensity] is the share of arrows
/// still in play, and the number of ghosts follows it. The backdrop empties as
/// the board does, so progress is felt as well as counted.
///
/// Everything here is deliberately far below the board in contrast. If a ghost
/// ever competes with a real arrow it stops being atmosphere and starts being
/// noise the player has to filter out.
class BoardBackdrop extends StatefulWidget {
  const BoardBackdrop({super.key, required this.intensity});

  /// 0..1, the fraction of the level's arrows still on the board.
  final double intensity;

  @override
  State<BoardBackdrop> createState() => _BoardBackdropState();
}

class _BoardBackdropState extends State<BoardBackdrop>
    with SingleTickerProviderStateMixin {
  static const List<_Ghost> _field = [
    _Ghost(x: 0.18, y: 0.16, depth: 0.15, phase: 0.0, speed: 0.62, dir: Direction.right),
    _Ghost(x: 0.82, y: 0.27, depth: 0.55, phase: 1.7, speed: 0.48, dir: Direction.up),
    _Ghost(x: 0.30, y: 0.46, depth: 0.85, phase: 3.1, speed: 0.40, dir: Direction.left),
    _Ghost(x: 0.72, y: 0.58, depth: 0.30, phase: 4.4, speed: 0.55, dir: Direction.down),
    _Ghost(x: 0.22, y: 0.74, depth: 0.65, phase: 2.2, speed: 0.44, dir: Direction.right),
    _Ghost(x: 0.62, y: 0.86, depth: 0.95, phase: 5.6, speed: 0.36, dir: Direction.left),
    _Ghost(x: 0.46, y: 0.34, depth: 0.45, phase: 0.8, speed: 0.52, dir: Direction.down),
    _Ghost(x: 0.86, y: 0.70, depth: 0.75, phase: 3.9, speed: 0.42, dir: Direction.up),
  ];

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 23),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => CustomPaint(
          painter: _BackdropPainter(
            field: _field,
            clock: _clock.value * 2 * math.pi,
            intensity: widget.intensity.clamp(0.0, 1.0),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.field,
    required this.clock,
    required this.intensity,
  });

  final List<_Ghost> field;
  final double clock;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // Ghosts drop out as the board empties. The fractional part fades the last
    // one rather than popping it, so clearing an arrow never makes the
    // backdrop flicker.
    final exact = intensity * field.length;
    final whole = exact.floor();
    final partial = exact - whole;

    for (var i = 0; i < field.length; i++) {
      if (i > whole) continue;
      final fade = i == whole ? partial : 1.0;
      if (fade <= 0.02) continue;
      _paintGhost(canvas, size, field[i], fade);
    }
  }

  void _paintGhost(Canvas canvas, Size size, _Ghost g, double fade) {
    final t = clock * g.speed + g.phase;
    final near = 1 - g.depth;

    final glyph = size.shortestSide * (0.12 + near * 0.13);
    final travel = size.height * (0.012 + near * 0.03);

    final centre = Offset(
      g.x * size.width + math.cos(t * 0.7) * travel,
      g.y * size.height + math.sin(t) * travel,
    );

    // Blur via the paint's mask rather than an ImageFilter layer: a filtered
    // layer would be re-rasterised every frame for an effect nobody looks at.
    final blur = 6.0 + g.depth * 12.0;
    final alpha = (0.022 + near * 0.024) * fade;

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(g.dir.turns * 2 * math.pi + math.sin(t * 0.4) * 0.12);
    canvas.drawPath(
      buildArrowPath(glyph),
      Paint()
        ..color = Palette.arrow.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = arrowStroke(glyph) * 1.35
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.clock != clock || old.intensity != intensity;
}
