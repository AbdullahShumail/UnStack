import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// The UnStack logotype: an arrowhead leads the name and a tail trails it, so
/// the whole mark reads as a single arrow with the word riding on its shaft.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 44});

  /// Cap height of the lettering. Everything else is derived from it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = Palette.display(size, weight: FontWeight.w700)
        .copyWith(letterSpacing: -size * 0.02);
    final painter = TextPainter(
      text: TextSpan(text: 'UnStack', style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final head = size * 0.52;
    final gap = size * 0.30;
    final tail = size * 1.85;
    final width = head + gap + painter.width + gap + tail;

    return SizedBox(
      width: width,
      height: painter.height,
      child: CustomPaint(
        painter: _WordmarkPainter(painter: painter, headSize: head, gap: gap),
      ),
    );
  }
}

class _WordmarkPainter extends CustomPainter {
  _WordmarkPainter({
    required this.painter,
    required this.headSize,
    required this.gap,
  });

  final TextPainter painter;
  final double headSize;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final stroke = headSize * 0.30;

    final linePaint = Paint()
      ..shader = Palette.arrowShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Arrowhead, pointing left, at the head of the mark.
    final tip = stroke * 0.5;
    canvas.drawPath(
      Path()
        ..moveTo(headSize, midY - headSize * 0.62)
        ..lineTo(tip, midY)
        ..lineTo(headSize, midY + headSize * 0.62),
      linePaint,
    );

    // The word.
    final textX = headSize + gap;
    painter.paint(canvas, Offset(textX, 0));

    // Tail, running out to the right edge.
    canvas.drawLine(
      Offset(textX + painter.width + gap, midY),
      Offset(size.width - stroke * 0.5, midY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WordmarkPainter old) =>
      old.painter.text != painter.text || old.headSize != headSize;
}
