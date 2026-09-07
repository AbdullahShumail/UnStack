import 'package:flutter/material.dart';

/// Black ground, white line-art arrows.
///
/// The board carries no tiles or chrome, so contrast does all the work: the
/// only bright thing on screen is an arrow.
class Palette {
  const Palette._();

  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF111111);
  static const edge = Color(0xFF262626);

  static const arrow = Color(0xFFFFFFFF);

  /// Arrows buried under a stack. Dim enough to read as "behind", never bright
  /// enough to compete with the live arrow on top.
  static const arrowGhost = Color(0x33FFFFFF);

  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFF8A8A8A);

  static const hint = Color(0xFFFACC15);

  static const healthFull = Color(0xFF4ADE80);
  static const healthMid = Color(0xFF38BDF8);
  static const healthLow = Color(0xFFF43F5E);

  /// Health runs green while comfortable, blue as a warning, red on the last
  /// one left.
  static Color health(int remaining) => switch (remaining) {
        >= 3 => healthFull,
        2 => healthMid,
        _ => healthLow,
      };

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          surface: surface,
          primary: Color(0xFFFFFFFF),
          onPrimary: Color(0xFF000000),
        ),
        fontFamily: 'Roboto',
      );
}
