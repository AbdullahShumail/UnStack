import 'package:flutter/material.dart';

import '../../state/game_controller.dart';
import '../../state/level_ref.dart';
import '../../state/progress_store.dart';
import '../../theme/palette.dart';
import '../widgets/board_view.dart';
import '../widgets/board_backdrop.dart';
import '../widgets/coin_pill.dart';
import '../widgets/health_bar.dart';
import '../widgets/level_clock.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.store, required this.initial});

  final ProgressStore store;
  final LevelRef initial;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _game = GameController(
    store: widget.store,
    ref: widget.initial,
  );

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  Future<void> _hint() async {
    final denial = await _game.useHint();
    if (denial == HintDenial.broke && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.surface,
            content: Text(
              'Need ${ProgressStore.hintCost} coins for another hint.',
              style: const TextStyle(color: Palette.text),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_game, widget.store]),
          builder: (context, _) => Column(
            children: [
              _Hud(game: _game, store: widget.store),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: BoardBackdrop(
                        intensity: _game.arrowsTotal == 0
                            ? 0
                            : _game.arrowsLeft / _game.arrowsTotal,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: BoardView(controller: _game),
                    ),
                    if (_game.won) _WinOverlay(game: _game),
                    if (_game.failed) _FailOverlay(game: _game),
                  ],
                ),
              ),
              _Controls(game: _game, onHint: _hint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.store});

  final GameController game;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: Palette.textDim,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.isTimed ? 'TIMED CHALLENGE' : game.ref.subtitle,
                  style: TextStyle(
                    color: game.isTimed ? Palette.hint : Palette.textDim,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text(
                      game.ref.title,
                      style: const TextStyle(
                        color: Palette.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${game.arrowsLeft}',
                      style: const TextStyle(
                        color: Palette.textDim,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (game.isTimed)
                LevelClock(
                  secondsLeft: game.secondsLeft,
                  secondsTotal: game.secondsTotal,
                  urgent: game.isUrgent,
                )
              else
                CoinPill(coins: store.coins),
              const SizedBox(height: 7),
              HealthBar(
                health: game.health,
                max: GameController.maxHealth,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.game, required this.onHint});

  final GameController game;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Button(
            icon: Icons.undo_rounded,
            label: 'Undo',
            enabled: game.canUndo && !game.failed,
            onTap: game.undo,
          ),
          _Button(
            icon: Icons.lightbulb_outline_rounded,
            label: game.hintIsFree ? 'Free' : '${ProgressStore.hintCost}',
            enabled: game.canHint,
            tint: Palette.hint,
            onTap: onHint,
          ),
          _Button(
            icon: Icons.refresh_rounded,
            label: 'Restart',
            enabled: true,
            onTap: game.restart,
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? (tint ?? Palette.text) : Palette.textDim;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.edge),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared fade-and-rise entrance for the end-of-run overlays.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Container(
          color: Palette.bg.withValues(alpha: 0.94 * t),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 26),
            child: child,
          ),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _WinOverlay extends StatelessWidget {
  const _WinOverlay({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      children: [
        const Text(
          'Cleared',
          style: TextStyle(
            color: Palette.text,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                i < game.stars ? Icons.star_rounded : Icons.star_border_rounded,
                color: i < game.stars ? Palette.hint : Palette.textDim,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (game.payout > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Palette.hint, size: 19),
              const SizedBox(width: 6),
              Text(
                '+${game.payout}',
                style: const TextStyle(
                  color: Palette.hint,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          )
        else
          const Text(
            'Already solved today',
            style: TextStyle(color: Palette.textDim, fontSize: 14),
          ),
        const SizedBox(height: 26),
        _PrimaryAction(
          label: game.isDaily ? 'Done' : 'Next level',
          onTap: game.isDaily
              ? () => Navigator.of(context).maybePop()
              : game.nextLevel,
        ),
      ],
    );
  }
}

class _FailOverlay extends StatelessWidget {
  const _FailOverlay({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      children: [
        Text(
          game.isTimed && game.secondsLeft <= 0 ? "Time's up" : 'Out of health',
          style: const TextStyle(
            color: Palette.healthLow,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${game.arrowsLeft} arrows left',
          style: const TextStyle(color: Palette.textDim, fontSize: 14),
        ),
        const SizedBox(height: 26),
        // TODO(ads): gate this behind a rewarded ad once google_mobile_ads
        // is wired up. Free revive is a placeholder so the loop is playable.
        _PrimaryAction(
          label: 'Continue  ▶',
          onTap: game.reviveWithHealth,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: game.restart,
          child: const Text(
            'Restart level',
            style: TextStyle(color: Palette.textDim, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Palette.arrow,
        foregroundColor: Palette.bg,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
