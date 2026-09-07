import 'dart:ui';

/// The single arrow shape used by the board, the health bar and the hero.
///
/// Authored pointing right, centred on the origin, inside a box of side [s].
/// The tail runs long and the head sits small and tight — the glyph reads as a
/// drawn line rather than a filled icon, which is what keeps dense boards calm.
Path buildArrowPath(double s) => Path()
  ..moveTo(-s * 0.52, 0)
  ..lineTo(s * 0.22, 0)
  ..moveTo(s * 0.03, -s * 0.19)
  ..lineTo(s * 0.35, 0)
  ..lineTo(s * 0.03, s * 0.19);

/// Line weight that keeps the glyph legible at any size.
double arrowStroke(double s) => s * 0.10;
