import 'direction.dart';

typedef Cell = ({int row, int col});

/// One cell of an arrow's lane, with the heading it was travelling on when it
/// entered. The heading changes at a mirror, and the flight animation needs
/// it to turn the glyph.
typedef LaneStep = ({int row, int col, Direction dir});

/// A grid of arrow stacks, with mirrors.
///
/// Each cell holds zero or more arrows. Only the arrow on top of a stack is
/// visible and only it can be launched; clearing it reveals the one beneath.
///
/// An arrow launches by travelling from its own cell toward the edge of the
/// board along its facing. The launch is legal only if every cell it passes
/// through is empty — a cell counts as occupied if it holds *any* arrow,
/// regardless of stack height.
///
/// A mirror is a fixed cell that never holds an arrow and never blocks one:
/// an arrow entering it leaves through a 90 degree turn and carries on. The
/// lane is therefore a bent path rather than a straight run, but the rule the
/// player reasons about is unchanged — is the lane clear or not.
class Board {
  Board(this.rows, this.cols)
      : _stacks = List.generate(rows * cols, (_) => <Direction>[],
            growable: false),
        _mirrors = List<Mirror?>.filled(rows * cols, null, growable: false);

  Board._(this.rows, this.cols, this._stacks, this._mirrors);

  final int rows;
  final int cols;

  /// Row-major cell stacks. The last element of a stack is the top arrow.
  final List<List<Direction>> _stacks;

  /// Row-major mirrors. A cell with a mirror holds no arrows.
  final List<Mirror?> _mirrors;

  int _index(int row, int col) => row * cols + col;

  bool contains(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  List<Direction> stackAt(int row, int col) => _stacks[_index(row, col)];

  int heightAt(int row, int col) => _stacks[_index(row, col)].length;

  bool isEmptyAt(int row, int col) => _stacks[_index(row, col)].isEmpty;

  Mirror? mirrorAt(int row, int col) => _mirrors[_index(row, col)];

  /// Whether an arrow may be placed here. Mirrors occupy their cell.
  bool canHoldArrow(int row, int col) => mirrorAt(row, col) == null;

  void setMirror(int row, int col, Mirror? mirror) {
    assert(
      mirror == null || isEmptyAt(row, col),
      'a mirror cannot share a cell with an arrow',
    );
    _mirrors[_index(row, col)] = mirror;
  }

  int get mirrorCount => _mirrors.where((m) => m != null).length;

  /// The visible arrow at [row], [col], or null when the cell is empty.
  Direction? topAt(int row, int col) {
    final stack = _stacks[_index(row, col)];
    return stack.isEmpty ? null : stack.last;
  }

  int get arrowCount {
    var total = 0;
    for (final stack in _stacks) {
      total += stack.length;
    }
    return total;
  }

  bool get isCleared => arrowCount == 0;

  void push(int row, int col, Direction dir) {
    assert(canHoldArrow(row, col), 'cannot stack an arrow on a mirror');
    _stacks[_index(row, col)].add(dir);
  }

  Direction pop(int row, int col) => _stacks[_index(row, col)].removeLast();

  /// Walks the lane an arrow at [row], [col] facing [dir] would take, calling
  /// [visit] for each cell entered. Stops early if [visit] returns false.
  ///
  /// Returns true if the walk reached the edge, false if it stopped early or
  /// went round in a circle. A circle is possible with two or more mirrors
  /// and is treated as no exit — the walk is capped at four passes over the
  /// board, which is the most any lane can make without repeating a state.
  ///
  /// [visit] is told when the lane has bent back into the origin cell. That
  /// cell is occupied by the very arrow being launched, and must read as
  /// blocked even when the board does not yet hold the arrow — which is the
  /// case while the generator is deciding whether to place it. Without this,
  /// an arrow whose lane loops home is placed with a "clear" lane and then
  /// blocks itself forever once it exists.
  bool _walk(
    int row,
    int col,
    Direction dir,
    bool Function(int r, int c, Direction heading, bool origin) visit,
  ) {
    var heading = dir;
    var r = row + heading.dr;
    var c = col + heading.dc;
    var budget = rows * cols * 4;
    while (contains(r, c)) {
      if (--budget < 0) return false;
      if (!visit(r, c, heading, r == row && c == col)) return false;
      final mirror = _mirrors[_index(r, c)];
      if (mirror != null) heading = mirror.bend(heading);
      r += heading.dr;
      c += heading.dc;
    }
    return true;
  }

  /// Whether an arrow sitting at [row], [col] and facing [dir] has an
  /// unobstructed run to the edge. The starting cell is not part of the path,
  /// so a tall stack never blocks its own top arrow.
  bool hasClearPath(int row, int col, Direction dir) =>
      _walk(row, col, dir, (r, c, _, origin) => !origin && isEmptyAt(r, c));

  /// The first occupied cell in the lane, or null if the lane is clear.
  Cell? firstBlocker(int row, int col, Direction dir) {
    Cell? blocker;
    _walk(row, col, dir, (r, c, _, origin) {
      if (!origin && isEmptyAt(r, c)) return true;
      blocker = (row: r, col: c);
      return false;
    });
    return blocker;
  }

  /// Whether the top arrow at [row], [col] can be launched right now.
  bool isLaunchable(int row, int col) {
    final dir = topAt(row, col);
    if (dir == null) return false;
    return hasClearPath(row, col, dir);
  }

  /// Every cell whose top arrow can currently be launched.
  List<Cell> launchableCells() {
    final result = <Cell>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (isLaunchable(r, c)) result.add((row: r, col: c));
      }
    }
    return result;
  }

  /// The cells an arrow at [row], [col] facing [dir] would travel through,
  /// each with the heading it was on when it arrived, ending one step past
  /// the edge. Used to animate the flight, bends included.
  List<LaneStep> pathFrom(int row, int col, Direction dir) {
    final path = <LaneStep>[];
    var last = (row: row, col: col, dir: dir);
    _walk(row, col, dir, (r, c, heading, _) {
      last = (row: r, col: c, dir: heading);
      path.add(last);
      return true;
    });
    // One step past the edge, on whatever heading the lane ended with. If the
    // lane bent inside its final cell, leave on the bent heading.
    final exit = mirrorAt(last.row, last.col)?.bend(last.dir) ?? last.dir;
    if (path.isEmpty) {
      // Launched from the edge facing out: the first step is already off.
      path.add((row: row + dir.dr, col: col + dir.dc, dir: dir));
    } else {
      path.add((
        row: last.row + exit.dr,
        col: last.col + exit.dc,
        dir: exit,
      ));
    }
    return path;
  }

  Board clone() => Board._(
        rows,
        cols,
        List.generate(rows * cols, (i) => List<Direction>.of(_stacks[i]),
            growable: false),
        List<Mirror?>.of(_mirrors, growable: false),
      );
}
