import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unstack/state/daily.dart';
import 'package:unstack/state/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await ProgressStore.load();
  });

  String dayKey(int daysAgo) => Daily.key(
        Daily.today().subtract(Duration(days: daysAgo)),
      );

  group('Campaign progress', () {
    test('clearing a level advances the pointer and pays out', () async {
      final before = store.coins;
      final paid = await store.recordCampaignWin(0, 3);
      expect(paid, ProgressStore.coinsByStars[3]);
      expect(store.coins, before + paid);
      expect(store.currentLevel, 1);
      expect(store.starsFor(0), 3);
    });

    test('replaying a cleared level only pays the improvement', () async {
      await store.recordCampaignWin(0, 1);
      final afterFirst = store.coins;

      // Same result again earns nothing.
      expect(await store.recordCampaignWin(0, 1), 0);
      expect(store.coins, afterFirst);

      // Improving from 1 star to 3 pays the difference, not the full amount.
      final improvement = await store.recordCampaignWin(0, 3);
      expect(
        improvement,
        ProgressStore.coinsByStars[3] - ProgressStore.coinsByStars[1],
      );
      expect(store.starsFor(0), 3);
    });

    test('a worse replay never lowers a stored star rating', () async {
      await store.recordCampaignWin(4, 3);
      await store.recordCampaignWin(4, 1);
      expect(store.starsFor(4), 3);
    });

    test('replaying an old level does not rewind the pointer', () async {
      await store.recordCampaignWin(0, 3);
      await store.recordCampaignWin(1, 3);
      expect(store.currentLevel, 2);
      await store.recordCampaignWin(0, 3);
      expect(store.currentLevel, 2);
    });
  });

  group('Daily streak', () {
    test('a first daily win starts the streak at one', () async {
      final paid = await store.recordDailyWin(Daily.today(), 3);
      expect(store.streak, 1);
      expect(store.dailyDoneToday, isTrue);
      expect(paid,
          ProgressStore.dailyBaseReward + ProgressStore.dailyStreakBonus);
    });

    test('solving on consecutive days extends the streak', () async {
      SharedPreferences.setMockInitialValues({
        'daily.streak': 4,
        'daily.last': dayKey(1),
        'wallet.coins': 0,
      });
      store = await ProgressStore.load();

      await store.recordDailyWin(Daily.today(), 2);
      expect(store.streak, 5);
      expect(store.bestStreak, 5);
    });

    test('a missed day resets the streak to one', () async {
      SharedPreferences.setMockInitialValues({
        'daily.streak': 9,
        'daily.bestStreak': 9,
        'daily.last': dayKey(3),
        'wallet.coins': 0,
      });
      store = await ProgressStore.load();

      await store.recordDailyWin(Daily.today(), 3);
      expect(store.streak, 1);
      // The record survives the reset.
      expect(store.bestStreak, 9);
    });

    test('solving twice in one day pays once and holds the streak', () async {
      await store.recordDailyWin(Daily.today(), 2);
      final afterFirst = store.coins;
      final second = await store.recordDailyWin(Daily.today(), 3);
      expect(second, 0);
      expect(store.coins, afterFirst);
      expect(store.streak, 1);
      // Stars still improve even though the payout does not repeat.
      expect(store.starsForDaily(Daily.today()), 3);
    });

    test('solving an old board does not extend the streak', () async {
      final old = Daily.today().subtract(const Duration(days: 5));
      final paid = await store.recordDailyWin(old, 3);
      expect(paid, 0);
      expect(store.streak, 0);
      expect(store.dailyDoneToday, isFalse);
      // The result is still recorded.
      expect(store.starsForDaily(old), 3);
    });

    test('refreshStreak zeroes a streak that already lapsed', () async {
      SharedPreferences.setMockInitialValues({
        'daily.streak': 6,
        'daily.last': dayKey(4),
      });
      store = await ProgressStore.load();
      await store.refreshStreak();
      expect(store.streak, 0);
    });

    test('refreshStreak leaves a live streak alone', () async {
      SharedPreferences.setMockInitialValues({
        'daily.streak': 6,
        'daily.last': dayKey(1),
      });
      store = await ProgressStore.load();
      await store.refreshStreak();
      expect(store.streak, 6);
    });

    test('the streak bonus is capped', () async {
      SharedPreferences.setMockInitialValues({
        'daily.streak': 40,
        'daily.last': dayKey(1),
        'wallet.coins': 0,
      });
      store = await ProgressStore.load();

      final paid = await store.recordDailyWin(Daily.today(), 3);
      expect(
        paid,
        ProgressStore.dailyBaseReward +
            ProgressStore.dailyStreakBonus *
                ProgressStore.dailyStreakBonusCap,
      );
    });
  });

  group('Wallet', () {
    test('spending more than the balance is refused', () async {
      final coins = store.coins;
      expect(await store.spend(coins + 1), isFalse);
      expect(store.coins, coins);
    });

    test('a corrupt star blob does not break loading', () async {
      SharedPreferences.setMockInitialValues({'campaign.stars': 'not json'});
      final recovered = await ProgressStore.load();
      expect(recovered.totalStars, 0);
      expect(recovered.levelsCleared, 0);
    });
  });

  group('Daily generation', () {
    test('the same day always produces the same board', () {
      final day = DateTime(2026, 9, 7);
      final a = Daily.build(day);
      final b = Daily.build(day);
      expect(a.placements.length, b.placements.length);
      for (var i = 0; i < a.placements.length; i++) {
        expect(a.placements[i].row, b.placements[i].row);
        expect(a.placements[i].col, b.placements[i].col);
        expect(a.placements[i].dir, b.placements[i].dir);
      }
    });

    test('different days produce different boards', () {
      final a = Daily.build(DateTime(2026, 9, 7));
      final b = Daily.build(DateTime(2026, 9, 8));
      final sameStart = a.placements.first.row == b.placements.first.row &&
          a.placements.first.col == b.placements.first.col &&
          a.placements.first.dir == b.placements.first.dir;
      expect(sameStart, isFalse);
    });

    test('a week of dailies are all solvable', () {
      for (var i = 0; i < 7; i++) {
        final level = Daily.build(DateTime(2026, 9, 1).add(Duration(days: i)));
        final board = level.toBoard();
        for (final step in level.solutionOrder) {
          expect(board.isLaunchable(step.row, step.col), isTrue);
          board.pop(step.row, step.col);
        }
        expect(board.isCleared, isTrue);
      }
    });
  });
}
