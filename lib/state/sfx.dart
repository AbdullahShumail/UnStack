import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The game's sound effects.
///
/// Each clip gets its own player so a launch never cuts off the tick before
/// it, and players are reused rather than created per shot — allocating one
/// on every tap is what makes mobile audio stutter.
///
/// Every call is fire-and-forget and swallows failures. An emulator without a
/// working audio device, or a phone mid-call, must never take the game down
/// over a sound effect.
class Sfx {
  Sfx._();

  static final Sfx instance = Sfx._();

  static const _swoosh = 'sfx/swoosh.wav';
  static const _tick = 'sfx/tick.wav';
  static const _tickUrgent = 'sfx/tick_urgent.wav';
  static const _error = 'sfx/error.wav';
  static const _clear = 'sfx/clear.wav';

  final Map<String, AudioPlayer> _players = {};

  /// Silences every effect. Left public so a settings toggle can flip it.
  bool muted = false;

  Future<void> warmUp() async {
    for (final asset in [_swoosh, _tick, _tickUrgent, _error, _clear]) {
      await _playerFor(asset);
    }
  }

  Future<AudioPlayer> _playerFor(String asset) async {
    final existing = _players[asset];
    if (existing != null) return existing;
    final player = AudioPlayer()
      ..setReleaseMode(ReleaseMode.stop)
      ..setPlayerMode(PlayerMode.lowLatency);
    try {
      await player.setSource(AssetSource(asset));
    } on Object catch (e) {
      debugPrint('Sfx: could not load $asset ($e)');
    }
    _players[asset] = player;
    return player;
  }

  Future<void> _play(String asset, {double volume = 1}) async {
    if (muted) return;
    try {
      final player = await _playerFor(asset);
      await player.stop();
      await player.setVolume(volume);
      await player.resume();
    } on Object catch (e) {
      debugPrint('Sfx: could not play $asset ($e)');
    }
  }

  /// An arrow leaving the board.
  void swoosh() => _play(_swoosh, volume: 0.85);

  /// A blocked arrow hitting what is in its way.
  void blocked() => _play(_error, volume: 0.75);

  /// The board cleared.
  void cleared() => _play(_clear, volume: 0.6);

  /// One second passing on a timed level.
  void tick({bool urgent = false}) =>
      _play(urgent ? _tickUrgent : _tick, volume: urgent ? 0.9 : 0.45);

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}
