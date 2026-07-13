import 'package:flutter/material.dart';

import 'state/app_scope.dart';
import 'state/game_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';
import 'ui/screens/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  await settings.load();
  final game = GameController(settings.currentLevel)
    ..hapticsEnabled = settings.haptics;
  runApp(ShikakuApp(settings: settings, game: game));
}

class ShikakuApp extends StatelessWidget {
  final SettingsController settings;
  final GameController game;

  const ShikakuApp({super.key, required this.settings, required this.game});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return AppScope(
          settings: settings,
          game: game,
          child: MaterialApp(
            title: 'Shikaku',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.build(Brightness.light),
            darkTheme: AppTheme.build(Brightness.dark),
            home: const GameScreen(),
          ),
        );
      },
    );
  }
}
