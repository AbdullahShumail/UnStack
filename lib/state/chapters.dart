import 'dart:math';

import '../engine/generator.dart';
import '../engine/level.dart';

/// A run of levels, defined by how many arrows they hold and how long those
/// arrows are.
class ChapterSpec {
  const ChapterSpec({
    required this.name,
    required this.startArrows,
    required this.endArrows,
    required this.minBody,
    required this.maxBody,
    required this.startHardness,
    required this.endHardness,
    required this.levelCount,
  });

  final String name;

  /// Arrow count at the first and last level of the chapter.
  final int startArrows;
  final int endArrows;

  /// How many cells an arrow's body covers. Longer bodies lie across more of
  /// the board, so they block more lanes and tangle harder.
  final int minBody;
  final int maxBody;

  /// How constrained the solve is, on the measured scale in tool/curve.dart.
  final double startHardness;
  final double endHardness;

  final int levelCount;

  double get avgBody => (minBody + maxBody) / 2;
}

/// The full progression.
///
/// Levels are never stored — a level index maps to a deterministic seed, and
/// the generator rebuilds the exact same board every time. That makes the
/// content effectively infinite at zero storage cost.
class Chapters {
  const Chapters._();

  /// Share of cells covered by arrow bodies. Bodies are long, so packing much
  /// tighter than this leaves the generator nowhere to lay one down.
  static const double _occupancy = 0.74;

  /// Board sides we are willing to draw. Columns are capped harder than rows:
  /// a phone is tall, and it is the column count that decides how small a cell
  /// gets. Past six columns the arrows stop being readable.
  static const int _minSide = 3;
  static const int _maxCols = 6;
  static const int _maxRows = 9;

  /// Rows per column. A square board on a tall phone is width-constrained and
  /// leaves dead bands above and below, so boards are grown taller than wide.
  static const double _aspect = 1.45;

  static const List<ChapterSpec> all = [
    ChapterSpec(
      name: 'First Steps',
      startArrows: 3, endArrows: 5,
      minBody: 1, maxBody: 2,
      startHardness: 0.0, endHardness: 0.4,
      levelCount: 12,
    ),
    ChapterSpec(
      name: 'Winding Up',
      startArrows: 4, endArrows: 6,
      minBody: 2, maxBody: 3,
      startHardness: 0.2, endHardness: 0.6,
      levelCount: 20,
    ),
    ChapterSpec(
      name: 'Tangled',
      startArrows: 5, endArrows: 7,
      minBody: 2, maxBody: 4,
      startHardness: 0.35, endHardness: 0.72,
      levelCount: 25,
    ),
    ChapterSpec(
      name: 'Gridlock',
      startArrows: 5, endArrows: 7,
      minBody: 3, maxBody: 4,
      startHardness: 0.45, endHardness: 0.82,
      levelCount: 30,
    ),
    ChapterSpec(
      name: 'Deep Weave',
      startArrows: 6, endArrows: 8,
      minBody: 3, maxBody: 5,
      startHardness: 0.55, endHardness: 0.9,
      levelCount: 30,
    ),
    ChapterSpec(
      name: 'Endless',
      startArrows: 6, endArrows: 9,
      minBody: 3, maxBody: 5,
      startHardness: 0.7, endHardness: 1.0,
      levelCount: 1 << 30,
    ),
  ];

  /// The board that comfortably holds [arrows] bodies of [avgBody] cells.
  ///
  /// The board grows with how much the arrows actually cover, which is what
  /// lets cells shrink to fit as levels get denser. It is also taller than it
  /// is wide, so a portrait screen is filled.
  static ({int rows, int cols}) gridFor(int arrows, double avgBody) {
    final cellsNeeded = arrows * avgBody / _occupancy;

    // Derive the shape from the aspect first, then grow it until it fits.
    // Rounding the column count (rather than ceiling it) matters: a ceil here
    // pushes small boards up a column and back into a square, which leaves
    // dead bands above and below on a tall screen.
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
        // The endless chapter keeps ramping for its first 60 levels then holds.
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
    return (at.spec.startArrows +
            (at.spec.endArrows - at.spec.startArrows) * at.t)
        .round();
  }

  /// Builds the level at [levelIndex]. Deterministic: same index, same board.
  static Level build(int levelIndex) {
    final at = locate(levelIndex);
    final spec = at.spec;
    final arrows = arrowsFor(levelIndex);
    final grid = gridFor(arrows, spec.avgBody);
    final hardness =
        spec.startHardness + (spec.endHardness - spec.startHardness) * at.t;
    return const LevelGenerator().generateTuned(
      rows: grid.rows,
      cols: grid.cols,
      targetArrows: arrows,
      minBody: spec.minBody,
      maxBody: spec.maxBody,
      hardness: hardness,
      // Mixed so neighbouring levels look unrelated.
      seed: 0x9E3779B9 ^ (levelIndex * 2654435761),
    );
  }
}
