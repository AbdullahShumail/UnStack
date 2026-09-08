import 'dart:math';

import 'board.dart';
import 'direction.dart';
import 'level.dart';

/// Builds puzzles by running the game backwards.
///
/// Starting from an empty board, an arrow is laid down only when its lane out
/// to the edge is already clear. Replaying those placements in reverse is
/// therefore a valid solution: at the moment arrow *i* is removed, the only
/// arrows left are the ones placed before it, which is exactly the board state
/// its lane was checked against.
///
/// Because an arrow's whole body occupies the board, removing one frees every
/// cell it covered. Lanes only ever open up, so no sequence of legal moves can
/// strand the player.
class LevelGenerator {
  const LevelGenerator();

  /// Placement attempts per arrow before giving up on it.
  static const int _tries = 90;

  /// Candidate bodies scored per arrow when biasing for difficulty.
  static const int _sampleSize = 14;

  Level generate({
    required int rows,
    required int cols,
    required int targetArrows,
    required int minBody,
    required int maxBody,
    required double hardness,
    required int seed,
  }) {
    final rng = Random(seed);
    final board = Board(rows, cols);
    final placed = <ArrowBody>[];

    for (var i = 0; i < targetArrows; i++) {
      final candidates = <ArrowBody>[];
      for (var t = 0; t < _tries && candidates.length < _sampleSize; t++) {
        final body = _attempt(board, rng, placed.length, minBody, maxBody);
        if (body != null) candidates.add(body);
      }
      if (candidates.isEmpty) break; // board is saturated; ship what we have

      final chosen = _choose(board, candidates, hardness, rng);
      board.place(chosen);
      placed.add(chosen);
    }

    return Level(
      rows: rows,
      cols: cols,
      bodies: placed,
      profile: profileOf(rows, cols, placed),
      seed: seed,
    );
  }

  /// Generates several candidate levels and returns whichever lands closest to
  /// the requested [hardness].
  Level generateTuned({
    required int rows,
    required int cols,
    required int targetArrows,
    required int minBody,
    required int maxBody,
    required double hardness,
    required int seed,
    int attempts = 6,
  }) {
    Level? best;
    var bestDelta = double.infinity;
    for (var i = 0; i < attempts; i++) {
      final level = generate(
        rows: rows,
        cols: cols,
        targetArrows: targetArrows,
        minBody: minBody,
        maxBody: maxBody,
        hardness: hardness,
        seed: seed + i * 7919,
      );
      final shortfall = targetArrows == 0
          ? 0.0
          : (targetArrows - level.profile.arrowCount) / targetArrows;
      final delta = (level.profile.score - hardness).abs() + shortfall * 0.6;
      if (delta < bestDelta) {
        bestDelta = delta;
        best = level;
      }
    }
    return best!;
  }

  /// Tries to lay one arrow: a free head with a clear lane out, and a tail
  /// snaking back through free cells.
  ArrowBody? _attempt(
    Board board,
    Random rng,
    int id,
    int minBody,
    int maxBody,
  ) {
    final head = (row: rng.nextInt(board.rows), col: rng.nextInt(board.cols));
    if (!board.isEmptyAt(head.row, head.col)) return null;

    final dir = Direction.values[rng.nextInt(4)];
    if (!board.hasClearExit(head, dir)) return null;

    // The tail must not settle in the arrow's own lane, or it would block
    // itself the moment it is placed.
    final lane = <String>{
      for (final c in board.exitPath(head, dir)) '${c.row},${c.col}',
    };

    final cells = <Cell>[head];
    final taken = <String>{'${head.row},${head.col}'};
    var cur = head;
    // The first step back is the exact opposite of the facing, so the run into
    // the head always points true and direction stays readable.
    var heading = dir.opposite;

    final target = minBody + rng.nextInt(maxBody - minBody + 1);
    for (var step = 0; step < target - 1; step++) {
      // Long straight runs with the occasional turn, like a routed trace.
      final turning = step > 0 && rng.nextInt(100) < 38;
      final options = <Direction>[
        if (!turning) heading,
        if (rng.nextBool()) ...[_left(heading), _right(heading)]
        else ...[_right(heading), _left(heading)],
        if (turning) heading,
      ];

      Cell? next;
      for (final option in options) {
        final nr = cur.row + option.dr;
        final nc = cur.col + option.dc;
        if (!board.contains(nr, nc)) continue;
        if (!board.isEmptyAt(nr, nc)) continue;
        final key = '$nr,$nc';
        if (taken.contains(key) || lane.contains(key)) continue;
        next = (row: nr, col: nc);
        heading = option;
        break;
      }
      if (next == null) break;

      cells.add(next);
      taken.add('${next.row},${next.col}');
      cur = next;
    }

    if (cells.length < minBody) return null;
    return ArrowBody(id: id, dir: dir, cells: cells);
  }

  /// Picks a placement, biased by [hardness] toward boards that leave the
  /// player fewer legal moves.
  ArrowBody _choose(
    Board board,
    List<ArrowBody> candidates,
    double hardness,
    Random rng,
  ) {
    if (candidates.length == 1) return candidates.first;

    final scored = <({ArrowBody body, int branching})>[];
    for (final b in candidates) {
      board.place(b);
      scored.add((body: b, branching: board.launchableIds().length));
      board.remove(b.id);
    }
    scored.sort((a, b) => a.branching.compareTo(b.branching));

    // hardness 1 favours the front of the list (fewest moves), 0 the back.
    final target = ((1 - hardness) * (scored.length - 1)).round();
    final window = max(1, scored.length ~/ 4);
    final low = max(0, target - window);
    final high = min(scored.length - 1, target + window);
    return scored[low + rng.nextInt(high - low + 1)].body;
  }

  /// Replays the canonical solution to measure how constrained the solve is.
  static DifficultyProfile profileOf(
    int rows,
    int cols,
    List<ArrowBody> bodies,
  ) {
    final board = Board(rows, cols);
    for (final b in bodies) {
      board.place(b);
    }

    var total = 0;
    var openTotal = 0.0;
    var tightSteps = 0;
    var scoredSteps = 0;
    final steps = bodies.reversed.toList(growable: false);

    var remaining = steps.length;
    for (final b in steps) {
      final branching = board.launchableIds().length;
      total += branching;
      // Skip the endgame, where a shrinking board makes every move look forced.
      if (remaining > DifficultyProfile.trivialTail) {
        openTotal += branching / remaining;
        if (branching <= 2) tightSteps++;
        scoredSteps++;
      }
      board.remove(b.id);
      remaining--;
    }

    return DifficultyProfile(
      arrowCount: steps.length,
      avgBranching: steps.isEmpty ? 0 : total / steps.length,
      avgOpenRatio: scoredSteps == 0 ? 0 : openTotal / scoredSteps,
      tightSteps: tightSteps,
      scoredSteps: scoredSteps,
    );
  }
}

Direction _left(Direction d) => switch (d) {
      Direction.up => Direction.left,
      Direction.left => Direction.down,
      Direction.down => Direction.right,
      Direction.right => Direction.up,
    };

Direction _right(Direction d) => _left(_left(_left(d)));
