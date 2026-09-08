import 'direction.dart';

typedef Cell = ({int row, int col});

/// One arrow: a head, a facing, and the tail lying behind it.
///
/// The tail is not decoration. Every cell of a body occupies the board and
/// blocks other arrows, so a long tail lying across the grid is an obstacle
/// that has to be cleared before the lanes it crosses open up.
class ArrowBody {
  const ArrowBody({
    required this.id,
    required this.dir,
    required this.cells,
  });

  final int id;
  final Direction dir;

  /// Head first, then each cell of the tail behind it.
  final List<Cell> cells;

  Cell get head => cells.first;
  int get length => cells.length;

  ArrowBody withId(int newId) =>
      ArrowBody(id: newId, dir: dir, cells: cells);
}

/// A grid of arrow bodies.
///
/// An arrow leaves by travelling from its head toward the edge along its
/// facing. The launch is legal only if every cell it would pass through is
/// free — of any arrow's body, not merely of other heads.
class Board {
  Board(this.rows, this.cols)
      : _owner = List<int>.filled(rows * cols, _empty, growable: false),
        _bodies = {};

  Board._(this.rows, this.cols, this._owner, this._bodies);

  static const int _empty = -1;

  final int rows;
  final int cols;

  /// Row-major cell ownership: the id of the arrow covering each cell.
  final List<int> _owner;
  final Map<int, ArrowBody> _bodies;

  int _index(int row, int col) => row * cols + col;

  bool contains(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  bool isEmptyAt(int row, int col) => _owner[_index(row, col)] == _empty;

  /// The arrow covering a cell, or null when the cell is free.
  ArrowBody? bodyAt(int row, int col) {
    final id = _owner[_index(row, col)];
    return id == _empty ? null : _bodies[id];
  }

  ArrowBody? bodyById(int id) => _bodies[id];

  Iterable<ArrowBody> get bodies => _bodies.values;

  int get arrowCount => _bodies.length;

  bool get isCleared => _bodies.isEmpty;

  /// Whether every cell of [body] is currently free.
  bool canPlace(ArrowBody body) {
    for (final c in body.cells) {
      if (!contains(c.row, c.col)) return false;
      if (!isEmptyAt(c.row, c.col)) return false;
    }
    return true;
  }

  void place(ArrowBody body) {
    _bodies[body.id] = body;
    for (final c in body.cells) {
      _owner[_index(c.row, c.col)] = body.id;
    }
  }

  ArrowBody remove(int id) {
    final body = _bodies.remove(id)!;
    for (final c in body.cells) {
      _owner[_index(c.row, c.col)] = _empty;
    }
    return body;
  }

  /// The cells an arrow at [head] facing [dir] would travel through, ending
  /// one step past the edge. Used both for the legality check and to animate
  /// the flight.
  List<Cell> exitPath(Cell head, Direction dir) {
    final path = <Cell>[];
    var r = head.row + dir.dr;
    var c = head.col + dir.dc;
    while (contains(r, c)) {
      path.add((row: r, col: c));
      r += dir.dr;
      c += dir.dc;
    }
    path.add((row: r, col: c)); // one step past the edge
    return path;
  }

  /// Whether the lane out of [head] along [dir] is clear of every body.
  ///
  /// [ignore] lets the generator test a lane before its own arrow is placed.
  bool hasClearExit(Cell head, Direction dir, {int? ignore}) {
    var r = head.row + dir.dr;
    var c = head.col + dir.dc;
    while (contains(r, c)) {
      final id = _owner[_index(r, c)];
      if (id != _empty && id != ignore) return false;
      r += dir.dr;
      c += dir.dc;
    }
    return true;
  }

  bool isLaunchable(int id) {
    final body = _bodies[id];
    if (body == null) return false;
    return hasClearExit(body.head, body.dir, ignore: id);
  }

  List<int> launchableIds() =>
      [for (final b in _bodies.values) if (isLaunchable(b.id)) b.id];

  Board clone() => Board._(
        rows,
        cols,
        List<int>.of(_owner, growable: false),
        Map<int, ArrowBody>.of(_bodies),
      );
}
