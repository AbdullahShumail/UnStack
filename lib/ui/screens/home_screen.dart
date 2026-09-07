import 'package:flutter/material.dart';

import '../../state/level_ref.dart';
import '../../state/progress_store.dart';
import '../../theme/palette.dart';
import '../widgets/coin_pill.dart';
import 'game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final ProgressStore store;

  Future<void> _open(BuildContext context, LevelRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(store: store, initial: ref),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [CoinPill(coins: store.coins)],
                ),
                const Spacer(flex: 2),
                const Text(
                  'UnStack',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Palette.text,
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Clear the board, one arrow at a time',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.textDim, fontSize: 14),
                ),
                const Spacer(flex: 2),
                _PrimaryCard(
                  label: store.currentLevel == 0 ? 'Play' : 'Continue',
                  detail: 'Level ${store.currentLevel + 1}',
                  onTap: () => _open(context, CampaignRef(store.currentLevel)),
                ),
                const SizedBox(height: 14),
                _DailyCard(
                  done: store.dailyDoneToday,
                  streak: store.streak,
                  onTap: () => _open(context, DailyRef.today()),
                ),
                const Spacer(flex: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(
                      value: '${store.levelsCleared}',
                      label: 'CLEARED',
                    ),
                    _Stat(
                      value: '${store.totalStars}',
                      label: 'STARS',
                      icon: Icons.star_rounded,
                    ),
                    _Stat(
                      value: '${store.bestStreak}',
                      label: 'BEST STREAK',
                      icon: Icons.local_fire_department_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: Palette.arrow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Palette.bg,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    detail,
                    style: TextStyle(
                      color: Palette.bg.withValues(alpha: 0.62),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow_rounded,
                color: Palette.bg, size: 34),
          ],
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.done,
    required this.streak,
    required this.onTap,
  });

  final bool done;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done ? Palette.healthFull : Palette.edge,
          ),
        ),
        child: Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.calendar_today_rounded,
              color: done ? Palette.healthFull : Palette.hint,
              size: 26,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Challenge',
                    style: TextStyle(
                      color: Palette.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    done ? 'Solved today' : 'Same board for everyone',
                    style: const TextStyle(
                      color: Palette.textDim,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (streak > 0)
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: Color(0xFFFB923C), size: 20),
                  const SizedBox(width: 2),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      color: Color(0xFFFB923C),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: Palette.textDim),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(
                color: Palette.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Palette.textDim,
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
