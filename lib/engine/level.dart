import 'board.dart';
import 'direction.dart';

/// A mirror fixed to a cell for the life of the level.
typedef MirrorPlacement = ({int row, int col, Mirror mirror});

/// A single arrow placed on the board.
class Placement {
  const Placement({required this.row, required this.col, required this.dir});

  final int row;
  final int col;
  final Direction dir;
}

/// How demanding a level is, measured by how much freedom the player has.
///
/// Because launching an arrow only ever frees space, a generated level can
/// never become unsolvable, and every solution takes exactly one move per
/// arrow. Difficulty therefore comes entirely from how *few* legal moves are
/// available at each step, not from move count or dead ends.
class DifficultyProfile {
  const DifficultyProfile({
    required this.arrowCount,
    required this.avgBranching,
    required this.avgOpenRatio,
    required this.tightSteps,
    required this.scoredSteps,
  });

  /// The tail of a solve is trivial by construction — the last arrow always
  /// has exactly one legal move — so those steps are excluded from the
  /// difficulty measures below.
  static const int trivialTail = 4;

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
  /// quantity the player actually experiences when scanning the board, and
  /// unlike a raw count it is comparable across board sizes.
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
    required this.placements,
    required this.profile,
    required this.seed,
    this.mirrors = const [],
  });

  final int rows;
  final int cols;
  final int seed;

  /// Arrows in the order the generator laid them down.
  final List<Placement> placements;

  /// Fixed for the whole level. Laid down before any arrow, so every arrow's
  /// lane was checked against the bends it will actually take.
  final List<MirrorPlacement> mirrors;

  final DifficultyProfile profile;

  /// A known-good solve order. Reversing the placement order works because an
  /// arrow was only ever placed while its own path was clear.
  List<Placement> get solutionOrder =>
      placements.reversed.toList(growable: false);

  Board toBoard() {
    final board = Board(rows, cols);
    for (final m in mirrors) {
      board.setMirror(m.row, m.col, m.mirror);
    }
    for (final p in placements) {
      board.push(p.row, p.col, p.dir);
    }
    return board;
  }
}
