import '../engine/generator.dart';
import '../engine/level.dart';

/// The once-a-day shared puzzle.
///
/// The seed comes from the calendar date alone, so every player in the world
/// gets the identical board without a server ever being involved. The board
/// config is fixed too — a daily that changes shape day to day makes streaks
/// feel arbitrary.
class Daily {
  const Daily._();

  static const rows = 6;
  static const cols = 6;
  static const maxStack = 3;
  static const arrows = 28;

  /// Middling-hard: beatable in one sitting by a regular, still a real puzzle.
  static const hardness = 0.7;

  /// Strips a timestamp down to the day it falls on.
  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime today() => dayOf(DateTime.now());

  /// Stable `yyyy-mm-dd` key for storage and comparison.
  static String key(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  static Level build(DateTime day) {
    final ordinal = day.year * 10000 + day.month * 100 + day.day;
    return const LevelGenerator().generateTuned(
      rows: rows,
      cols: cols,
      targetArrows: arrows,
      maxStack: maxStack,
      hardness: hardness,
      seed: 0x5BF03635 ^ (ordinal * 2246822519),
    );
  }
}
