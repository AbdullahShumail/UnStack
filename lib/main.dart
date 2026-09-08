import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state/progress_store.dart';
import 'state/sfx.dart';
import 'theme/palette.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await ProgressStore.load();
  // A streak that lapsed while the app was closed should read zero on launch,
  // not the stale number from the last session.
  await store.refreshStreak();
  // Decoding the clips up front keeps the first launch of a level from
  // stuttering while audio initialises. Failures are swallowed inside Sfx: a
  // device without working audio must still play the game.
  unawaited(Sfx.instance.warmUp());
  runApp(UnstackApp(store: store));
}

class UnstackApp extends StatelessWidget {
  const UnstackApp({super.key, required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UnStack',
      debugShowCheckedModeBanner: false,
      theme: Palette.theme,
      home: HomeScreen(store: store),
    );
  }
}
