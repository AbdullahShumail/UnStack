# UnStack

A minimalist logic puzzle for Android and iOS, built with Flutter.

Tap an arrow and it flies off the board in the direction it points — but only if
its entire lane to the edge is clear. Cells hold *stacks*, and only the arrow on
top can move. Clearing it reveals what is underneath. The whole game is working
out the right order.

Black ground, white line-art, no chrome.

## How it works

### Levels are generated backwards

The generator runs the game in reverse. Starting from an empty board, it adds an
arrow only when that arrow's path to the edge is already clear. Replaying those
placements in reverse order is therefore always a valid solution: at the moment
arrow *i* is removed, the only arrows left are the ones placed before it, which
is exactly the board state its path was checked against.

Stacking comes for free. Pushing an arrow onto an occupied cell means it gets
removed *earlier* in the forward game, so it is always on top when its turn
comes.

Two properties follow, and both are verified by the test suite rather than
assumed:

- **Every generated level is solvable.**
- **The player can never get stuck.** Launching an arrow only ever frees space,
  so paths never become blocked. The highest-index remaining arrow is always
  launchable.

That second property is why hints are cheap: any legal move is safe, so a hint
never has to search for a *correct* move, only a legal one.

### Difficulty is measured, not guessed

Because every solution takes exactly one move per arrow and there are no dead
ends, difficulty cannot come from move count. It comes from how *few* legal
moves exist at each step.

The metric is the mean fraction of remaining arrows that are launchable —
board-size independent, unlike a raw count, and the thing a player actually
experiences when scanning the board. `tool/curve.dart` prints the measured
difficulty for every board configuration so the progression can be tuned against
real numbers.

### Nothing is stored

A level index hashes to a seed, and the generator rebuilds the identical board
every time. Content is effectively infinite at zero storage cost, and the daily
challenge is seeded from the calendar date alone — every player worldwide gets
the same board with no server involved.

The save file holds outcomes only: stars, coins, streak. A few hundred bytes no
matter how far you play.

## Running it

```bash
flutter pub get
flutter run
```

Requires Flutter 3.47+.

```bash
flutter test              # engine, progression and persistence
dart run tool/curve.dart  # measured difficulty per board config
dart run tool/levels.dart # the real progression, level by level
```

## Layout

```
lib/
  engine/     board rules, reverse generator, difficulty metric
  state/      progression, persistence, game controller
  ui/         board renderer and screens
  theme/      palette
test/         engine, controller and persistence suites
tool/         difficulty and progression analysis
```

The engine has no Flutter dependency and is tested in isolation.

## Status

Playable end to end: campaign progression, daily challenge with streaks, a coin
economy, hints, and health.

Not yet wired up:

- Rewarded ads — the "continue" on the fail screen currently revives for free
  (marked `TODO(ads)`)
- In-app purchases
- Sound
