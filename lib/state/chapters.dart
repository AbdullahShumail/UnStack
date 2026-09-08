import 'dart:math';

import '../engine/generator.dart';
import '../engine/level.dart';

/// A run of levels, defined by how many arrows they hold rather than by a
/// fixed board shape.
class ChapterSpec {
  const ChapterSpec({
    required this.name,
    required this.startArrows,
    required this.endArrows,
    required this.maxStack,
    required this.startHardness,
    required this.endHardness,
    required this.levelCount,
  });

  final String name;

  /// Arrow count at the first and last level of the chapter. This is the only
  /// difficulty dial the player perceives directly: more arrows, denser board.
  final int startArrows;
  final int endArrows;

  final int maxStack;

  /// How constrained the solve is, on the measured scale in tool/curve.dart.
  final double startHardness;
  final double endHardness;

  final int levelCount;
}

/// The full progression.
///
/// Levels are never stored — a level index maps to a deterministic seed, and
/// the generator rebuilds the exact same board every time. That makes the
/// content effectively infinite at zero storage cost.
class Chapters {
  const Chapters._();

  /// Share of cells holding an arrow. Below this the board feels sparse and
  /// trivial; above it the generator starts running out of legal placements.
  static const double _occupancy = 0.55;

  /// Board sides we are willing to draw. The upper bound keeps arrows legible
  /// on a phone once they shrink to fit.
  static const int _minSide = 3;
  static const int _maxSide = 9;

  /// Rows per column. A square board on a tall phone is width-constrained and
  /// leaves big dead bands above and below, so boards are grown taller than
  /// they are wide to use the screen and keep arrows as large as possible.
  static const double _aspect = 1.45;

  static const List<ChapterSpec> all = [
    ChapterSpec(
      name: 'First Steps',
      startArrows: 5, endArrows: 11, maxStack: 1,
      startHardness: 0.0, endHardness: 0.45,
      levelCount: 12,
    ),
    ChapterSpec(
      name: 'Stacking Up',
      startArrows: 12, endArrows: 20, maxStack: 2,
      startHardness: 0.2, endHardness: 0.6,
      levelCount: 20,
    ),
    ChapterSpec(
      name: 'Deep Cuts',
      startArrows: 20, endArrows: 30, maxStack: 3,
      startHardness: 0.35, endHardness: 0.75,
      levelCount: 25,
    ),
    ChapterSpec(
      name: 'Gridlock',
      startArrows: 28, endArrows: 42, maxStack: 3,
      startHardness: 0.45, endHardness: 0.85,
      levelCount: 30,
    ),
    ChapterSpec(
      name: 'Tower Block',
      startArrows: 38, endArrows: 55, maxStack: 4,
      startHardness: 0.55, endHardness: 0.9,
      levelCount: 30,
    ),
    ChapterSpec(
      name: 'Endless',
      startArrows: 48, endArrows: 72, maxStack: 4,
      startHardness: 0.7, endHardness: 1.0,
      levelCount: 1 << 30,
    ),
  ];

  /// The board that comfortably holds [arrows] at [maxStack] deep.
  ///
  /// The board grows with the arrow count instead of being fixed per chapter,
  /// which is what lets arrows shrink to fit as levels get denser. It is also
  /// taller than it is wide, so a portrait screen is actually filled.
  static ({int rows, int cols}) gridFor(int arrows, int maxStack) {
    final cellsNeeded = arrows / maxStack / _occupancy;

    // Derive the shape from the aspect first, then grow it until it holds the
    // arrows. Rounding the column count (rather than ceiling it) matters: a
    // ceil here pushes small boards up a column and back into a square, which
    // is what left dead bands above and below the board on a tall screen.
    var cols = sqrt(cellsNeeded / _aspect).round().clamp(_minSide, _maxSide);
    var rows = (cols * _aspect).round().clamp(_minSide, _maxSide);

    while (cols * rows < cellsNeeded && rows < _maxSide) {
      rows++;
    }
    while (cols * rows < cellsNeeded && cols < _maxSide) {
      cols++;
    }
    return (rows: rows, cols: cols);
  }

  /// Which chapter a zero-based level index falls in, and how far through it.
  static ({ChapterSpec spec, int index, double t}) locate(int levelIndex) {
    var remaining = levelIndex;
    for (var i = 0; i < all.length; i++) {
      final spec = all[i];
      if (remaining < spec.levelCount) {
        // The endless chapter keeps ramping for its first 60 levels, then holds.
        final span = min(spec.levelCount, 60);
        final t = span <= 1 ? 1.0 : (remaining / (span - 1)).clamp(0.0, 1.0);
        return (spec: spec, index: i, t: t);
      }
      remaining -= spec.levelCount;
    }
    final last = all.last;
    return (spec: last, index: all.length - 1, t: 1.0);
  }

  /// How many arrows the level at [levelIndex] holds.
  static int arrowsFor(int levelIndex) {
    final at = locate(levelIndex);
    final spec = at.spec;
    return (spec.startArrows +
            (spec.endArrows - spec.startArrows) * at.t)
        .round();
  }

  /// Builds the level at [levelIndex]. Deterministic: same index, same board.
  static Level build(int levelIndex) {
    final at = locate(levelIndex);
    final spec = at.spec;
    final arrows = arrowsFor(levelIndex);
    final grid = gridFor(arrows, spec.maxStack);
    final hardness =
        spec.startHardness + (spec.endHardness - spec.startHardness) * at.t;
    return const LevelGenerator().generateTuned(
      rows: grid.rows,
      cols: grid.cols,
      targetArrows: arrows,
      maxStack: spec.maxStack,
      hardness: hardness,
      // Mixed so neighbouring levels look unrelated.
      seed: 0x9E3779B9 ^ (levelIndex * 2654435761),
    );
  }
}
