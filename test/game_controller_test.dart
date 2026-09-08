import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unstack/engine/board.dart';
import 'package:unstack/state/game_controller.dart';
import 'package:unstack/state/level_ref.dart';
import 'package:unstack/state/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await ProgressStore.load();
  });

  GameController controllerAt(int index) =>
      GameController(store: store, ref: CampaignRef(index));

  /// A cell belonging to an arrow that cannot currently leave.
  Cell? blockedCell(GameController game) {
    final legal = game.board.launchableIds().toSet();
    for (final b in game.board.bodies) {
      if (!legal.contains(b.id)) return b.head;
    }
    return null;
  }

  Cell launchableCell(GameController game) =>
      game.board.bodyById(game.board.launchableIds().first)!.head;

  group('GameController', () {
    test('a legal launch clears the whole arrow', () {
      final game = controllerAt(0);
      final before = game.arrowsLeft;
      final target = game.board.bodyById(game.board.launchableIds().first)!;
      final covered = target.cells;

      expect(game.launch(target.head.row, target.head.col), isA<LaunchOk>());
      expect(game.arrowsLeft, before - 1);
      for (final c in covered) {
        expect(game.board.isEmptyAt(c.row, c.col), isTrue,
            reason: 'every cell of the body must be freed');
      }
      game.dispose();
    });

    test('tapping any cell of a body launches it, not just the head', () {
      final game = controllerAt(30);
      final target = game.board.bodies.firstWhere(
        (b) => b.length > 1 && game.board.isLaunchable(b.id),
        orElse: () => game.board.bodyById(game.board.launchableIds().first)!,
      );
      final tail = target.cells.last;
      expect(game.launch(tail.row, tail.col), isA<LaunchOk>());
      expect(game.board.bodyById(target.id), isNull);
      game.dispose();
    });

    test('a blocked launch reports the cell standing in the way', () {
      final game = controllerAt(30);
      final target = blockedCell(game);
      expect(target, isNotNull, reason: 'level 31 should have a blocked arrow');

      final result = game.launch(target!.row, target.col);
      expect(result, isA<LaunchBlocked>());
      final blocked = result as LaunchBlocked;
      expect(game.board.isEmptyAt(blocked.blocker.row, blocked.blocker.col),
          isFalse);
      expect(
        game.board.bodyAt(blocked.blocker.row, blocked.blocker.col)!.id,
        isNot(blocked.body.id),
        reason: 'an arrow must never be reported as blocking itself',
      );
      game.dispose();
    });

    test('undo puts the whole body back', () {
      final game = controllerAt(12);
      final target = game.board.bodyById(game.board.launchableIds().first)!;
      final covered = target.cells;

      game.launch(target.head.row, target.head.col);
      game.undo();

      for (final c in covered) {
        expect(game.board.bodyAt(c.row, c.col)?.id, target.id);
      }
      expect(game.canUndo, isFalse);
      game.dispose();
    });

    test('undo unwinds a full solve back to the starting board', () {
      final game = controllerAt(20);
      final total = game.arrowsTotal;
      for (final step in game.level.solutionOrder) {
        game.launch(step.head.row, step.head.col);
      }
      expect(game.won, isTrue);

      for (var i = 0; i < total; i++) {
        game.undo();
      }
      expect(game.arrowsLeft, total);
      expect(game.won, isFalse);
      expect(game.canUndo, isFalse);
      game.dispose();
    });

    test('a clean solve is worth three stars and pays out', () async {
      final game = controllerAt(5);
      for (final step in game.level.solutionOrder) {
        game.launch(step.head.row, step.head.col);
      }
      await Future<void>.delayed(Duration.zero);
      expect(game.stars, 3);
      expect(game.payout, ProgressStore.coinsByStars[3]);
      expect(store.currentLevel, 6);
      game.dispose();
    });

    test('the first hint of a level is free', () async {
      final game = controllerAt(40);
      final before = store.coins;
      expect(game.hintIsFree, isTrue);
      expect(await game.useHint(), isNull);
      expect(store.coins, before, reason: 'free hint must not charge');
      expect(game.hintIsFree, isFalse);
      expect(
        game.board.isLaunchable(
          game.board.bodyAt(game.hinted!.row, game.hinted!.col)!.id,
        ),
        isTrue,
      );
      game.dispose();
    });

    test('hints after the free one cost coins', () async {
      final game = controllerAt(40);
      await game.useHint();
      final before = store.coins;
      expect(await game.useHint(), isNull);
      expect(store.coins, before - ProgressStore.hintCost);
      game.dispose();
    });

    test('an empty wallet refuses a paid hint and charges nothing', () async {
      final game = controllerAt(9);
      await game.useHint();
      await store.spend(store.coins);
      expect(await game.useHint(), HintDenial.broke);
      expect(game.hintsUsed, 1);
      expect(store.coins, 0);
      game.dispose();
    });

    test('the free hint resets on the next level', () async {
      final game = controllerAt(3);
      await game.useHint();
      expect(game.hintIsFree, isFalse);
      game.nextLevel();
      expect(game.hintIsFree, isTrue);
      game.dispose();
    });

    test('nextLevel advances and resets the run', () {
      final game = controllerAt(3);
      final first = launchableCell(game);
      game.launch(first.row, first.col);
      game.nextLevel();
      expect((game.ref as CampaignRef).index, 4);
      expect(game.canUndo, isFalse);
      expect(game.mistakes, 0);
      expect(game.arrowsLeft, game.arrowsTotal);
      game.dispose();
    });

    test('the daily has no next level', () {
      final game = GameController(store: store, ref: DailyRef.today());
      expect(game.isDaily, isTrue);
      game.nextLevel();
      expect(game.ref, isA<DailyRef>());
      game.dispose();
    });

    test('a level opens at full health', () {
      final game = controllerAt(30);
      expect(game.health, GameController.maxHealth);
      expect(game.failed, isFalse);
      game.dispose();
    });

    test('a blocked tap costs one health, a legal one costs none', () {
      final game = controllerAt(30);
      final blocked = blockedCell(game)!;
      game.launch(blocked.row, blocked.col);
      expect(game.health, GameController.maxHealth - 1);

      final legal = launchableCell(game);
      game.launch(legal.row, legal.col);
      expect(game.health, GameController.maxHealth - 1);
      game.dispose();
    });

    test('running out of health fails the level and stops play', () {
      final game = controllerAt(30);
      for (var i = 0; i < GameController.maxHealth; i++) {
        final target = blockedCell(game);
        expect(target, isNotNull, reason: 'need a blocked arrow on attempt $i');
        game.launch(target!.row, target.col);
      }
      expect(game.health, 0);
      expect(game.failed, isTrue);

      final remaining = game.arrowsLeft;
      final legal = launchableCell(game);
      expect(game.launch(legal.row, legal.col), isA<LaunchNothing>());
      expect(game.arrowsLeft, remaining, reason: 'board must not change');
      game.dispose();
    });

    test('reviving restores play with one health', () {
      final game = controllerAt(30);
      for (var i = 0; i < GameController.maxHealth; i++) {
        final target = blockedCell(game)!;
        game.launch(target.row, target.col);
      }
      game.reviveWithHealth();
      expect(game.failed, isFalse);
      expect(game.health, 1);

      final legal = launchableCell(game);
      expect(game.launch(legal.row, legal.col), isA<LaunchOk>());
      game.dispose();
    });

    test('restart brings health back to full', () {
      final game = controllerAt(30);
      final target = blockedCell(game)!;
      game.launch(target.row, target.col);
      game.restart();
      expect(game.health, GameController.maxHealth);
      expect(game.failed, isFalse);
      game.dispose();
    });

    test('every chapter boundary builds a playable level', () {
      for (final index in [0, 12, 32, 57, 87, 117, 400]) {
        final game = controllerAt(index);
        expect(game.arrowsLeft, greaterThan(0), reason: 'level $index is empty');
        expect(
          game.board.launchableIds(),
          isNotEmpty,
          reason: 'level $index opens with no legal move',
        );
        game.dispose();
      }
    });
  });
}
