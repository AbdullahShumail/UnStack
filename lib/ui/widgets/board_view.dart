import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/board.dart';
import '../../engine/direction.dart';
import '../../state/game_controller.dart';
import '../../theme/palette.dart';
import 'arrow_glyph.dart';

/// An arrow currently flying off the board.
class _Flight {
  _Flight({
    required this.path,
    required this.dir,
    required this.controller,
  });

  final List<Cell> path;
  final Direction dir;
  final AnimationController controller;
}

/// A blocked launch, animating its recoil.
class _Recoil {
  const _Recoil({required this.from, required this.blocker, required this.dir});

  final Cell from;
  final Cell blocker;
  final Direction dir;
}

/// Renders the board and owns every transient animation.
///
/// The board model updates synchronously on tap; flights and recoils are
/// decorative overlays, so a fast tapper can never desync the two.
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.controller});

  final GameController controller;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  final List<_Flight> _flights = [];
  _Recoil? _recoil;
  Cell? _lastHinted;

  late final AnimationController _reject = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// Drives the full hint reveal: scrim in, arrow pops, scrim out.
  late final AnimationController _hintReveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  /// Slow breathing ring left on the hinted arrow after the reveal.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onModelChanged);
    for (final f in _flights) {
      f.controller.dispose();
    }
    _reject.dispose();
    _hintReveal.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Fires the reveal whenever a new hint lands, wherever it came from.
  void _onModelChanged() {
    final hinted = widget.controller.hinted;
    if (hinted != null && hinted != _lastHinted) {
      _hintReveal.forward(from: 0);
    }
    _lastHinted = hinted;
  }

  void _handleTap(int row, int col) {
    final result = widget.controller.launch(row, col);
    switch (result) {
      case LaunchOk(:final path, :final dir, :final from):
        final flight = _Flight(
          path: [from, ...path],
          dir: dir,
          controller: AnimationController(
            vsync: this,
            // Longer than the travel strictly needs, so the wind-up has room
            // to be felt before the arrow goes.
            duration: Duration(milliseconds: math.max(340, 58 * path.length)),
          ),
        );
        setState(() => _flights.add(flight));
        flight.controller.forward().whenComplete(() {
          flight.controller.dispose();
          if (mounted) setState(() => _flights.remove(flight));
        });

      case LaunchBlocked(:final from, :final blocker):
        final dir = widget.controller.board.topAt(from.row, from.col);
        if (dir == null) break;
        setState(() => _recoil = _Recoil(from: from, blocker: blocker, dir: dir));
        _reject.forward(from: 0).whenComplete(() {
          if (mounted) setState(() => _recoil = null);
        });

      case LaunchNothing():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.controller.board;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _Geometry.fit(
          Size(constraints.maxWidth, constraints.maxHeight),
          board.rows,
          board.cols,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final cell = geometry.cellAt(details.localPosition);
            if (cell != null) _handleTap(cell.row, cell.col);
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([
              widget.controller,
              _reject,
              _hintReveal,
              _pulse,
              ..._flights.map((f) => f.controller),
            ]),
            builder: (context, _) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _BoardPainter(
                board: board,
                geometry: geometry,
                flights: _flights,
                recoil: _recoil,
                rejectT: _reject.value,
                hinted: widget.controller.hinted,
                hintT: _hintReveal.value,
                pulseT: _pulse.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Maps between cells and pixels. The grid is invisible but still governs
/// layout, and the cell size shrinks as the board grows — which is what keeps
/// dense late levels on screen.
class _Geometry {
  const _Geometry({
    required this.origin,
    required this.cell,
    required this.rows,
    required this.cols,
  });

  factory _Geometry.fit(Size size, int rows, int cols) {
    final cell = math.min(size.width / cols, size.height / rows);
    final origin = Offset(
      (size.width - cell * cols) / 2,
      (size.height - cell * rows) / 2,
    );
    return _Geometry(origin: origin, cell: cell, rows: rows, cols: cols);
  }

  final Offset origin;
  final double cell;
  final int rows;
  final int cols;

  Offset centerOf(num row, num col) => Offset(
        origin.dx + (col + 0.5) * cell,
        origin.dy + (row + 0.5) * cell,
      );

  Cell? cellAt(Offset p) {
    final col = ((p.dx - origin.dx) / cell).floor();
    final row = ((p.dy - origin.dy) / cell).floor();
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return (row: row, col: col);
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.board,
    required this.geometry,
    required this.flights,
    required this.recoil,
    required this.rejectT,
    required this.hinted,
    required this.hintT,
    required this.pulseT,
  });

  final Board board;
  final _Geometry geometry;
  final List<_Flight> flights;
  final _Recoil? recoil;
  final double rejectT;
  final Cell? hinted;
  final double hintT;
  final double pulseT;

  /// Arrows are drawn at this fraction of a cell.
  static const double _glyphScale = 0.60;

  @override
  void paint(Canvas canvas, Size size) {
    for (var r = 0; r < board.rows; r++) {
      for (var c = 0; c < board.cols; c++) {
        final height = board.heightAt(r, c);
        if (height > 0) _paintCell(canvas, r, c, height);
      }
    }

    for (final flight in flights) {
      _paintFlight(canvas, flight);
    }

    if (recoil != null) _paintBlocker(canvas, recoil!);
    if (hinted != null && hintT > 0) _paintHintReveal(canvas, size);
  }

  void _paintCell(Canvas canvas, int row, int col, int height) {
    final dir = board.topAt(row, col)!;
    final s = geometry.cell * _glyphScale;
    var center = geometry.centerOf(row, col);

    // A blocked arrow lunges at the wall and springs back.
    var tint = Palette.arrow;
    final r = recoil;
    if (r != null && r.from.row == row && r.from.col == col) {
      final swing = math.sin(rejectT * math.pi) * (1 - rejectT * 0.35);
      center += Offset(
        r.dir.dc * swing * geometry.cell * 0.2,
        r.dir.dr * swing * geometry.cell * 0.2,
      );
      tint = Color.lerp(Palette.healthLow, Palette.arrow, rejectT)!;
    }

    // Ghosts behind convey stack depth. They copy the top arrow's silhouette
    // rather than the buried arrows' real facings, which stay hidden — the
    // numeral is what states the depth.
    for (var i = height - 1; i >= 1; i--) {
      final offset = geometry.cell * 0.05 * i;
      _paintArrow(
        canvas,
        center + Offset(offset, offset),
        s,
        dir,
        Palette.arrowGhost,
        1 - (i - 1) * 0.25,
      );
    }

    _paintArrow(canvas, center, s, dir, tint, 1);

    if (height > 1) _paintDepth(canvas, center, s, height);
  }

  /// Slow, then very fast.
  ///
  /// The opening dip draws the arrow back a touch before it goes. That tiny
  /// pause is what makes the release read as a release rather than a jump —
  /// without it the motion starts at full speed and looks abrupt.
  static double _launchCurve(double t) {
    const windUp = 0.17;
    if (t < windUp) {
      return -0.055 * math.sin(t / windUp * math.pi);
    }
    return Curves.easeInQuart.transform((t - windUp) / (1 - windUp));
  }

  void _paintFlight(Canvas canvas, _Flight flight) {
    final raw = flight.controller.value;
    final path = flight.path;
    final s = geometry.cell * _glyphScale;

    // A short trail sells the speed without a particle system.
    for (var i = 2; i >= 0; i--) {
      final lag = _launchCurve((raw - i * 0.05).clamp(0.0, 1.0));
      final center = _along(path, lag);
      final fade =
          (1 - raw * raw).clamp(0.0, 1.0) * (i == 0 ? 1.0 : 0.22 / i);
      if (fade <= 0.01) continue;
      _paintArrow(
        canvas,
        center,
        s * (1 - lag * 0.2),
        flight.dir,
        Palette.arrow,
        fade,
      );
    }
  }

  /// Position along a cell path at normalised progress [t].
  Offset _along(List<Cell> path, double t) {
    final pos = t * (path.length - 1);
    final i = pos.floor().clamp(0, path.length - 2);
    // Deliberately not clamped: a negative fraction extrapolates backwards,
    // which is how the wind-up pulls the arrow behind its starting cell.
    final frac = pos - i;
    return Offset.lerp(
      geometry.centerOf(path[i].row, path[i].col),
      geometry.centerOf(path[i + 1].row, path[i + 1].col),
      frac,
    )!;
  }

  /// Rings the arrow that stood in the way, so the rule teaches itself.
  void _paintBlocker(Canvas canvas, _Recoil r) {
    final center = geometry.centerOf(r.blocker.row, r.blocker.col);
    final fade = (1 - rejectT);
    canvas.drawCircle(
      center,
      geometry.cell * (0.34 + rejectT * 0.16),
      Paint()
        ..color = Palette.healthLow.withValues(alpha: fade * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.cell * 0.05 * fade,
    );
  }

  /// Dims the board, pops the hinted arrow, then lifts the dim away.
  void _paintHintReveal(Canvas canvas, Size size) {
    final cell = hinted!;
    final center = geometry.centerOf(cell.row, cell.col);
    final s = geometry.cell * _glyphScale;

    // Scrim rises over the first third and clears over the last third.
    final scrim = hintT < 0.35
        ? Curves.easeOut.transform(hintT / 0.35)
        : hintT > 0.7
            ? 1 - Curves.easeIn.transform((hintT - 0.7) / 0.3)
            : 1.0;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Palette.bg.withValues(alpha: scrim * 0.82),
    );

    // The arrow overshoots then settles.
    final popRaw = ((hintT - 0.22) / 0.5).clamp(0.0, 1.0);
    final pop = Curves.elasticOut.transform(popRaw);
    final scale = 1 + pop * 0.55 * (1 - hintT * 0.6);

    // Halo expands outward as it lands.
    if (popRaw > 0) {
      canvas.drawCircle(
        center,
        geometry.cell * (0.3 + popRaw * 0.35),
        Paint()
          ..color = Palette.hint.withValues(alpha: (1 - popRaw) * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.cell * 0.06,
      );
    }

    _paintArrow(
      canvas,
      center,
      s * scale,
      board.topAt(cell.row, cell.col) ?? Direction.right,
      Palette.hint,
      1,
    );

    // Once the reveal finishes, a slow ring keeps the arrow findable.
    if (hintT >= 1) {
      canvas.drawCircle(
        center,
        geometry.cell * (0.36 + pulseT * 0.05),
        Paint()
          ..color = Palette.hint.withValues(alpha: 0.25 + pulseT * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.cell * 0.035,
      );
    }
  }

  /// A thin stroked arrow, authored pointing right and rotated to [dir].
  void _paintArrow(
    Canvas canvas,
    Offset center,
    double s,
    Direction dir,
    Color color,
    double opacity,
  ) {
    if (opacity <= 0.01) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(dir.turns * 2 * math.pi);

    canvas.drawPath(
      buildArrowPath(s),
      Paint()
        ..color = color.withValues(alpha: color.a * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = arrowStroke(s)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _paintDepth(Canvas canvas, Offset center, double s, int height) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$height',
        style: TextStyle(
          color: Palette.arrow.withValues(alpha: 0.55),
          fontSize: s * 0.30,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center + Offset(-s * 0.44, -s * 0.46) - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
