// ignore_for_file: avoid_print
// Prints the difficulty a given board config actually produces, so the
// chapter curve in lib/state can be tuned against real numbers.
//
//   dart run tool/curve.dart

import 'package:unstack/engine/generator.dart';

void main() {
  const gen = LevelGenerator();
  const configs = [
    (label: '4x4 s1', rows: 4, cols: 4, arrows: 10, stack: 1),
    (label: '5x5 s2', rows: 5, cols: 5, arrows: 18, stack: 2),
    (label: '5x5 s3', rows: 5, cols: 5, arrows: 24, stack: 3),
    (label: '6x6 s3', rows: 6, cols: 6, arrows: 30, stack: 3),
    (label: '6x6 s4', rows: 6, cols: 6, arrows: 40, stack: 4),
    (label: '7x6 s4', rows: 7, cols: 6, arrows: 48, stack: 4),
  ];
  const knobs = [0.0, 0.25, 0.5, 0.75, 1.0];

  print('config   knob   arrows   avgBranch   openRatio   forced   score');
  print('-' * 64);

  for (final cfg in configs) {
    for (final knob in knobs) {
      var arrows = 0.0, avg = 0.0, open = 0.0, forced = 0.0, score = 0.0;
      const trials = 25;
      for (var seed = 0; seed < trials; seed++) {
        final p = gen
            .generateTuned(
              rows: cfg.rows,
              cols: cfg.cols,
              targetArrows: cfg.arrows,
              maxStack: cfg.stack,
              hardness: knob,
              seed: seed * 101 + 13,
            )
            .profile;
        arrows += p.arrowCount;
        avg += p.avgBranching;
        open += p.avgOpenRatio;
        forced += p.tightSteps;
        score += p.score;
      }
      print(
        '${cfg.label.padRight(8)} '
        '${knob.toStringAsFixed(2).padLeft(4)}   '
        '${(arrows / trials).toStringAsFixed(1).padLeft(6)}   '
        '${(avg / trials).toStringAsFixed(2).padLeft(9)}   '
        '${(open / trials).toStringAsFixed(3).padLeft(9)}   '
        '${(forced / trials).toStringAsFixed(1).padLeft(6)}   '
        '${(score / trials).toStringAsFixed(3).padLeft(5)}',
      );
    }
    print('');
  }
}
