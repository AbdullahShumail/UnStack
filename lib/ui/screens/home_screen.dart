import 'package:flutter/material.dart';

import '../../state/level_ref.dart';
import '../../state/progress_store.dart';
import '../../theme/palette.dart';
import '../widgets/coin_pill.dart';
import '../widgets/floating_arrows.dart';
import '../widgets/wordmark.dart';
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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Palette.pageGradient),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _Enter(delay: 0, child: CoinPill(coins: store.coins)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      const _Enter(delay: 60, child: Wordmark(size: 42)),
                      const SizedBox(height: 10),
                      _Enter(
                        delay: 120,
                        child: Text(
                          'Clear the board, one arrow at a time',
                          textAlign: TextAlign.center,
                          style: Palette.ui(
                            13,
                            weight: FontWeight.w500,
                            color: Palette.textDim,
                          ),
                        ),
                      ),
                      // The drift sits under the name, filling whatever space
                      // the layout has left rather than a fixed band.
                      const Expanded(child: FloatingArrows()),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _Enter(
                        delay: 190,
                        child: _PlayCard(
                          label: store.currentLevel == 0 ? 'Play' : 'Continue',
                          detail: 'Level ${store.currentLevel + 1}',
                          onTap: () =>
                              _open(context, CampaignRef(store.currentLevel)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Enter(
                        delay: 250,
                        child: _DailyCard(
                          done: store.dailyDoneToday,
                          streak: store.streak,
                          onTap: () => _open(context, DailyRef.today()),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Enter(delay: 310, child: _Stats(store: store)),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Staggered fade-and-rise, so the screen assembles instead of appearing.
class _Enter extends StatelessWidget {
  const _Enter({required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = 460 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _PlayCard extends StatelessWidget {
  const _PlayCard({
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: Palette.primaryGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.14),
              blurRadius: 34,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Palette.display(23).copyWith(color: Palette.bg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: Palette.ui(
                      13,
                      color: Palette.bg.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow_rounded, color: Palette.bg, size: 32),
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
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        decoration: BoxDecoration(
          gradient: Palette.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                done ? Palette.healthFull.withValues(alpha: 0.5) : Palette.edge,
          ),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.bolt_rounded,
              color: done ? Palette.healthFull : Palette.hint,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Challenge', style: Palette.ui(16)),
                  const SizedBox(height: 2),
                  Text(
                    done ? 'Solved today' : 'Same board for everyone',
                    style: Palette.ui(
                      12,
                      weight: FontWeight.w500,
                      color: Palette.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (streak > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: Color(0xFFFB923C), size: 19),
                  const SizedBox(width: 2),
                  Text(
                    '$streak',
                    style: Palette.ui(
                      16,
                      weight: FontWeight.w700,
                      color: const Color(0xFFFB923C),
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

class _Stats extends StatelessWidget {
  const _Stats({required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(value: '${store.levelsCleared}', label: 'CLEARED'),
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
              Icon(icon, size: 16, color: Palette.textDim),
              const SizedBox(width: 4),
            ],
            Text(value, style: Palette.display(19)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Palette.ui(
            9,
            weight: FontWeight.w600,
            color: Palette.textDim,
            spacing: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Taps scale the card down slightly — the tactile cue phones have trained
/// people to expect from a primary action.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
