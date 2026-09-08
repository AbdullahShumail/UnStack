import 'dart:math';

import '../../engine/board.dart';
import '../../engine/direction.dart';

/// Lanes per cell along each axis.
///
/// Routing on whole cells cannot work: a dense board leaves almost no empty
/// cell for a tail to enter, so most arrows end up with no tail while a lucky
/// few get long ones. Subdividing gives tails room to thread through the gaps
/// around arrows — which is exactly where the density in a woven lattice comes
/// from — while heads stay locked to cell centres.
const int lanesPerCell = 3;

typedef Lane = ({int lr, int lc});

/// One arrow's drawn shape: the lane its head sits in, then the lanes its tail
/// threads back through.
class ArrowRoute {
  const ArrowRoute({required this.dir, required this.lanes});

  final Direction dir;
  final List<Lane> lanes;
}

Direction _left(Direction d) => switch (d) {
      Direction.up => Direction.left,
      Direction.left => Direction.down,
      Direction.down => Direction.right,
      Direction.right => Direction.up,
    };

Direction _right(Direction d) => _left(_left(_left(d)));

/// Threads every arrow's tail through the lane grid, weaving around the others.
///
/// Invariants that exist for play rather than looks:
///
/// * No tail may enter the lane strip a head occupies, so a tail never draws
///   through an arrow.
/// * The first step back from a head is the exact opposite of its facing, so
///   the run into the head is square to the way it will travel and direction
///   stays readable at a glance.
///
/// Tails are drawn fading away from the head, because a tail crosses cells
/// that are *empty* — and an empty cell is still a clear lane. The fade is what
/// stops the lattice reading as occupancy.
Map<int, ArrowRoute> routeBoard(Board board, {int maxTail = 13}) {
  final laneRows = board.rows * lanesPerCell;
  final laneCols = board.cols * lanesPerCell;

  int laneKey(int lr, int lc) => lr * laneCols + lc;
  bool inBounds(int lr, int lc) =>
      lr >= 0 && lr < laneRows && lc >= 0 && lc < laneCols;

  /// The lane at the centre of a cell.
  Lane centreLane(int row, int col) => (
        lr: row * lanesPerCell + lanesPerCell ~/ 2,
        lc: col * lanesPerCell + lanesPerCell ~/ 2,
      );

  // Lanes no tail may use: the centre of every occupied cell and the lane its
  // head reaches into. Everything else around an arrow stays routable, which
  // is what lets tails weave past a crowded board.
  final blocked = <int>{};
  for (var r = 0; r < board.rows; r++) {
    for (var c = 0; c < board.cols; c++) {
      final dir = board.topAt(r, c);
      if (dir == null) continue;
      final centre = centreLane(r, c);
      blocked.add(laneKey(centre.lr, centre.lc));
      final front = (lr: centre.lr + dir.dr, lc: centre.lc + dir.dc);
      if (inBounds(front.lr, front.lc)) {
        blocked.add(laneKey(front.lr, front.lc));
      }
    }
  }

  final claimed = <int>{};
  final routes = <int, ArrowRoute>{};

  for (var r = 0; r < board.rows; r++) {
    for (var c = 0; c < board.cols; c++) {
      final dir = board.topAt(r, c);
      if (dir == null) continue;

      // Deterministic per cell and facing: the board repaints constantly for
      // the hint pulse, and a re-rolled lattice would shimmer while the player
      // is reading it.
      final rng =
          Random((r * 73856093) ^ (c * 19349663) ^ (dir.index * 83492791));

      final centre = centreLane(r, c);
      final lanes = <Lane>[centre];
      var cur = centre;
      var heading = dir.opposite;

      final target = 5 + rng.nextInt(maxTail - 4);

      for (var step = 0; step < target; step++) {
        // Long straight runs with occasional turns, like a routed trace.
        final turning = step > 0 && rng.nextInt(100) < 34;
        final options = <Direction>[
          if (!turning) heading,
          if (rng.nextBool()) ...[_left(heading), _right(heading)]
          else ...[_right(heading), _left(heading)],
          if (turning) heading,
        ];

        Lane? chosen;
        for (final option in options) {
          final nr = cur.lr + option.dr;
          final nc = cur.lc + option.dc;
          if (!inBounds(nr, nc)) continue;
          final k = laneKey(nr, nc);
          if (blocked.contains(k) || claimed.contains(k)) continue;
          chosen = (lr: nr, lc: nc);
          heading = option;
          break;
        }
        if (chosen == null) break;

        claimed.add(laneKey(chosen.lr, chosen.lc));
        lanes.add(chosen);
        cur = chosen;
      }

      routes[r * board.cols + c] = ArrowRoute(dir: dir, lanes: lanes);
    }
  }

  return routes;
}
