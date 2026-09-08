import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unstack/state/game_controller.dart';
import 'package:unstack/state/level_ref.dart';
import 'package:unstack/state/progress_store.dart';
import 'package:unstack/state/sfx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressStore store;

  setUp(() async {
    // No audio plugin exists under flutter_test, and a failed play resolves
    // after the test that triggered it, which fails whichever test is running
    // by then. Muting keeps playback from ever reaching the platform channel.
    Sfx.instance.muted = true;
    SharedPreferences.setMockInitialValues({});
    store = await ProgressStore.load();
  });

  GameController controllerAt(int index) =>
      GameController(store: store, ref: CampaignRef(index));

  group('GameController', () {
    test('a legal launch clears the arrow', () {
      final game = controllerAt(0);
      final before = game.arrowsLeft;
      final target = game.board.launchableCells().first;
      expect(game.launch(target.row, target.col), isA<LaunchOk>());
      expect(game.arrowsLeft, before - 1);
      expect(game.mistakes, 0);
      game.dispose();
    });

    test('a blocked launch reports the arrow standing in the way', () {
      final game = controllerAt(30);
      final legal =
          game.board.launchableCells().map((c) => '${c.row},${c.col}').toSet();

      LaunchBlocked? blocked;
      for (var r = 0; r < game.board.rows && blocked == null; r++) {
        for (var c = 0; c < game.board.cols; c++) {
          if (game.board.isEmptyAt(r, c) || legal.contains('$r,$c')) continue;
          final result = game.launch(r, c);
          if (result is LaunchBlocked) {
            blocked = result;
            break;
          }
        }
      }

      expect(blocked, isNotNull, reason: 'level 31 should have a blocked arrow');
      expect(game.mistakes, 1);
      expect(
        game.board.isEmptyAt(blocked!.blocker.row, blocked.blocker.col),
        isFalse,
      );
      game.dispose();
    });

    test('undo restores the exact arrow that was launched', () {
      final game = controllerAt(12);
      final target = game.board.launchableCells().first;
      final dir = game.board.topAt(target.row, target.col);
      final height = game.board.heightAt(target.row, target.col);

      game.launch(target.row, target.col);
      expect(game.board.heightAt(target.row, target.col), height - 1);

      game.undo();
      expect(game.board.heightAt(target.row, target.col), height);
      expect(game.board.topAt(target.row, target.col), dir);
      expect(game.canUndo, isFalse);
      game.dispose();
    });

    test('undo unwinds a full solve back to the starting board', () {
      final game = controllerAt(20);
      final total = game.arrowsTotal;
      for (final step in game.level.solutionOrder) {
        game.launch(step.row, step.col);
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
        game.launch(step.row, step.col);
      }
      await Future<void>.delayed(Duration.zero);
      expect(game.stars, 3);
      expect(game.payout, ProgressStore.coinsByStars[3]);
      expect(store.starsFor(5), 3);
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
        game.board.isLaunchable(game.hinted!.row, game.hinted!.col),
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
      expect(game.hintsUsed, 2);
      game.dispose();
    });

    test('an empty wallet refuses a paid hint and charges nothing', () async {
      final game = controllerAt(9);
      await game.useHint(); // free one
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
      final first = game.board.launchableCells().first;
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

    /// A cell whose top arrow is currently blocked, if the level has one.
    Cell? blockedCell(GameController game) {
      final legal =
          game.board.launchableCells().map((c) => '${c.row},${c.col}').toSet();
      for (var r = 0; r < game.board.rows; r++) {
        for (var c = 0; c < game.board.cols; c++) {
          if (game.board.isEmptyAt(r, c)) continue;
          if (legal.contains('$r,$c')) continue;
          return (row: r, col: c);
        }
      }
      return null;
    }

    test('a level opens at full health', () {
      final game = controllerAt(30);
      expect(game.health, GameController.maxHealth);
      expect(game.failed, isFalse);
      game.dispose();
    });

    test('a blocked tap costs one health', () {
      final game = controllerAt(30);
      final target = blockedCell(game)!;
      game.launch(target.row, target.col);
      expect(game.health, GameController.maxHealth - 1);
      expect(game.failed, isFalse);
      game.dispose();
    });

    test('a legal launch costs no health', () {
      final game = controllerAt(30);
      final target = game.board.launchableCells().first;
      game.launch(target.row, target.col);
      expect(game.health, GameController.maxHealth);
      game.dispose();
    });

    test('running out of health fails the level', () {
      final game = controllerAt(30);
      for (var i = 0; i < GameController.maxHealth; i++) {
        final target = blockedCell(game);
        expect(target, isNotNull, reason: 'need a blocked arrow on attempt $i');
        game.launch(target!.row, target.col);
      }
      expect(game.health, 0);
      expect(game.failed, isTrue);
      game.dispose();
    });

    test('a failed level refuses further launches', () {
      final game = controllerAt(30);
      for (var i = 0; i < GameController.maxHealth; i++) {
        final target = blockedCell(game)!;
        game.launch(target.row, target.col);
      }
      final remaining = game.arrowsLeft;
      final legal = game.board.launchableCells().first;
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

      final legal = game.board.launchableCells().first;
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

    test('lost health costs stars', () async {
      final game = controllerAt(30);
      final target = blockedCell(game)!;
      game.launch(target.row, target.col);
      for (final step in game.level.solutionOrder) {
        game.launch(step.row, step.col);
      }
      await Future<void>.delayed(Duration.zero);
      expect(game.won, isTrue);
      expect(game.stars, lessThan(3));
      game.dispose();
    });

    test('every chapter boundary builds a playable level', () {
      for (final index in [0, 12, 32, 57, 87, 117, 400]) {
        final game = controllerAt(index);
        expect(game.arrowsLeft, greaterThan(0), reason: 'level $index is empty');
        expect(
          game.board.launchableCells(),
          isNotEmpty,
          reason: 'level $index opens with no legal move',
        );
        game.dispose();
      }
    });
  });
}
