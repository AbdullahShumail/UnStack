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
