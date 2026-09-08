import 'board.dart';

/// How demanding a level is, measured by how much freedom the player has.
///
/// Removing an arrow only ever frees cells, so a generated level can never
/// become unsolvable and every solution takes exactly one move per arrow.
/// Difficulty therefore comes entirely from how *few* arrows are launchable at
/// each step, not from move count or dead ends.
class DifficultyProfile {
  const DifficultyProfile({
    required this.arrowCount,
    required this.avgBranching,
    required this.avgOpenRatio,
    required this.tightSteps,
    required this.scoredSteps,
  });

  /// The tail of a solve is trivial by construction — the last arrow always
  /// has a clear lane — so those steps are excluded from the measures below.
  static const int trivialTail = 3;

  /// Where the open ratio realistically lands, measured across shipped board
  /// configs in tool/curve.dart. Used to normalise [score].
  static const double _hardRatio = 0.18;
  static const double _easyRatio = 0.90;

  /// Number of arrows, and therefore the number of moves in any solution.
  final int arrowCount;

  /// Mean number of launchable arrows across the solve. Informative, but it
  /// scales with board size, so it is not used for scoring.
  final double avgBranching;

  /// Mean fraction of the *remaining* arrows that were launchable. This is the
  /// quantity the player experiences when scanning the board, and unlike a raw
  /// count it is comparable across board sizes.
  final double avgOpenRatio;

  /// Non-trivial steps offering at most two legal moves.
  final int tightSteps;

  /// How many steps were counted, i.e. excluding the trivial tail.
  final int scoredSteps;

  /// Normalised 0..1 hardness, where 1 is most constrained.
  double get score {
    if (scoredSteps == 0) return 0;
    final openTerm =
        (1 - ((avgOpenRatio - _hardRatio) / (_easyRatio - _hardRatio)))
            .clamp(0.0, 1.0);
    final forcedTerm = tightSteps / scoredSteps;
    return (openTerm * 0.75 + forcedTerm * 0.25).clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'arrows=$arrowCount avg=${avgBranching.toStringAsFixed(2)} '
      'open=${avgOpenRatio.toStringAsFixed(3)} tight=$tightSteps/$scoredSteps '
      'score=${score.toStringAsFixed(2)}';
}

/// A generated, guaranteed-solvable puzzle.
class Level {
  const Level({
    required this.rows,
    required this.cols,
    required this.bodies,
    required this.profile,
    required this.seed,
  });

  final int rows;
  final int cols;
  final int seed;

  /// Arrows in the order the generator laid them down.
  final List<ArrowBody> bodies;

  final DifficultyProfile profile;

  /// A known-good solve order. Reversing the placement order works because an
  /// arrow was only ever placed while its own lane out was clear.
  List<ArrowBody> get solutionOrder => bodies.reversed.toList(growable: false);

  /// Total cells covered, which is what the board actually looks full of.
  int get coveredCells =>
      bodies.fold(0, (sum, b) => sum + b.length);

  Board toBoard() {
    final board = Board(rows, cols);
    for (final b in bodies) {
      board.place(b);
    }
    return board;
  }
}
