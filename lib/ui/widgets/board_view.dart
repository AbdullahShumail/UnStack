import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/board.dart';
import '../../state/game_controller.dart';
import '../../theme/palette.dart';

/// An arrow currently flying off the board.
class _Flight {
  _Flight({
    required this.body,
    required this.steps,
    required this.controller,
  });

  final ArrowBody body;

  /// How many cells the head travels before it clears the edge.
  final int steps;

  final AnimationController controller;
}

/// A blocked launch, animating its recoil.
class _Recoil {
  const _Recoil({required this.body, required this.blocker});

  final ArrowBody body;
  final Cell blocker;
}

/// Renders the board and owns every transient animation.
///
/// The board model updates synchronously on tap; flights and recoils are
/// overlays, so a fast tapper can never desync the two.
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

  /// Slow breathing glow left on the hinted arrow after the reveal.
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
      case LaunchOk(:final body, :final path):
        final flight = _Flight(
          body: body,
          steps: path.length,
          controller: AnimationController(
            vsync: this,
            duration: Duration(milliseconds: math.max(240, 46 * path.length)),
          ),
        );
        setState(() => _flights.add(flight));
        flight.controller.forward().whenComplete(() {
          flight.controller.dispose();
          if (mounted) setState(() => _flights.remove(flight));
        });

      case LaunchBlocked(:final body, :final blocker):
        setState(() => _recoil = _Recoil(body: body, blocker: blocker));
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
/// layout, and the cell size shrinks as the board grows.
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

  Offset centreOf(num row, num col) => Offset(
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

  double get _stroke => geometry.cell * 0.125;

  /// How far the head reaches past its cell centre.
  double get _reach => geometry.cell * 0.30;

  @override
  void paint(Canvas canvas, Size size) {
    for (final body in board.bodies) {
      final r = recoil;
      final blocked = r != null && r.body.id == body.id;
      _paintBody(
        canvas,
        body,
        colour: blocked
            ? Color.lerp(Palette.healthLow, Palette.arrow, rejectT)!
            : Palette.arrow,
        shift: blocked ? _lunge(body) : Offset.zero,
      );
    }

    for (final flight in flights) {
      _paintFlight(canvas, flight);
    }

    if (recoil != null) _paintBlocker(canvas, recoil!);
    if (hinted != null && hintT > 0) _paintHintReveal(canvas, size);
  }

  /// A blocked arrow lunges at whatever is in its way and springs back.
  Offset _lunge(ArrowBody body) {
    final swing = math.sin(rejectT * math.pi) * (1 - rejectT * 0.35);
    return Offset(
      body.dir.dc * swing * geometry.cell * 0.22,
      body.dir.dr * swing * geometry.cell * 0.22,
    );
  }

  /// The whole arrow: tail, shaft and head in one unbroken stroke.
  ///
  /// Every cell drawn here is a cell the arrow occupies and blocks. There is
  /// no dimming and no second weight, because there is nothing decorative in
  /// the shape — what you see is exactly what stands in the way.
  void _paintBody(
    Canvas canvas,
    ArrowBody body, {
    required Color colour,
    Offset shift = Offset.zero,
    double opacity = 1,
    double scale = 1,
  }) {
    final d = Offset(body.dir.dc.toDouble(), body.dir.dr.toDouble());
    final perp = Offset(-body.dir.dr.toDouble(), body.dir.dc.toDouble());

    // Walk the body from its far tail up to the head.
    final points = <Offset>[
      for (final c in body.cells.reversed) geometry.centreOf(c.row, c.col),
    ];
    // A single-cell arrow still needs a shaft to read as an arrow.
    if (points.length == 1) {
      points.insert(0, points.first - d * geometry.cell * 0.34);
    }
    final tip = points.last + d * _reach;
    points.add(tip);

    final centre = points.last;
    canvas.save();
    canvas.translate(shift.dx, shift.dy);
    if (scale != 1) {
      canvas.translate(centre.dx, centre.dy);
      canvas.scale(scale);
      canvas.translate(-centre.dx, -centre.dy);
    }

    final paint = Paint()
      ..color = colour.withValues(alpha: colour.a * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final barb = geometry.cell * 0.23;
    path
      ..moveTo(tip.dx - d.dx * barb + perp.dx * barb * 0.8,
          tip.dy - d.dy * barb + perp.dy * barb * 0.8)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - d.dx * barb - perp.dx * barb * 0.8,
          tip.dy - d.dy * barb - perp.dy * barb * 0.8);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// A launched arrow slides out along its lane, whole.
  void _paintFlight(Canvas canvas, _Flight flight) {
    final t = Curves.easeInCubic.transform(flight.controller.value);
    final d = Offset(
      flight.body.dir.dc.toDouble(),
      flight.body.dir.dr.toDouble(),
    );
    final travel = d * (t * flight.steps * geometry.cell);
    _paintBody(
      canvas,
      flight.body,
      colour: Palette.arrow,
      shift: travel,
      opacity: (1 - t * t).clamp(0.0, 1.0),
    );
  }

  /// Rings the cell that stood in the way, so the rule teaches itself.
  void _paintBlocker(Canvas canvas, _Recoil r) {
    final centre = geometry.centreOf(r.blocker.row, r.blocker.col);
    final fade = 1 - rejectT;
    canvas.drawCircle(
      centre,
      geometry.cell * (0.36 + rejectT * 0.16),
      Paint()
        ..color = Palette.healthLow.withValues(alpha: fade * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.cell * 0.06 * fade,
    );
  }

  /// Dims the board, pops the hinted arrow, then lifts the dim away.
  void _paintHintReveal(Canvas canvas, Size size) {
    final body = board.bodyAt(hinted!.row, hinted!.col);
    if (body == null) return;
    final centre = geometry.centreOf(hinted!.row, hinted!.col);

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

    if (popRaw > 0) {
      canvas.drawCircle(
        centre,
        geometry.cell * (0.3 + popRaw * 0.4),
        Paint()
          ..color = Palette.hint.withValues(alpha: (1 - popRaw) * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.cell * 0.06,
      );
    }

    _paintBody(
      canvas,
      body,
      colour: Palette.hint,
      scale: 1 + pop * 0.16 * (1 - hintT * 0.5),
    );

    if (hintT >= 1) {
      canvas.drawCircle(
        centre,
        geometry.cell * (0.4 + pulseT * 0.06),
        Paint()
          ..color = Palette.hint.withValues(alpha: 0.2 + pulseT * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.cell * 0.04,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
