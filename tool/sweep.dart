// ignore_for_file: avoid_print
// Sweeps every level in a range and reports any that generate short.
//
//   dart run tool/sweep.dart

import 'package:unstack/state/chapters.dart';

void main() {
  var short = 0;
  var worst = 0.0;
  final examples = <String>[];

  for (var i = 0; i < 130; i++) {
    final want = Chapters.arrowsFor(i);
    final level = Chapters.build(i);
    final got = level.profile.arrowCount;
    if (got < want) {
      short++;
      final miss = (want - got) / want;
      if (miss > worst) worst = miss;
      if (examples.length < 14) {
        final at = Chapters.locate(i);
        final grid = Chapters.gridFor(want, at.spec.avgBody);
        examples.add(
          'lvl ${i.toString().padLeft(3)}  ${at.spec.name.padRight(12)} '
          'want $want got $got  ${grid.cols}x${grid.rows} '
          'body ${at.spec.minBody}-${at.spec.maxBody}',
        );
      }
    }
  }

  print('levels short: $short of 130');
  print('worst shortfall: ${(worst * 100).toStringAsFixed(0)}%');
  for (final e in examples) {
    print('  $e');
  }
}
