import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:unstack/engine/board.dart';
import 'package:unstack/engine/direction.dart';
import 'package:unstack/engine/generator.dart';

void main() {
  group('Mirror bends', () {
    test('slash and backslash bend every heading correctly', () {
      // Slash rises to the right: right<->up, left<->down.
      expect(Mirror.slash.bend(Direction.right), Direction.up);
      expect(Mirror.slash.bend(Direction.up), Direction.right);
      expect(Mirror.slash.bend(Direction.left), Direction.down);
      expect(Mirror.slash.bend(Direction.down), Direction.left);
      // Backslash falls to the right: right<->down, left<->up.
      expect(Mirror.backslash.bend(Direction.right), Direction.down);
      expect(Mirror.backslash.bend(Direction.down), Direction.right);
      expect(Mirror.backslash.bend(Direction.left), Direction.up);
      expect(Mirror.backslash.bend(Direction.up), Direction.left);
    });

    test('a bend is an involution: bouncing twice restores the heading', () {
      for (final m in Mirror.values) {
        for (final d in Direction.values) {
          expect(m.bend(m.bend(d)), d);
        }
      }
    });
  });

  group('Lanes through mirrors', () {
    test('a mirror never blocks, it redirects', () {
      // Arrow at (2,0) facing right meets a slash at (2,2) and turns up.
      // Rows 1 and 0 above the mirror are empty, so the lane is clear.
      final board = Board(4, 4)
        ..setMirror(2, 2, Mirror.slash)
        ..push(2, 0, Direction.right);
      expect(board.isLaunchable(2, 0), isTrue);
    });

    test('an arrow after the bend blocks the lane', () {
      final board = Board(4, 4)
        ..setMirror(2, 2, Mirror.slash)
        ..push(2, 0, Direction.right)
        ..push(0, 2, Direction.left); // in the bent lane, above the mirror
      expect(board.isLaunchable(2, 0), isFalse);
      expect(board.firstBlocker(2, 0, Direction.right), (row: 0, col: 2));
    });

    test('an arrow off the bent lane does not block it', () {
      // Without the mirror, (2,3) would be in the way. With it, the lane
      // turns up at column 2 and never reaches column 3.
      final board = Board(4, 4)
        ..setMirror(2, 2, Mirror.slash)
        ..push(2, 0, Direction.right)
        ..push(2, 3, Direction.up);
      expect(board.isLaunchable(2, 0), isTrue);
    });

    test('backslash sends a rightward arrow down', () {
      final board = Board(4, 4)
        ..setMirror(1, 1, Mirror.backslash)
        ..push(1, 0, Direction.right)
        ..push(3, 1, Direction.left); // below the mirror, in the bent lane
      expect(board.isLaunchable(1, 0), isFalse);
      expect(board.firstBlocker(1, 0, Direction.right), (row: 3, col: 1));
    });

    test('pathFrom records the heading before and after the bend', () {
      final board = Board(4, 4)
        ..setMirror(2, 2, Mirror.slash)
        ..push(2, 0, Direction.right);
      final path = board.pathFrom(2, 0, Direction.right);
      // (2,1) reached going right, the mirror at (2,2) reached going right,
      // then (1,2) and (0,2) reached going up, then one step off the top.
      expect(
        path.map((s) => '${s.row},${s.col}:${s.dir.name}').toList(),
        ['2,1:right', '2,2:right', '1,2:up', '0,2:up', '-1,2:up'],
      );
    });

    test('a lane that circles back reads as blocked and terminates', () {
      // Right into a backslash, down into a slash, left into a backslash,
      // up into a slash: the lane returns to the origin cell, which holds
      // the arrow itself. It must read as blocked, not loop forever.
      final board = Board(3, 3)
        ..setMirror(0, 1, Mirror.backslash)
        ..setMirror(1, 1, Mirror.slash)
        ..setMirror(1, 0, Mirror.backslash)
        ..push(0, 0, Direction.right);
      expect(board.isLaunchable(0, 0), isFalse);
      expect(board.firstBlocker(0, 0, Direction.right), (row: 0, col: 0));
    });

    test('a mirror on the last cell bends the exit step off the board', () {
      // Arrow at (1,0) facing right, backslash at (1,3) on the right edge.
      // Right becomes down, so the lane leaves through the bottom, not the
      // right side, and the animation must follow it.
      final board = Board(3, 4)
        ..setMirror(1, 3, Mirror.backslash)
        ..push(1, 0, Direction.right);
      final path = board.pathFrom(1, 0, Direction.right);
      // (2,3) is on the board and empty, so the lane continues down through
      // it and leaves off the bottom at (3,3).
      expect(path.map((s) => '${s.row},${s.col}:${s.dir.name}').toList(),
          ['1,1:right', '1,2:right', '1,3:right', '2,3:down', '3,3:down']);
      expect(board.isLaunchable(1, 0), isTrue);
    });
  });

  group('Generator with mirrors', () {
    const gen = LevelGenerator();

    test('arrows are never placed on a mirror', () {
      for (var seed = 0; seed < 30; seed++) {
        final level = gen.generate(
          rows: 6, cols: 4, targetArrows: 20, maxStack: 3,
          hardness: 0.6, seed: seed, mirrors: 4,
        );
        final mirrored = level.mirrors.map((m) => '${m.row},${m.col}').toSet();
        for (final p in level.placements) {
          expect(
            mirrored.contains('${p.row},${p.col}'),
            isFalse,
            reason: 'seed $seed put an arrow on a mirror',
          );
        }
      }
    });

    test('the generator lays the mirrors it was asked for', () {
      final level = gen.generate(
        rows: 7, cols: 5, targetArrows: 24, maxStack: 3,
        hardness: 0.5, seed: 11, mirrors: 5,
      );
      expect(level.mirrors.length, 5);
      expect(level.toBoard().mirrorCount, 5);
    });

    test('the canonical solution is legal at every step', () {
      for (var seed = 0; seed < 40; seed++) {
        final level = gen.generate(
          rows: 7, cols: 5, targetArrows: 30, maxStack: 3,
          hardness: seed / 40, seed: seed + 900, mirrors: 2 + seed % 5,
        );
        final board = level.toBoard();
        for (final step in level.solutionOrder) {
          expect(board.topAt(step.row, step.col), step.dir);
          expect(
            board.isLaunchable(step.row, step.col),
            isTrue,
            reason: 'seed $seed: (${step.row},${step.col}) must be legal',
          );
          board.pop(step.row, step.col);
        }
        expect(board.isCleared, isTrue);
      }
    });

    test('random legal play always clears the board', () {
      // The guarantee must survive bends: mirrors are fixed, so removing an
      // arrow still only ever frees a lane and never closes one.
      final rng = Random(4321);
      for (var seed = 0; seed < 40; seed++) {
        final level = gen.generate(
          rows: 8, cols: 5, targetArrows: 36, maxStack: 4,
          hardness: rng.nextDouble(), seed: seed + 1500, mirrors: 3 + seed % 6,
        );
        final board = level.toBoard();
        var moves = 0;
        while (!board.isCleared) {
          final options = board.launchableCells();
          expect(
            options,
            isNotEmpty,
            reason: 'stuck with ${board.arrowCount} left on seed $seed',
          );
          final pick = options[rng.nextInt(options.length)];
          board.pop(pick.row, pick.col);
          moves++;
        }
        expect(moves, level.profile.arrowCount);
      }
    });

    test('mirrors actually matter: lanes in a level pass through them', () {
      // A mirror nobody's lane crosses is a wasted cell. Across a batch of
      // levels a healthy share of arrows must have a bend in their lane.
      var bent = 0;
      var total = 0;
      for (var seed = 0; seed < 20; seed++) {
        final level = gen.generate(
          rows: 7, cols: 5, targetArrows: 28, maxStack: 3,
          hardness: 0.6, seed: seed + 77, mirrors: 4,
        );
        final board = level.toBoard();
        for (final p in level.placements) {
          total++;
          final path = board.pathFrom(p.row, p.col, p.dir);
          if (path.any((s) => s.dir != p.dir)) bent++;
        }
      }
      expect(
        bent / total,
        greaterThan(0.15),
        reason: 'only $bent of $total lanes bend',
      );
    });
  });
}
