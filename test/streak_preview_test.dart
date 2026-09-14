// Renders the streak badge at every tier to PNGs so the fire can be checked
// by eye without playing two hundred clean arrows. Output lands in the
// scratchpad, not the repo. Run on demand:
//
//   flutter test test/streak_preview_test.dart
//
// It is skipped by default so it never slows or clutters a normal run.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unstack/theme/palette.dart';
import 'package:unstack/ui/widgets/streak_badge.dart';

void main() {
  final out = Platform.environment['STREAK_PREVIEW_DIR'];

  testWidgets(
    'render every streak tier',
    (tester) async {
      final dir = Directory(out!)..createSync(recursive: true);
      final key = GlobalKey();

      // A row of badges, one per tier, on the real background.
      await tester.pumpWidget(
        MaterialApp(
          theme: Palette.theme,
          home: RepaintBoundary(
            key: key,
            child: Container(
              color: Palette.bg,
              padding: const EdgeInsets.all(24),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StreakBadge(streak: 12, height: 44),
                  StreakBadge(streak: 35, height: 44),
                  StreakBadge(streak: 64, height: 44),
                  StreakBadge(streak: 128, height: 44),
                  StreakBadge(streak: 256, height: 44),
                ],
              ),
            ),
          ),
        ),
      );

      // Advance the flicker so the flames are mid-motion, not at t=0.
      await tester.pump(const Duration(milliseconds: 900));

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/streak_tiers.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    },
    skip: out == null,
  );
}
