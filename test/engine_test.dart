import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:unstack/engine/board.dart';
import 'package:unstack/engine/direction.dart';
import 'package:unstack/engine/generator.dart';

void main() {
  group('Board rules', () {
    test('an arrow with an empty lane can launch', () {
      final board = Board(3, 3)..push(1, 1, Direction.right);
      expect(board.isLaunchable(1, 1), isTrue);
    });

    test('an arrow is blocked by anything in its lane', () {
      final board = Board(3, 3)
        ..push(1, 1, Direction.right)
        ..push(1, 2, Direction.up);
      expect(board.isLaunchable(1, 1), isFalse);
      // The blocker itself is on the edge facing out, so it can still go.
      expect(board.isLaunchable(1, 2), isTrue);
    });

    test('a stack never blocks its own top arrow', () {
      final board = Board(3, 3)
        ..push(1, 1, Direction.up)
        ..push(1, 1, Direction.right);
      expect(board.heightAt(1, 1), 2);
      expect(board.topAt(1, 1), Direction.right);
      expect(board.isLaunchable(1, 1), isTrue);
    });

    test('only the top of a stack is considered', () {
      // Top faces right into a blocker; the buried arrow faces a clear lane
      // but must not be launchable.
      final board = Board(3, 3)
        ..push(1, 1, Direction.up)
        ..push(1, 1, Direction.right)
        ..push(1, 2, Direction.down);
      expect(board.isLaunchable(1, 1), isFalse);
      board.pop(1, 1);
      expect(board.isLaunchable(1, 1), isTrue, reason: 'buried arrow now on top');
    });

    test('clone is a deep copy', () {
      final board = Board(2, 2)..push(0, 0, Direction.up);
      final copy = board.clone()..push(0, 0, Direction.down);
      expect(board.heightAt(0, 0), 1);
      expect(copy.heightAt(0, 0), 2);
    });
  });

  group('Generator', () {
    const gen = LevelGenerator();

    // Configurations spanning the range we expect to ship.
    final configs = [
      (rows: 4, cols: 4, arrows: 10, stack: 1),
      (rows: 5, cols: 5, arrows: 18, stack: 2),
      (rows: 6, cols: 6, arrows: 30, stack: 3),
      (rows: 7, cols: 5, arrows: 34, stack: 3),
    ];

    test('the canonical solution is legal at every step', () {
      for (final cfg in configs) {
        for (var seed = 0; seed < 40; seed++) {
          final level = gen.generate(
            rows: cfg.rows,
            cols: cfg.cols,
            targetArrows: cfg.arrows,
            maxStack: cfg.stack,
            hardness: seed / 40,
            seed: seed,
          );
          final board = level.toBoard();
          for (final step in level.solutionOrder) {
            expect(
              board.topAt(step.row, step.col),
              step.dir,
              reason: 'solution step must address the visible arrow',
            );
            expect(
              board.isLaunchable(step.row, step.col),
              isTrue,
              reason: 'seed $seed step (${step.row},${step.col}) must be legal',
            );
            board.pop(step.row, step.col);
          }
          expect(board.isCleared, isTrue);
        }
      }
    });

    test('random legal play always clears the board', () {
      // The strong claim: because launching only ever frees space, no sequence
      // of legal moves can strand the player. Play greedily at random and the
      // board must always empty out.
      final rng = Random(1234);
      for (final cfg in configs) {
        for (var seed = 0; seed < 30; seed++) {
          final level = gen.generate(
            rows: cfg.rows,
            cols: cfg.cols,
            targetArrows: cfg.arrows,
            maxStack: cfg.stack,
            hardness: rng.nextDouble(),
            seed: seed + 500,
          );
          final board = level.toBoard();
          var moves = 0;
          while (!board.isCleared) {
            final options = board.launchableCells();
            expect(
              options,
              isNotEmpty,
              reason: 'stuck with ${board.arrowCount} arrows left '
                  '(seed $seed, ${cfg.rows}x${cfg.cols})',
            );
            final pick = options[rng.nextInt(options.length)];
            board.pop(pick.row, pick.col);
            moves++;
          }
          expect(moves, level.profile.arrowCount);
        }
      }
    });

    test('every solution costs exactly one move per arrow', () {
      final level = gen.generate(
        rows: 6,
        cols: 6,
        targetArrows: 28,
        maxStack: 3,
        hardness: 0.6,
        seed: 99,
      );
      expect(level.solutionOrder.length, level.toBoard().arrowCount);
    });

    test('higher hardness yields more constrained boards', () {
      double meanScore(double hardness) {
        var total = 0.0;
        const trials = 30;
        for (var seed = 0; seed < trials; seed++) {
          total += gen
              .generateTuned(
                rows: 6,
                cols: 6,
                targetArrows: 28,
                maxStack: 3,
                hardness: hardness,
                seed: seed * 31 + 7,
              )
              .profile
              .score;
        }
        return total / trials;
      }

      final easy = meanScore(0.15);
      final hard = meanScore(0.9);
      expect(
        hard,
        greaterThan(easy),
        reason: 'hardness knob must actually move difficulty (easy=$easy hard=$hard)',
      );
    });

    test('generateTuned fills the board it was asked for', () {
      final level = gen.generateTuned(
        rows: 6,
        cols: 6,
        targetArrows: 26,
        maxStack: 3,
        hardness: 0.5,
        seed: 4242,
      );
      // Saturation can cost a few arrows, but not many.
      expect(level.profile.arrowCount, greaterThanOrEqualTo(22));
    });

    test('the same seed reproduces the same level', () {
      final a = gen.generate(
          rows: 5, cols: 5, targetArrows: 18, maxStack: 2, hardness: 0.5, seed: 77);
      final b = gen.generate(
          rows: 5, cols: 5, targetArrows: 18, maxStack: 2, hardness: 0.5, seed: 77);
      expect(a.placements.length, b.placements.length);
      for (var i = 0; i < a.placements.length; i++) {
        expect(a.placements[i].row, b.placements[i].row);
        expect(a.placements[i].col, b.placements[i].col);
        expect(a.placements[i].dir, b.placements[i].dir);
      }
    });
  });
}
