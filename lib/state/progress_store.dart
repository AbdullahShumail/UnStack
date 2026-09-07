import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily.dart';

/// Everything that survives a relaunch.
///
/// Only outcomes are stored — never boards. A level is rebuilt from its seed,
/// so the whole save file stays a few hundred bytes no matter how far someone
/// plays.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs);

  static const _kLevel = 'campaign.level';
  static const _kStars = 'campaign.stars';
  static const _kCoins = 'wallet.coins';
  static const _kStreak = 'daily.streak';
  static const _kLastDaily = 'daily.last';
  static const _kBestStreak = 'daily.bestStreak';

  /// What a solve pays, by star rating. Clean solves are worth chasing.
  static const coinsByStars = [0, 10, 20, 30];

  /// Daily solves pay a base plus a streak bonus, capped so a long streak
  /// stays motivating without making hints free forever.
  static const dailyBaseReward = 50;
  static const dailyStreakBonus = 10;
  static const dailyStreakBonusCap = 7;

  static const hintCost = 25;

  /// Enough to try a few hints before the economy starts to bite.
  static const _startingCoins = 60;

  final SharedPreferences _prefs;
  Map<String, int> _stars = {};

  static Future<ProgressStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProgressStore._(prefs);
    store._readStars();
    if (!prefs.containsKey(_kCoins)) {
      await prefs.setInt(_kCoins, _startingCoins);
    }
    return store;
  }

  void _readStars() {
    final raw = _prefs.getString(_kStars);
    if (raw == null || raw.isEmpty) {
      _stars = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _stars = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } on FormatException {
      // A corrupt save should cost progress, not crash the app on launch.
      _stars = {};
    }
  }

  Future<void> _writeStars() =>
      _prefs.setString(_kStars, jsonEncode(_stars));

  // ---------------------------------------------------------------- campaign

  /// The next campaign level to play.
  int get currentLevel => _prefs.getInt(_kLevel) ?? 0;

  /// Stars earned on a campaign level, 0 if never cleared.
  int starsFor(int level) => _stars['c$level'] ?? 0;

  bool isCleared(int level) => _stars.containsKey('c$level');

  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  int get levelsCleared => _stars.length;

  /// Records a campaign result. Stars only ever improve, and the campaign
  /// pointer only moves forward, so replaying an old level cannot cost
  /// progress.
  Future<int> recordCampaignWin(int level, int stars) async {
    final key = 'c$level';
    final previous = _stars[key];
    final improved = previous == null || stars > previous;
    if (improved) {
      _stars[key] = stars;
      await _writeStars();
    }
    if (level >= currentLevel) {
      await _prefs.setInt(_kLevel, level + 1);
    }
    // Replays pay only the improvement, so a solved level is not a coin farm.
    final payout = previous == null
        ? coinsByStars[stars]
        : (coinsByStars[stars] - coinsByStars[previous]).clamp(0, 30);
    await addCoins(payout);
    notifyListeners();
    return payout;
  }

  // ------------------------------------------------------------------- daily

  int get streak => _prefs.getInt(_kStreak) ?? 0;

  int get bestStreak => _prefs.getInt(_kBestStreak) ?? 0;

  String? get lastDailyKey => _prefs.getString(_kLastDaily);

  bool get dailyDoneToday => lastDailyKey == Daily.key(Daily.today());

  int starsForDaily(DateTime day) => _stars['d${Daily.key(day)}'] ?? 0;

  /// Records a daily result and advances or resets the streak.
  ///
  /// Solving yesterday's board today does not extend a streak — only the
  /// current day's puzzle counts, which is the whole point of a daily.
  Future<int> recordDailyWin(DateTime day, int stars) async {
    final dayKey = Daily.key(Daily.dayOf(day));
    final todayKey = Daily.key(Daily.today());

    final starKey = 'd$dayKey';
    final previous = _stars[starKey];
    if (previous == null || stars > previous) {
      _stars[starKey] = stars;
      await _writeStars();
    }

    var payout = 0;
    if (dayKey == todayKey && lastDailyKey != todayKey) {
      final yesterday = Daily.key(
        Daily.today().subtract(const Duration(days: 1)),
      );
      final continued = lastDailyKey == yesterday;
      final next = continued ? streak + 1 : 1;
      await _prefs.setInt(_kStreak, next);
      if (next > bestStreak) await _prefs.setInt(_kBestStreak, next);
      await _prefs.setString(_kLastDaily, todayKey);

      final bonus =
          dailyStreakBonus * next.clamp(0, dailyStreakBonusCap);
      payout = dailyBaseReward + bonus;
      await addCoins(payout);
    }
    notifyListeners();
    return payout;
  }

  /// Zeroes a streak that has already lapsed, so the UI never shows a stale
  /// number. Safe to call on every launch.
  Future<void> refreshStreak() async {
    final last = lastDailyKey;
    if (last == null || streak == 0) return;
    final today = Daily.key(Daily.today());
    final yesterday = Daily.key(
      Daily.today().subtract(const Duration(days: 1)),
    );
    if (last != today && last != yesterday) {
      await _prefs.setInt(_kStreak, 0);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ wallet

  int get coins => _prefs.getInt(_kCoins) ?? _startingCoins;

  bool get canAffordHint => coins >= hintCost;

  Future<void> addCoins(int amount) async {
    if (amount == 0) return;
    await _prefs.setInt(_kCoins, coins + amount);
    notifyListeners();
  }

  /// Spends [amount] if the wallet covers it. Returns false when it does not.
  Future<bool> spend(int amount) async {
    if (coins < amount) return false;
    await _prefs.setInt(_kCoins, coins - amount);
    notifyListeners();
    return true;
  }

  @visibleForTesting
  Future<void> reset() async {
    await _prefs.clear();
    _stars = {};
    await _prefs.setInt(_kCoins, _startingCoins);
    notifyListeners();
  }
}
