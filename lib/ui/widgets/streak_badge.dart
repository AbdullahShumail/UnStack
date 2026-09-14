import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// How far a flawless streak has climbed, and what its fire looks like.
enum StreakTier {
  none,
  ember,
  red,
  purple,
  rainbow;

  static StreakTier of(int streak) {
    if (streak >= 200) return StreakTier.rainbow;
    if (streak >= 100) return StreakTier.purple;
    if (streak >= 50) return StreakTier.red;
    if (streak >= 30) return StreakTier.ember;
    return StreakTier.none;
  }

  /// Next threshold, or null once the top tier is reached.
  int? get next => switch (this) {
        StreakTier.none => 30,
        StreakTier.ember => 50,
        StreakTier.red => 100,
        StreakTier.purple => 200,
        StreakTier.rainbow => null,
      };
}

/// The flawless streak: arrows out in a row without a blocked tap.
///
/// Hidden at zero so the HUD stays quiet until there is something to show.
/// From 30 the number gets a living flame behind it, and the flame changes
/// colour at 50, 100 and 200. Crossing a tier pops the whole badge.
class StreakBadge extends StatefulWidget {
  const StreakBadge({super.key, required this.streak, this.height = 30});

  final int streak;
  final double height;

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with TickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late StreakTier _tier = StreakTier.of(widget.streak);

  @override
  void didUpdateWidget(covariant StreakBadge old) {
    super.didUpdateWidget(old);
    final tier = StreakTier.of(widget.streak);
    if (tier != _tier) {
      _tier = tier;
      // Celebrate going up; going back to nothing gets no fanfare.
      if (tier != StreakTier.none) _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak <= 0) return const SizedBox.shrink();

    final tier = StreakTier.of(widget.streak);
    final h = widget.height;

    return AnimatedBuilder(
      animation: Listenable.merge([_flicker, _pop]),
      builder: (context, _) {
        // Overshoot then settle, so a tier crossing is felt.
        final pop = Curves.elasticOut.transform(_pop.value);
        final scale = 1 + pop * 0.28 * (1 - _pop.value * 0.55);

        return Transform.scale(
          scale: scale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tier != StreakTier.none)
                SizedBox(
                  width: h * 0.9,
                  height: h * 1.25,
                  child: CustomPaint(
                    painter: _FlamePainter(
                      t: _flicker.value * 2 * math.pi,
                      tier: tier,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.local_fire_department_rounded,
                  size: h * 0.6,
                  color: Palette.textDim,
                ),
              SizedBox(width: h * 0.12),
              Text(
                '${widget.streak}',
                style: Palette.display(
                  h * 0.62,
                  weight: FontWeight.w700,
                ).copyWith(
                  color: tier == StreakTier.none
                      ? Palette.textDim
                      : Palette.text,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A living flame: three nested tongues that lean and flicker, with two
/// smaller licks either side and a soft glow behind. Everything is driven by
/// overlapping sines at unrelated rates so it never visibly loops.
class _FlamePainter extends CustomPainter {
  const _FlamePainter({required this.t, required this.tier});

  final double t;
  final StreakTier tier;

  /// Outer, middle and core colours for each tier. Rainbow is computed.
  List<Color> _colours(double phase) => switch (tier) {
        StreakTier.ember => const [
            Color(0xFFFF6A00),
            Color(0xFFFFA000),
            Color(0xFFFFE082),
          ],
        StreakTier.red => const [
            Color(0xFFC62828),
            Color(0xFFFF3D00),
            Color(0xFFFF8A65),
          ],
        StreakTier.purple => const [
            Color(0xFF6A1B9A),
            Color(0xFFC044FF),
            Color(0xFFF3B3FF),
          ],
        StreakTier.rainbow => [
            HSVColor.fromAHSV(1, (phase * 60) % 360, 0.95, 0.85).toColor(),
            HSVColor.fromAHSV(1, (phase * 60 + 40) % 360, 0.9, 1).toColor(),
            HSVColor.fromAHSV(1, (phase * 60 + 80) % 360, 0.35, 1).toColor(),
          ],
        StreakTier.none => const [Colors.transparent, Colors.transparent, Colors.transparent],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final colours = _colours(t);
    final cx = size.width / 2;
    final baseY = size.height * 0.96;
    final h = size.height * 0.92;
    final w = size.width * 0.78;

    // Glow first, under everything.
    canvas.drawPath(
      _tongue(cx, baseY, h * 0.95, w * 1.05, 0, 1.0),
      Paint()
        ..color = colours[1].withValues(alpha: 0.55)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );

    // Two side licks, lagging the main body.
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        _tongue(
          cx + side * w * 0.26,
          baseY,
          h * 0.5,
          w * 0.42,
          side * 1.9,
          0.85,
        ),
        Paint()..color = colours[0].withValues(alpha: 0.9),
      );
    }

    // Main body, outer to core.
    final scales = [1.0, 0.7, 0.42];
    for (var i = 0; i < 3; i++) {
      canvas.drawPath(
        _tongue(cx, baseY, h * scales[i], w * scales[i], i * 0.8, 1.0),
        Paint()..color = colours[i],
      );
    }
  }

  /// One flame tongue rising from ([cx], [baseY]) to a wobbling tip.
  Path _tongue(
    double cx,
    double baseY,
    double h,
    double w,
    double phase,
    double liveliness,
  ) {
    // The tip leans left and right; the height breathes. Rates are chosen so
    // they never line up, which is what keeps it from looking mechanical.
    final lean = (math.sin(t * 3.1 + phase) * 0.55 +
            math.sin(t * 7.3 + phase * 1.7) * 0.25) *
        w *
        0.32 *
        liveliness;
    final breathe = 1 + (math.sin(t * 5.7 + phase * 2.3) * 0.08 +
            math.sin(t * 11.0 + phase) * 0.04) *
        liveliness;
    final top = baseY - h * breathe;
    final tipX = cx + lean;

    // Shoulders lean with the tip, less so, which gives the body a sway.
    final shoulderY = baseY - h * 0.42;
    final sway = lean * 0.35;

    return Path()
      ..moveTo(cx, baseY)
      ..cubicTo(
        cx - w * 0.62, baseY - h * 0.06,
        cx - w * 0.52 + sway, shoulderY,
        tipX, top,
      )
      ..cubicTo(
        cx + w * 0.52 + sway, shoulderY,
        cx + w * 0.62, baseY - h * 0.06,
        cx, baseY,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) =>
      old.t != t || old.tier != tier;
}
