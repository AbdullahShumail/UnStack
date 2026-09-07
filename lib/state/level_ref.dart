import '../engine/level.dart';
import 'chapters.dart';
import 'daily.dart';

/// Identifies a puzzle without holding one.
///
/// Levels are generated on demand from a seed, so a reference is all that ever
/// needs to be stored, passed around, or restored from disk.
sealed class LevelRef {
  const LevelRef();

  Level build();

  /// Heading shown above the board.
  String get title;

  /// Smaller label above the title.
  String get subtitle;
}

class CampaignRef extends LevelRef {
  const CampaignRef(this.index);

  final int index;

  @override
  Level build() => Chapters.build(index);

  @override
  String get title => 'Level ${index + 1}';

  @override
  String get subtitle => Chapters.locate(index).spec.name.toUpperCase();

  CampaignRef get next => CampaignRef(index + 1);
}

class DailyRef extends LevelRef {
  DailyRef(DateTime day) : day = Daily.dayOf(day);

  DailyRef.today() : day = Daily.today();

  final DateTime day;

  String get key => Daily.key(day);

  @override
  Level build() => Daily.build(day);

  @override
  String get title => 'Daily Challenge';

  @override
  String get subtitle => key;
}
