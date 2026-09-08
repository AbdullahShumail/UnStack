import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/board.dart';
import '../../engine/direction.dart';
import '../../state/game_controller.dart';
import '../../theme/palette.dart';
import 'arrow_glyph.dart';
import 'arrow_routing.dart';

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
            duration: Duration(milliseconds: math.max(230, 52 * path.length)),
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
    // Recomputed when the board changes rather than per frame: the lattice
    // reflows into space an departing arrow frees up.
    final routes = routeBoard(board);

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
                routes: routes,
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

  /// Centre of a lane on the finer routing grid.
  Offset laneCentre(int lr, int lc) => Offset(
        origin.dx + (lc + 0.5) * cell / lanesPerCell,
        origin.dy + (lr + 0.5) * cell / lanesPerCell,
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
    required this.routes,
    required this.geometry,
    required this.flights,
    required this.recoil,
    required this.rejectT,
    required this.hinted,
    required this.hintT,
    required this.pulseT,
  });

  final Board board;
  final Map<int, ArrowRoute> routes;
  final _Geometry geometry;
  final List<_Flight> flights;
  final _Recoil? recoil;
  final double rejectT;
  final Cell? hinted;
  final double hintT;
  final double pulseT;

  double get _stroke => geometry.cell * 0.105;

  /// How far the head reaches past its cell centre.
  double get _reach => geometry.cell * 0.24;

  @override
  void paint(Canvas canvas, Size size) {
    // Tails first, so no tail is ever drawn over a head.
    for (final entry in routes.entries) {
      _paintTail(canvas, entry.key, entry.value);
    }
    for (final entry in routes.entries) {
      _paintHead(canvas, entry.key, entry.value);
    }

    for (final flight in flights) {
      _paintFlight(canvas, flight);
    }

    if (recoil != null) _paintBlocker(canvas, recoil!);
    if (hinted != null && hintT > 0) _paintHintReveal(canvas, size);
  }

  Cell _cellOf(int key) =>
      (row: key ~/ geometry.cols, col: key % geometry.cols);

  /// Nudge applied while a blocked arrow lunges at the wall and springs back.
  Offset _shiftFor(Cell cell) {
    final r = recoil;
    if (r == null || r.from.row != cell.row || r.from.col != cell.col) {
      return Offset.zero;
    }
    final swing = math.sin(rejectT * math.pi) * (1 - rejectT * 0.35);
    return Offset(
      r.dir.dc * swing * geometry.cell * 0.2,
      r.dir.dr * swing * geometry.cell * 0.2,
    );
  }

  Color _tintFor(Cell cell) {
    final r = recoil;
    if (r == null || r.from.row != cell.row || r.from.col != cell.col) {
      return Palette.arrow;
    }
    return Color.lerp(Palette.healthLow, Palette.arrow, rejectT)!;
  }

  /// The tail threading back from a head, fading as it goes.
  ///
  /// The fade is not decoration: a tail runs through empty cells, and an empty
  /// cell is still a clear lane. Dimming it keeps the lattice from reading as
  /// occupancy.
  void _paintTail(Canvas canvas, int key, ArrowRoute route) {
    if (route.lanes.length < 2) return;
    final head = _cellOf(key);
    final shift = _shiftFor(head);
    final tint = _tintFor(head);

    final points = [
      for (final l in route.lanes) geometry.laneCentre(l.lr, l.lc) + shift,
    ];

    // One continuous path, stroked once. Drawing segment by segment with a
    // per-segment alpha makes the round caps overlap at every joint and the
    // tail comes out beaded like a string of pearls.
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = tint.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke * 0.82
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// The bright end of an arrow: the run into its head, and the head itself.
  void _paintHead(Canvas canvas, int key, ArrowRoute route) {
    final cell = _cellOf(key);
    final height = board.heightAt(cell.row, cell.col);
    final shift = _shiftFor(cell);
    final tint = _tintFor(cell);
    final centre = geometry.centerOf(cell.row, cell.col) + shift;
    final dir = route.dir;

    // Depth ghost, offset behind. It repeats the head's silhouette only — the
    // facings underneath stay hidden, and the numeral states the count.
    if (height > 1) {
      final off = Offset(geometry.cell * 0.06, geometry.cell * 0.06);
      _drawHead(canvas, centre + off, dir, Palette.arrowGhost, 1);
    }

    _drawHead(canvas, centre, dir, tint, 1);
    if (height > 1) _paintDepth(canvas, centre, height);
  }

  void _drawHead(
    Canvas canvas,
    Offset centre,
    Direction dir,
    Color color,
    double opacity,
  ) {
    final d = Offset(dir.dc.toDouble(), dir.dr.toDouble());
    final perp = Offset(-dir.dr.toDouble(), dir.dc.toDouble());
    final tip = centre + d * _reach;
    final barb = geometry.cell * 0.20;

    final paint = Paint()
      ..color = color.withValues(alpha: color.a * opacity)
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // The straight run into the head, always square to the way it will travel.
    canvas.drawLine(centre - d * geometry.cell * 0.5, tip, paint);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - d.dx * barb + perp.dx * barb * 0.78,
            tip.dy - d.dy * barb + perp.dy * barb * 0.78)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - d.dx * barb - perp.dx * barb * 0.78,
            tip.dy - d.dy * barb - perp.dy * barb * 0.78),
      paint,
    );
  }

  /// A launched arrow pulls free of the lattice and runs straight out.
  void _paintFlight(Canvas canvas, _Flight flight) {
    final raw = flight.controller.value;
    final t = Curves.easeInCubic.transform(raw);
    final path = flight.path;
    final s = geometry.cell * 0.72;

    for (var i = 2; i >= 0; i--) {
      final lag = (t - i * 0.06).clamp(0.0, 1.0);
      final centre = _along(path, lag);
      final fade = (1 - lag * lag) * (i == 0 ? 1.0 : 0.22 / i);
      if (fade <= 0.01) continue;

      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(flight.dir.turns * 2 * math.pi);
      canvas.drawPath(
        buildArrowPath(s * (1 - lag * 0.2)),
        Paint()
          ..color = Palette.arrow.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }
  }

  /// Position along a cell path at normalised progress [t].
  Offset _along(List<Cell> path, double t) {
    final pos = t * (path.length - 1);
    final i = pos.floor().clamp(0, path.length - 2);
    final frac = pos - i;
    return Offset.lerp(
      geometry.centerOf(path[i].row, path[i].col),
      geometry.centerOf(path[i + 1].row, path[i + 1].col),
      frac,
    )!;
  }

  /// Rings the arrow that stood in the way, so the rule teaches itself.
  void _paintBlocker(Canvas canvas, _Recoil r) {
    final centre = geometry.centerOf(r.blocker.row, r.blocker.col);
    final fade = 1 - rejectT;
    canvas.drawCircle(
      centre,
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
    final centre = geometry.centerOf(cell.row, cell.col);

    final scrim = hintT < 0.35
        ? Curves.easeOut.transform(hintT / 0.35)
        : hintT > 0.7
            ? 1 - Curves.easeIn.transform((hintT - 0.7) / 0.3)
            : 1.0;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Palette.bg.withValues(alpha: scrim * 0.82),
    );

    final popRaw = ((hintT - 0.22) / 0.5).clamp(0.0, 1.0);
    final pop = Curves.elasticOut.transform(popRaw);
    final scale = 1 + pop * 0.4 * (1 - hintT * 0.6);

    if (popRaw > 0) {
      canvas.drawCircle(
        centre,
        geometry.cell * (0.3 + popRaw * 0.35),
        Paint()
          ..color = Palette.hint.withValues(alpha: (1 - popRaw) * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.cell * 0.06,
      );
    }

    final dir = board.topAt(cell.row, cell.col) ?? Direction.right;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(scale);
    canvas.translate(-centre.dx, -centre.dy);
    _drawHead(canvas, centre, dir, Palette.hint, 1);
    canvas.restore();

    if (hintT >= 1) {
      canvas.drawCircle(
        centre,
        geometry.cell * (0.36 + pulseT * 0.05),
        Paint()
          ..color = Palette.hint.withValues(alpha: 0.25 + pulseT * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.cell * 0.035,
      );
    }
  }

  void _paintDepth(Canvas canvas, Offset centre, int height) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$height',
        style: TextStyle(
          fontFamily: Palette.family,
          color: Palette.arrow.withValues(alpha: 0.55),
          fontSize: geometry.cell * 0.19,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      centre +
          Offset(-geometry.cell * 0.34, -geometry.cell * 0.34) -
          Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
