import 'dart:math';

import 'board.dart';
import 'direction.dart';
import 'level.dart';

/// Builds puzzles by running the game backwards.
///
/// Starting from an empty board, an arrow is added only when its path to the
/// edge is already clear. Replaying those placements in reverse is therefore a
/// valid solution: at the moment arrow *i* is removed, the only arrows left on
/// the board are the ones placed before it, which is exactly the state its
/// path was checked against.
///
/// Stacking comes for free. Pushing an arrow onto an occupied cell means it is
/// removed *earlier* in the forward game, so it is always on top when its turn
/// comes.
class LevelGenerator {
  const LevelGenerator();

  /// How many candidate placements to evaluate per arrow. Higher values give
  /// the hardness bias more to work with, at linear cost.
  static const int _sampleSize = 36;

  Level generate({
    required int rows,
    required int cols,
    required int targetArrows,
    required int maxStack,
    required double hardness,
    required int seed,
    int mirrors = 0,
  }) {
    final rng = Random(seed);
    final board = Board(rows, cols);
    final placements = <Placement>[];

    // Mirrors go down first and never move. Every arrow placed afterwards has
    // its lane checked against the bends, so the reverse-order solution
    // remains valid: the board an arrow is removed against is exactly the
    // board it was placed against, mirrors included.
    final laid = _layMirrors(board, mirrors, rng);

    for (var i = 0; i < targetArrows; i++) {
      final candidates = _candidates(board, maxStack, rng);
      if (candidates.isEmpty) break; // board is saturated; ship what we have
      final chosen = _choose(board, candidates, hardness, rng);
      board.push(chosen.row, chosen.col, chosen.dir);
      placements.add(chosen);
    }

    return Level(
      rows: rows,
      cols: cols,
      placements: placements,
      mirrors: laid,
      profile: profileOf(rows, cols, placements, mirrors: laid),
      seed: seed,
    );
  }

  /// Scatters [count] mirrors on cells that leave the board still workable.
  ///
  /// Mirrors on the outer ring are avoided: a mirror in a corner can only be
  /// hit from two sides and mostly just costs a cell, while one in the
  /// interior can turn lanes coming from all four directions.
  List<MirrorPlacement> _layMirrors(Board board, int count, Random rng) {
    final laid = <MirrorPlacement>[];
    if (count <= 0) return laid;

    final interior = <Cell>[
      for (var r = 1; r < board.rows - 1; r++)
        for (var c = 1; c < board.cols - 1; c++) (row: r, col: c),
    ];
    final pool = interior.isEmpty
        ? <Cell>[
            for (var r = 0; r < board.rows; r++)
              for (var c = 0; c < board.cols; c++) (row: r, col: c),
          ]
        : interior;
    pool.shuffle(rng);

    for (final cell in pool.take(count)) {
      final mirror = rng.nextBool() ? Mirror.slash : Mirror.backslash;
      board.setMirror(cell.row, cell.col, mirror);
      laid.add((row: cell.row, col: cell.col, mirror: mirror));
    }
    return laid;
  }

  /// Generates several candidate levels and returns whichever lands closest to
  /// the requested [hardness].
  Level generateTuned({
    required int rows,
    required int cols,
    required int targetArrows,
    required int maxStack,
    required double hardness,
    required int seed,
    int mirrors = 0,
    int attempts = 8,
  }) {
    Level? best;
    var bestDelta = double.infinity;
    for (var i = 0; i < attempts; i++) {
      final level = generate(
        rows: rows,
        cols: cols,
        targetArrows: targetArrows,
        maxStack: maxStack,
        hardness: hardness,
        seed: seed + i * 7919,
        mirrors: mirrors,
      );
      // A level that came up short on arrows is a poor fit however it feels.
      final shortfall =
          targetArrows == 0 ? 0.0 : (targetArrows - level.profile.arrowCount) / targetArrows;
      final delta = (level.profile.score - hardness).abs() + shortfall * 0.5;
      if (delta < bestDelta) {
        bestDelta = delta;
        best = level;
      }
    }
    return best!;
  }

  /// Every legal placement, sampled down to [_sampleSize] for speed.
  ///
  /// When the board has mirrors, placements whose lane actually bends are
  /// reserved half the sample. Left to chance most lanes miss the mirrors,
  /// and a mirror nobody's lane crosses is nothing but a dead cell.
  List<Placement> _candidates(Board board, int maxStack, Random rng) {
    final bent = <Placement>[];
    final straight = <Placement>[];
    for (var r = 0; r < board.rows; r++) {
      for (var c = 0; c < board.cols; c++) {
        if (!board.canHoldArrow(r, c)) continue;
        if (board.heightAt(r, c) >= maxStack) continue;
        for (final dir in Direction.values) {
          if (!board.hasClearPath(r, c, dir)) continue;
          final p = Placement(row: r, col: c, dir: dir);
          (_laneBends(board, p) ? bent : straight).add(p);
        }
      }
    }
    if (bent.length + straight.length <= _sampleSize) return [...bent, ...straight];

    bent.shuffle(rng);
    straight.shuffle(rng);
    final fromBent = min(bent.length, _sampleSize ~/ 2);
    final fromStraight = min(straight.length, _sampleSize - fromBent);
    return [...bent.take(fromBent), ...straight.take(fromStraight)];
  }

  bool _laneBends(Board board, Placement p) =>
      board.pathFrom(p.row, p.col, p.dir).any((s) => s.dir != p.dir);

  /// Picks a placement, biased by [hardness] toward boards that leave the
  /// player fewer legal moves.
  Placement _choose(
    Board board,
    List<Placement> candidates,
    double hardness,
    Random rng,
  ) {
    if (candidates.length == 1) return candidates.first;

    final scored = <({Placement placement, int branching})>[];
    for (final p in candidates) {
      board.push(p.row, p.col, p.dir);
      scored.add((placement: p, branching: board.launchableCells().length));
      board.pop(p.row, p.col);
    }
    scored.sort((a, b) => a.branching.compareTo(b.branching));

    // hardness 1 favours the front of the list (fewest moves), 0 the back.
    final target = ((1 - hardness) * (scored.length - 1)).round();
    // Keep a jitter window so repeated seeds still produce distinct boards.
    final window = max(1, scored.length ~/ 6);
    final low = max(0, target - window);
    final high = min(scored.length - 1, target + window);
    return scored[low + rng.nextInt(high - low + 1)].placement;
  }

  /// Replays the canonical solution to measure how constrained the solve is.
  static DifficultyProfile profileOf(
    int rows,
    int cols,
    List<Placement> placements, {
    List<MirrorPlacement> mirrors = const [],
  }) {
    final board = Board(rows, cols);
    for (final m in mirrors) {
      board.setMirror(m.row, m.col, m.mirror);
    }
    for (final p in placements) {
      board.push(p.row, p.col, p.dir);
    }

    var total = 0;
    var openTotal = 0.0;
    var tightSteps = 0;
    var scoredSteps = 0;
    final steps = placements.reversed.toList(growable: false);

    var remaining = steps.length;
    for (final p in steps) {
      final branching = board.launchableCells().length;
      total += branching;
      // Skip the endgame, where a shrinking board makes every move look forced.
      if (remaining > DifficultyProfile.trivialTail) {
        openTotal += branching / remaining;
        if (branching <= 2) tightSteps++;
        scoredSteps++;
      }
      board.pop(p.row, p.col);
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
