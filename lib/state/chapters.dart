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
    this.minMirrors = 0,
    this.maxMirrors = 0,
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

  /// Mirrors on the board, at the first and last level of the chapter.
  final int minMirrors;
  final int maxMirrors;
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
  static const double _occupancy = 0.66;

  /// Board sides we are willing to draw. The upper bound keeps arrows legible
  /// on a phone once they shrink to fit.
  static const int _minSide = 3;
  static const int _maxCols = 6;
  static const int _maxRows = 10;

  /// Rows per column. A square board on a tall phone is width-constrained and
  /// leaves big dead bands above and below, so boards are grown taller than
  /// they are wide to use the screen and keep arrows as large as possible.
  static const double _aspect = 1.45;

  static const List<ChapterSpec> all = [
    ChapterSpec(
      name: 'First Steps',
      startArrows: 10, endArrows: 20, maxStack: 2,
      startHardness: 0.3, endHardness: 0.65,
      levelCount: 10,
    ),
    ChapterSpec(
      name: 'Stacking Up',
      startArrows: 22, endArrows: 36, maxStack: 3,
      startHardness: 0.5, endHardness: 0.78,
      levelCount: 20,
    ),
    // Mirrors get a chapter to themselves. Arrow count is held back so the
    // new rule has room to be learned before it is combined with density.
    ChapterSpec(
      name: 'Mirrors',
      startArrows: 24, endArrows: 36, maxStack: 3,
      startHardness: 0.45, endHardness: 0.75,
      levelCount: 20,
      minMirrors: 1, maxMirrors: 3,
    ),
    ChapterSpec(
      name: 'Deep Cuts',
      startArrows: 38, endArrows: 55, maxStack: 4,
      startHardness: 0.62, endHardness: 0.86,
      levelCount: 25,
      minMirrors: 2, maxMirrors: 4,
    ),
    ChapterSpec(
      name: 'Gridlock',
      startArrows: 55, endArrows: 75, maxStack: 4,
      startHardness: 0.72, endHardness: 0.92,
      levelCount: 30,
      minMirrors: 3, maxMirrors: 5,
    ),
    ChapterSpec(
      name: 'Tower Block',
      startArrows: 75, endArrows: 100, maxStack: 5,
      startHardness: 0.8, endHardness: 0.95,
      levelCount: 35,
      minMirrors: 4, maxMirrors: 6,
    ),
    ChapterSpec(
      name: 'The Vault',
      startArrows: 95, endArrows: 135, maxStack: 5,
      startHardness: 0.88, endHardness: 1.0,
      levelCount: 40,
      minMirrors: 5, maxMirrors: 8,
    ),
    ChapterSpec(
      name: 'Endless',
      startArrows: 125, endArrows: 180, maxStack: 5,
      startHardness: 0.95, endHardness: 1.0,
      levelCount: 1 << 30,
      minMirrors: 6, maxMirrors: 10,
    ),
  ];

  /// The board that comfortably holds [arrows] at [maxStack] deep.
  ///
  /// The board grows with the arrow count instead of being fixed per chapter,
  /// which is what lets arrows shrink to fit as levels get denser. It is also
  /// taller than it is wide, so a portrait screen is actually filled.
  static ({int rows, int cols}) gridFor(int arrows, int maxStack,
      {int mirrors = 0}) {
    final cellsNeeded = arrows / maxStack / _occupancy + mirrors;

    // Derive the shape from the aspect first, then grow it until it holds the
    // arrows. Rounding the column count (rather than ceiling it) matters: a
    // ceil here pushes small boards up a column and back into a square, which
    // is what left dead bands above and below the board on a tall screen.
    var cols = sqrt(cellsNeeded / _aspect).round().clamp(_minSide, _maxCols);
    var rows = (cols * _aspect).round().clamp(_minSide, _maxRows);

    while (cols * rows < cellsNeeded && rows < _maxRows) {
      rows++;
    }
    while (cols * rows < cellsNeeded && cols < _maxCols) {
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

  /// How many mirrors the level at [levelIndex] holds.
  static int mirrorsFor(int levelIndex) {
    final at = locate(levelIndex);
    return (at.spec.minMirrors +
            (at.spec.maxMirrors - at.spec.minMirrors) * at.t)
        .round();
  }

  /// How many arrows the level at [levelIndex] holds.
  static int arrowsFor(int levelIndex) {
    final at = locate(levelIndex);
    final spec = at.spec;
    return (spec.startArrows +
            (spec.endArrows - spec.startArrows) * at.t)
        .round();
  }

  /// How often a surprise timed level turns up.
  static const int timedEvery = 6;

  /// The first level that may be timed. The opening run stays untimed so the
  /// rules are learned before the clock is introduced.
  static const int firstTimedLevel = 5;

  /// Whether the level at [levelIndex] runs against a clock.
  static bool isTimed(int levelIndex) =>
      levelIndex >= firstTimedLevel && (levelIndex + 1) % timedEvery == 0;

  /// Seconds allowed on a timed level: enough to solve it at a brisk pace,
  /// not enough to deliberate over every arrow.
  static int secondsFor(int levelIndex) {
    final arrows = arrowsFor(levelIndex);
    return (arrows * 1.15).round().clamp(20, 150);
  }

  /// Builds the level at [levelIndex]. Deterministic: same index, same board.
  static Level build(int levelIndex) {
    final at = locate(levelIndex);
    final spec = at.spec;
    final arrows = arrowsFor(levelIndex);
    final grid = gridFor(arrows, spec.maxStack, mirrors: mirrorsFor(levelIndex));
    final hardness =
        spec.startHardness + (spec.endHardness - spec.startHardness) * at.t;
    return const LevelGenerator().generateTuned(
      rows: grid.rows,
      cols: grid.cols,
      targetArrows: arrows,
      maxStack: spec.maxStack,
      hardness: hardness,
      mirrors: mirrorsFor(levelIndex),
      // Mixed so neighbouring levels look unrelated.
      seed: 0x9E3779B9 ^ (levelIndex * 2654435761),
    );
  }
}
