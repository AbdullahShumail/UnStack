// ignore_for_file: avoid_print
// Walks the real progression and reports whether each level actually fills.
//
//   dart run tool/levels.dart

import 'package:unstack/state/chapters.dart';

void main() {
  print('lvl  chapter       want  got  grid  stack  fill%   score');
  print('-' * 62);

  var shortfalls = 0;
  for (final index in [
    0, 3, 6, 11, // First Steps
    12, 20, 31, // Stacking Up
    32, 45, 56, // Deep Cuts
    57, 72, 86, // Gridlock
    87, 100, 116, // Tower Block
    117, 140, 176, 300, // Endless
  ]) {
    final at = Chapters.locate(index);
    final want = Chapters.arrowsFor(index);
    final grid = Chapters.gridFor(want, at.spec.maxStack);
    final level = Chapters.build(index);
    final got = level.profile.arrowCount;
    final fill = got / (grid.rows * grid.cols * at.spec.maxStack) * 100;
    if (got < want) shortfalls++;

    print(
      '${index.toString().padLeft(3)}  '
      '${at.spec.name.padRight(13)} '
      '${want.toString().padLeft(4)} '
      '${got.toString().padLeft(4)}  '
      '${grid.cols}x${grid.rows}  '
      '${at.spec.maxStack.toString().padLeft(5)}  '
      '${fill.toStringAsFixed(0).padLeft(4)}%  '
      '${level.profile.score.toStringAsFixed(2).padLeft(6)}'
      '${got < want ? "   <-- SHORT" : ""}',
    );
  }

  print('');
  print(shortfalls == 0
      ? 'All sampled levels filled to target.'
      : '$shortfalls level(s) came up short — lower _occupancy in chapters.dart.');
}
