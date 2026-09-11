/// The four directions an arrow can face and travel.
///
/// [dc] is the column delta and [dr] the row delta of a single step, with the
/// origin at the top-left of the board.
enum Direction {
  up(0, -1),
  right(1, 0),
  down(0, 1),
  left(-1, 0);

  const Direction(this.dc, this.dr);

  final int dc;
  final int dr;

  /// Rotation applied to the arrow glyph, in turns. The glyph is authored
  /// pointing right, so [right] is the identity.
  double get turns => switch (this) {
        Direction.up => -0.25,
        Direction.right => 0.0,
        Direction.down => 0.25,
        Direction.left => 0.5,
      };

  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.right => Direction.left,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
      };
}

/// A deflector: a static cell that turns an arrow's lane through 90 degrees.
///
/// Named for the diagonal it draws. Think of the arrow bouncing off a mirror
/// laid along that line, with rows growing downward as on screen.
enum Mirror {
  /// Bottom-left to top-right. Right turns up, up turns right.
  slash,

  /// Top-left to bottom-right. Right turns down, down turns right.
  backslash;

  Direction bend(Direction incoming) => switch (this) {
        Mirror.slash => switch (incoming) {
            Direction.right => Direction.up,
            Direction.up => Direction.right,
            Direction.left => Direction.down,
            Direction.down => Direction.left,
          },
        Mirror.backslash => switch (incoming) {
            Direction.right => Direction.down,
            Direction.down => Direction.right,
            Direction.left => Direction.up,
            Direction.up => Direction.left,
          },
      };
}
