import 'package:flutter/material.dart';

/// Black ground, white line-art arrows.
///
/// The board carries no tiles or chrome, so contrast does all the work: the
/// only bright thing on screen is an arrow. Gradients are kept very shallow —
/// enough to give the black some depth, never enough to read as grey.
class Palette {
  const Palette._();

  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF101012);
  static const edge = Color(0xFF232326);

  static const arrow = Color(0xFFFFFFFF);

  /// Arrows buried under a stack. Dim enough to read as "behind", never bright
  /// enough to compete with the live arrow on top.
  static const arrowGhost = Color(0x30FFFFFF);

  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFF8A8A90);

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

  // ------------------------------------------------------------- gradients

  /// Page ground. Lifts the top of the screen just off pure black so the
  /// layout has somewhere to sit.
  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0C0C10), Color(0xFF000000), Color(0xFF000000)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Soft light behind the hero animation.
  static const heroGlow = RadialGradient(
    colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
  );

  /// Bright face of the primary button.
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFD9D9E0)],
  );

  /// Secondary card face — barely there, but it separates from the ground.
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF17171B), Color(0xFF0D0D10)],
  );

  /// Applied to hero arrows so they catch light across their length.
  static Shader arrowShader(Rect bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFF9A9AA5)],
      ).createShader(bounds);

  // ------------------------------------------------------------------ type

  /// Bundled with the app, so the first launch renders correctly offline.
  static const family = 'SpaceGrotesk';

  static TextStyle display(double size, {FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        color: text,
        height: 1.05,
      );

  static TextStyle ui(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = text,
    double spacing = 0,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          surface: surface,
          primary: Color(0xFFFFFFFF),
          onPrimary: Color(0xFF000000),
        ),
        fontFamily: family,
        textTheme: ThemeData(brightness: Brightness.dark)
            .textTheme
            .apply(fontFamily: family),
      );
}
