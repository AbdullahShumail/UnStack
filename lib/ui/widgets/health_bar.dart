import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// Health drawn as a row of arrows, matching the board's line-art.
///
/// The whole row takes the colour of the *current* level — green while
/// comfortable, blue as a warning, red on the last one — so the state reads
/// from colour alone without counting segments.
class HealthBar extends StatelessWidget {
  const HealthBar({
    super.key,
    required this.health,
    required this.max,
    this.size = 22,
  });

  final int health;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Palette.health(health);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final alive = i < health;
        return Padding(
          padding: EdgeInsets.only(right: i == max - 1 ? 0 : size * 0.22),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            scale: alive ? 1 : 0.72,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: alive ? 1 : 0.22,
              child: TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 320),
                tween: ColorTween(
                  end: alive ? color : Palette.textDim,
                ),
                builder: (context, value, _) => CustomPaint(
                  size: Size(size, size),
                  painter: _ArrowGlyph(value ?? color),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ArrowGlyph extends CustomPainter {
  const _ArrowGlyph(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.135
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(-s * 0.38, 0)
      ..lineTo(s * 0.26, 0)
      ..moveTo(s * 0.04, -s * 0.24)
      ..lineTo(s * 0.38, 0)
      ..lineTo(s * 0.04, s * 0.24);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowGlyph old) => old.color != color;
}
