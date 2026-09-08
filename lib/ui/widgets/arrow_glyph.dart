import 'dart:math';
import 'dart:ui';

/// The plain arrow: one straight shaft into a small head.
///
/// Authored pointing right, centred on the origin, inside a box of side [s].
/// Used where the glyph is too small for routing to read — the health bar and
/// the wordmark.
Path buildArrowPath(double s) => Path()
  ..moveTo(-s * 0.52, 0)
  ..lineTo(s * 0.22, 0)
  ..moveTo(s * 0.03, -s * 0.19)
  ..lineTo(s * 0.35, 0)
  ..lineTo(s * 0.03, s * 0.19);

/// Line weight that keeps a glyph legible at any size.
double arrowStroke(double s) => s * 0.10;

/// A stable seed for the arrow at a given cell and facing.
///
/// Routing must be deterministic: an arrow that re-rolled its shape every
/// frame would shimmer, and one that re-rolled on rebuild would look unstable
/// while the player is reading the board.
int routeSeed(int row, int col, int dirIndex) =>
    ((row * 73856093) ^ (col * 19349663) ^ (dirIndex * 83492791)) & 0x7fffffff;

/// A winding arrow: an orthogonal route with rounded corners, ending in a
/// straight run into the head.
///
/// [straightness] morphs the route toward a plain straight arrow. At 0 the
/// tail is fully coiled; at 1 it has unwound. Launching animates this, so the
/// coil reads as stored energy released when the arrow flies.
///
/// The run into the head is never routed. Direction is the one thing the
/// player must read instantly, so the last stretch always points true.
Path buildRoutedArrowPath({
  required double s,
  required int seed,
  double straightness = 0,
  int turns = 3,
}) {
  final points = _route(s, seed, turns);

  // Distance back from the tip to each point, used to lay the straightened
  // version out along the axis with the same spacing.
  final cumulative = <double>[0];
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += (points[i] - points[i - 1]).distance;
    cumulative.add(total);
  }

  const straightLength = 0.86;
  final t = straightness.clamp(0.0, 1.0);
  final tip = points.first;

  final path = Path();
  for (var i = 0; i < points.length; i++) {
    final straight = Offset(
      tip.dx - (total == 0 ? 0 : cumulative[i] / total) * s * straightLength,
      0,
    );
    final p = Offset.lerp(points[i], straight, t)!;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }

  // Head last, always square to the direction of travel.
  final barb = s * 0.155;
  path
    ..moveTo(tip.dx - barb, -barb * 0.82)
    ..lineTo(tip.dx, 0)
    ..lineTo(tip.dx - barb, barb * 0.82);

  return path;
}

/// Walks backwards from the head, alternating across and along, to lay out an
/// orthogonal route inside the glyph box.
List<Offset> _route(double s, int seed, int turns) {
  final rng = Random(seed);

  final tipX = s * 0.40;
  // The straight approach the head sits on. Long enough to read as a
  // direction on its own, before any wandering starts.
  final approachX = s * 0.10;
  final minX = -s * 0.46;

  final points = <Offset>[Offset(tipX, 0), Offset(approachX, 0)];

  var x = approachX;
  var side = rng.nextBool() ? 1.0 : -1.0;
  final span = approachX - minX;

  for (var i = 0; i < turns; i++) {
    // Across.
    final amp = s * (0.13 + rng.nextDouble() * 0.19);
    final y = side * amp;
    points.add(Offset(x, y));

    // Along. The last leg always lands on the back wall so routes of
    // different shapes still read as the same length arrow.
    final remaining = turns - i;
    final step = i == turns - 1
        ? x - minX
        : (span / turns) * (0.65 + rng.nextDouble() * 0.7);
    x = (x - step).clamp(minX, approachX);
    if (remaining == 1) x = minX;

    points.add(Offset(x, y));
    side = -side;
  }

  return points;
}
