import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:unstack/engine/board.dart';
import 'package:unstack/engine/direction.dart';
import 'package:unstack/engine/generator.dart';

void main() {
  ArrowBody body(int id, Direction dir, List<Cell> cells) =>
      ArrowBody(id: id, dir: dir, cells: cells);

  group('Board rules', () {
    test('an arrow with an empty lane can launch', () {
      final b = Board(3, 3)
        ..place(body(0, Direction.right, [(row: 1, col: 0)]));
      expect(b.isLaunchable(0), isTrue);
    });

    test('a body blocks a lane, not just a head', () {
      // Arrow 1's tail lies across arrow 0's lane; its head is elsewhere.
      final b = Board(3, 4)
        ..place(body(0, Direction.right, [(row: 1, col: 0)]))
        ..place(body(1, Direction.up, [
          (row: 0, col: 2),
          (row: 1, col: 2),
        ]));
      expect(
        b.bodyAt(1, 2)!.id,
        1,
        reason: 'the blocking cell is a tail cell, not a head',
      );
      expect(b.isLaunchable(0), isFalse);
      expect(b.isLaunchable(1), isTrue);
    });

    test('an arrow is not blocked by its own body', () {
      final b = Board(3, 4)
        ..place(body(0, Direction.right, [
          (row: 1, col: 2),
          (row: 1, col: 1),
          (row: 1, col: 0),
        ]));
      expect(b.isLaunchable(0), isTrue);
    });

    test('removing an arrow frees every cell it covered', () {
      final cells = [(row: 1, col: 2), (row: 1, col: 1), (row: 0, col: 1)];
      final b = Board(3, 3)..place(body(0, Direction.right, cells));
      for (final c in cells) {
        expect(b.isEmptyAt(c.row, c.col), isFalse);
      }
      b.remove(0);
      for (final c in cells) {
        expect(b.isEmptyAt(c.row, c.col), isTrue);
      }
      expect(b.isCleared, isTrue);
    });

    test('canPlace rejects an overlap', () {
      final b = Board(3, 3)
        ..place(body(0, Direction.right, [(row: 1, col: 1)]));
      expect(
        b.canPlace(body(1, Direction.up, [(row: 1, col: 1)])),
        isFalse,
      );
      expect(
        b.canPlace(body(1, Direction.up, [(row: 0, col: 0)])),
        isTrue,
      );
    });

    test('clone is a deep copy', () {
      final b = Board(2, 2)..place(body(0, Direction.up, [(row: 0, col: 0)]));
      final copy = b.clone()..remove(0);
      expect(b.arrowCount, 1);
      expect(copy.arrowCount, 0);
    });
  });

  group('Generator', () {
    const gen = LevelGenerator();

    final configs = [
      (rows: 5, cols: 3, arrows: 5, minBody: 1, maxBody: 2),
      (rows: 6, cols: 4, arrows: 8, minBody: 2, maxBody: 3),
      (rows: 7, cols: 5, arrows: 12, minBody: 2, maxBody: 4),
      (rows: 8, cols: 5, arrows: 16, minBody: 3, maxBody: 5),
    ];

    test('the canonical solution is legal at every step', () {
      for (final cfg in configs) {
        for (var seed = 0; seed < 30; seed++) {
          final level = gen.generate(
            rows: cfg.rows,
            cols: cfg.cols,
            targetArrows: cfg.arrows,
            minBody: cfg.minBody,
            maxBody: cfg.maxBody,
            hardness: seed / 30,
            seed: seed,
          );
          final board = level.toBoard();
          for (final step in level.solutionOrder) {
            expect(
              board.isLaunchable(step.id),
              isTrue,
              reason: 'seed $seed arrow ${step.id} must have a clear lane',
            );
            board.remove(step.id);
          }
          expect(board.isCleared, isTrue);
        }
      }
    });

    test('random legal play always clears the board', () {
      // The strong claim: removing an arrow frees every cell it covered, so
      // lanes only ever open up and no sequence of legal moves can strand the
      // player. Play at random and the board must always empty out.
      final rng = Random(1234);
      for (final cfg in configs) {
        for (var seed = 0; seed < 25; seed++) {
          final level = gen.generate(
            rows: cfg.rows,
            cols: cfg.cols,
            targetArrows: cfg.arrows,
            minBody: cfg.minBody,
            maxBody: cfg.maxBody,
            hardness: rng.nextDouble(),
            seed: seed + 500,
          );
          final board = level.toBoard();
          var moves = 0;
          while (!board.isCleared) {
            final options = board.launchableIds();
            expect(
              options,
              isNotEmpty,
              reason: 'stuck with ${board.arrowCount} arrows left '
                  '(seed $seed, ${cfg.rows}x${cfg.cols})',
            );
            board.remove(options[rng.nextInt(options.length)]);
            moves++;
          }
          expect(moves, level.profile.arrowCount);
        }
      }
    });

    test('bodies never overlap', () {
      for (var seed = 0; seed < 40; seed++) {
        final level = gen.generate(
          rows: 7, cols: 5, targetArrows: 12,
          minBody: 2, maxBody: 4, hardness: 0.6, seed: seed,
        );
        final seen = <String>{};
        for (final b in level.bodies) {
          for (final c in b.cells) {
            expect(
              seen.add('${c.row},${c.col}'),
              isTrue,
              reason: 'cell ${c.row},${c.col} covered twice on seed $seed',
            );
          }
        }
      }
    });

    test('a body never lies in its own lane', () {
      for (var seed = 0; seed < 40; seed++) {
        final level = gen.generate(
          rows: 7, cols: 5, targetArrows: 12,
          minBody: 2, maxBody: 4, hardness: 0.6, seed: seed,
        );
        final board = Board(level.rows, level.cols);
        for (final b in level.bodies) {
          final lane = board.exitPath(b.head, b.dir).map(
                (c) => '${c.row},${c.col}',
              );
          for (final c in b.cells) {
            expect(
              lane.contains('${c.row},${c.col}'),
              isFalse,
              reason: 'arrow ${b.id} blocks itself on seed $seed',
            );
          }
        }
      }
    });

    test('bodies respect the requested length range', () {
      final level = gen.generate(
        rows: 8, cols: 5, targetArrows: 14,
        minBody: 3, maxBody: 5, hardness: 0.5, seed: 21,
      );
      for (final b in level.bodies) {
        expect(b.length, greaterThanOrEqualTo(3));
        expect(b.length, lessThanOrEqualTo(5));
      }
    });

    test('every solution costs exactly one move per arrow', () {
      final level = gen.generate(
        rows: 7, cols: 5, targetArrows: 12,
        minBody: 2, maxBody: 4, hardness: 0.6, seed: 99,
      );
      expect(level.solutionOrder.length, level.toBoard().arrowCount);
    });

    test('higher hardness yields more constrained boards', () {
      double meanScore(double hardness) {
        var total = 0.0;
        const trials = 25;
        for (var seed = 0; seed < trials; seed++) {
          total += gen
              .generateTuned(
                rows: 7, cols: 5, targetArrows: 12,
                minBody: 2, maxBody: 4,
                hardness: hardness, seed: seed * 31 + 7,
              )
              .profile
              .score;
        }
        return total / trials;
      }

      final easy = meanScore(0.1);
      final hard = meanScore(0.95);
      expect(
        hard,
        greaterThan(easy),
        reason: 'hardness must move difficulty (easy=$easy hard=$hard)',
      );
    });

    test('the same seed reproduces the same level', () {
      Level0 build() => Level0(gen.generate(
            rows: 7, cols: 5, targetArrows: 12,
            minBody: 2, maxBody: 4, hardness: 0.5, seed: 77,
          ).bodies);
      final a = build();
      final b = build();
      expect(a.signature, b.signature);
    });
  });
}

/// Small helper for comparing two generated levels cell for cell.
class Level0 {
  Level0(this.bodies);
  final List<ArrowBody> bodies;
  String get signature => bodies
      .map((b) =>
          '${b.dir.index}:${b.cells.map((c) => '${c.row},${c.col}').join('>')}')
      .join('|');
}
