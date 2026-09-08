import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// The countdown on a surprise timed level.
///
/// Under the last few seconds it swells and shrinks on every beat and turns
/// red, so the pressure is felt peripherally — the player's eyes are on the
/// board, not on the number.
class LevelClock extends StatefulWidget {
  const LevelClock({
    super.key,
    required this.secondsLeft,
    required this.secondsTotal,
    required this.urgent,
  });

  final int secondsLeft;
  final int secondsTotal;
  final bool urgent;

  @override
  State<LevelClock> createState() => _LevelClockState();
}

class _LevelClockState extends State<LevelClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didUpdateWidget(covariant LevelClock old) {
    super.didUpdateWidget(old);
    // One swell per second, fired when the number actually changes so the
    // pulse stays locked to the tick sound.
    if (widget.secondsLeft != old.secondsLeft && widget.urgent) {
      _beat.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  String get _label {
    final s = widget.secondsLeft;
    if (s >= 60) {
      final m = s ~/ 60;
      final r = (s % 60).toString().padLeft(2, '0');
      return '$m:$r';
    }
    return '$s';
  }

  @override
  Widget build(BuildContext context) {
    final colour = widget.urgent ? Palette.healthLow : Palette.text;
    final fraction = widget.secondsTotal == 0
        ? 0.0
        : (widget.secondsLeft / widget.secondsTotal).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _beat,
      builder: (context, child) {
        // Swell out and settle back, rather than a linear throb.
        final beat = widget.urgent
            ? math.sin(_beat.value * math.pi) * (1 - _beat.value * 0.35)
            : 0.0;
        return Transform.scale(
          scale: 1 + beat * 0.22,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: widget.urgent
                ? Palette.healthLow.withValues(alpha: 0.85)
                : Palette.edge,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A ring that empties as the time goes.
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 2.4,
                backgroundColor: Palette.edge,
                valueColor: AlwaysStoppedAnimation(colour),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _label,
              style: Palette.ui(
                15,
                weight: FontWeight.w700,
                color: colour,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}
