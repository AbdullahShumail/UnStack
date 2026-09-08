import 'direction.dart';

/// A grid of arrow stacks.
///
/// Each cell holds zero or more arrows. Only the arrow on top of a stack is
/// visible and only it can be launched; clearing it reveals the one beneath.
///
/// An arrow launches by travelling from its own cell toward the edge of the
/// board along its facing. The launch is legal only if every cell it passes
/// through is empty — a cell counts as occupied if it holds *any* arrow,
/// regardless of stack height.
class Board {
  Board(this.rows, this.cols)
      : _stacks = List.generate(rows * cols, (_) => <Direction>[], growable: false);

  Board._(this.rows, this.cols, this._stacks);

  final int rows;
  final int cols;

  /// Row-major cell stacks. The last element of a stack is the top arrow.
  final List<List<Direction>> _stacks;

  int _index(int row, int col) => row * cols + col;

  bool contains(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  List<Direction> stackAt(int row, int col) => _stacks[_index(row, col)];

  int heightAt(int row, int col) => _stacks[_index(row, col)].length;

  bool isEmptyAt(int row, int col) => _stacks[_index(row, col)].isEmpty;

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

  void push(int row, int col, Direction dir) =>
      _stacks[_index(row, col)].add(dir);

  Direction pop(int row, int col) => _stacks[_index(row, col)].removeLast();

  /// Whether an arrow sitting at [row], [col] and facing [dir] has an
  /// unobstructed run to the edge. The starting cell is not part of the path,
  /// so a tall stack never blocks its own top arrow.
  bool hasClearPath(int row, int col, Direction dir) {
    var r = row + dir.dr;
    var c = col + dir.dc;
    while (contains(r, c)) {
      if (!isEmptyAt(r, c)) return false;
      r += dir.dr;
      c += dir.dc;
    }
    return true;
  }

  /// Whether the top arrow at [row], [col] can be launched right now.
  bool isLaunchable(int row, int col) {
    final dir = topAt(row, col);
    if (dir == null) return false;
    return hasClearPath(row, col, dir);
  }

  /// Every cell whose top arrow can currently be launched.
  List<({int row, int col})> launchableCells() {
    final result = <({int row, int col})>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (isLaunchable(r, c)) result.add((row: r, col: c));
      }
    }
    return result;
  }

  /// The cells an arrow at [row], [col] facing [dir] would travel through,
  /// ending just off the board. Used to animate the flight.
  List<({int row, int col})> pathFrom(int row, int col, Direction dir) {
    final path = <({int row, int col})>[];
    var r = row + dir.dr;
    var c = col + dir.dc;
    while (contains(r, c)) {
      path.add((row: r, col: c));
      r += dir.dr;
      c += dir.dc;
    }
    path.add((row: r, col: c)); // one step past the edge
    return path;
  }

  Board clone() => Board._(
        rows,
        cols,
        List.generate(rows * cols, (i) => List<Direction>.of(_stacks[i]),
            growable: false),
      );
}
