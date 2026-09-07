import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/board.dart';
import '../engine/direction.dart';
import '../engine/level.dart';
import 'level_ref.dart';
import 'progress_store.dart';

typedef Cell = ({int row, int col});

/// Outcome of tapping a cell.
sealed class LaunchResult {
  const LaunchResult();
}

/// The arrow left the board. [path] runs from the first cell it crosses to one
/// step past the edge, so the view can animate the flight.
class LaunchOk extends LaunchResult {
  const LaunchOk({required this.from, required this.dir, required this.path});

  final Cell from;
  final Direction dir;
  final List<Cell> path;
}

/// The arrow could not leave. [blocker] is the first arrow standing in its way
/// — shown to the player so the rule teaches itself.
class LaunchBlocked extends LaunchResult {
  const LaunchBlocked({required this.from, required this.blocker});

  final Cell from;
  final Cell blocker;
}

/// The tapped cell was empty.
class LaunchNothing extends LaunchResult {
  const LaunchNothing();
}

/// Why a hint request did not produce a hint.
enum HintDenial { broke, alreadyWon, noneAvailable }

/// Owns the board and the run of a single level.
class GameController extends ChangeNotifier {
  GameController({required this.store, required LevelRef ref}) {
    load(ref);
  }

  final ProgressStore store;

  late Level _level;
  late Board _board;
  late LevelRef _ref;

  /// Health at the start of a level. A blocked tap costs one.
  static const int maxHealth = 3;

  /// Every level opens with one hint on the house; the rest cost coins.
  static const int freeHintsPerLevel = 1;

  final List<Cell> _undo = [];
  int _mistakes = 0;
  int _hintsUsed = 0;
  int _freeHintsLeft = freeHintsPerLevel;
  int _health = maxHealth;
  Cell? _hinted;
  bool _won = false;
  bool _failed = false;
  int _payout = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Recording a win and buying a hint both await a disk write, and the player
  /// can leave the screen before it lands. Notifying a disposed controller
  /// throws, so every notification goes through here.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  Board get board => _board;
  Level get level => _level;
  LevelRef get ref => _ref;
  int get mistakes => _mistakes;
  int get hintsUsed => _hintsUsed;
  Cell? get hinted => _hinted;
  bool get won => _won;
  bool get canUndo => _undo.isNotEmpty;

  /// Coins awarded for the win currently on screen.
  int get payout => _payout;

  int get arrowsLeft => _board.arrowCount;
  int get arrowsTotal => _level.profile.arrowCount;

  bool get isDaily => _ref is DailyRef;

  int get health => _health;
  bool get failed => _failed;

  /// Whether the next hint is on the house.
  bool get hintIsFree => _freeHintsLeft > 0;

  /// A hint is available if it is free or the wallet covers it.
  bool get canHint => !_won && !_failed && (hintIsFree || store.canAffordHint);

  /// Stars for the current run. Paid hints cost more than a blocked tap,
  /// because a blocked tap is how the game teaches its own rule.
  int get stars {
    if (!_won) return 0;
    final paidHints = (_hintsUsed - freeHintsPerLevel).clamp(0, _hintsUsed);
    final penalty = (maxHealth - _health) + paidHints * 2;
    if (penalty == 0) return 3;
    if (penalty <= 2) return 2;
    return 1;
  }

  void load(LevelRef ref) {
    _ref = ref;
    _level = ref.build();
    _board = _level.toBoard();
    _undo.clear();
    _mistakes = 0;
    _hintsUsed = 0;
    _freeHintsLeft = freeHintsPerLevel;
    _health = maxHealth;
    _hinted = null;
    _won = false;
    _failed = false;
    _payout = 0;
    _notify();
  }

  void restart() => load(_ref);

  /// Advances to the next campaign level. No-op on the daily, which has none.
  void nextLevel() {
    final current = _ref;
    if (current is CampaignRef) load(current.next);
  }

  /// Attempts to launch the top arrow at [row], [col].
  LaunchResult launch(int row, int col) {
    if (_won || _failed) return const LaunchNothing();
    final dir = _board.topAt(row, col);
    if (dir == null) return const LaunchNothing();

    final blocker = _firstBlocker(row, col, dir);
    if (blocker != null) {
      _mistakes++;
      if (_health > 0) _health--;
      if (_health == 0) _failed = true;
      _notify();
      return LaunchBlocked(from: (row: row, col: col), blocker: blocker);
    }

    final path = _board.pathFrom(row, col, dir);
    _board.pop(row, col);
    _undo.add((row: row, col: col));
    if (_hinted != null && _hinted!.row == row && _hinted!.col == col) {
      _hinted = null;
    }
    if (_board.isCleared) {
      _won = true;
      unawaited(_record());
    }
    _notify();
    return LaunchOk(from: (row: row, col: col), dir: dir, path: path);
  }

  Future<void> _record() async {
    final current = _ref;
    final earned = switch (current) {
      CampaignRef() => await store.recordCampaignWin(current.index, stars),
      DailyRef() => await store.recordDailyWin(current.day, stars),
    };
    _payout = earned;
    _notify();
  }

  /// Puts the last launched arrow back. Undo is free — the puzzle has no fail
  /// state, so charging for it would only add friction.
  void undo() {
    if (_undo.isEmpty) return;
    final cell = _undo.removeLast();
    // Recover the arrow's facing from the level definition: the one to restore
    // sits at the stack position the cell has just been cut back to.
    final height = _board.heightAt(cell.row, cell.col);
    final dir = _facingAt(cell.row, cell.col, height);
    if (dir == null) {
      _undo.add(cell);
      return;
    }
    _board.push(cell.row, cell.col, dir);
    _won = false;
    _hinted = null;
    _notify();
  }

  /// Buys a hint, revealing one arrow that can be launched right now.
  ///
  /// Any legal move is safe — launching only ever frees space, so no move can
  /// strand the player. A hint therefore never has to search for a *correct*
  /// move, only a legal one.
  Future<HintDenial?> useHint() async {
    if (_won || _failed) return HintDenial.alreadyWon;
    final options = _board.launchableCells();
    if (options.isEmpty) return HintDenial.noneAvailable;

    if (_freeHintsLeft > 0) {
      _freeHintsLeft--;
    } else if (!await store.spend(ProgressStore.hintCost)) {
      return HintDenial.broke;
    }

    _hintsUsed++;
    _hinted = options.first;
    _notify();
    return null;
  }

  /// Grants one health back so the run can continue — the reward for watching
  /// an ad once the board has run the player out.
  void reviveWithHealth([int amount = 1]) {
    if (!_failed) return;
    _failed = false;
    _health = amount.clamp(1, maxHealth);
    _notify();
  }

  void clearHint() {
    if (_hinted == null) return;
    _hinted = null;
    _notify();
  }

  /// The first occupied cell in the arrow's lane, or null if the lane is clear.
  Cell? _firstBlocker(int row, int col, Direction dir) {
    var r = row + dir.dr;
    var c = col + dir.dc;
    while (_board.contains(r, c)) {
      if (!_board.isEmptyAt(r, c)) return (row: r, col: c);
      r += dir.dr;
      c += dir.dc;
    }
    return null;
  }

  /// The facing of the arrow originally placed at [row], [col] at stack
  /// position [height] (zero-based from the bottom).
  Direction? _facingAt(int row, int col, int height) {
    var seen = 0;
    for (final p in _level.placements) {
      if (p.row == row && p.col == col) {
        if (seen == height) return p.dir;
        seen++;
      }
    }
    return null;
  }
}
