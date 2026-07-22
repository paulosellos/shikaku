import 'package:flutter/material.dart';

import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'state/app_scope.dart';
import 'state/game_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  await settings.load();
  final analytics = AnalyticsService();
  await analytics.initialize();
  await analytics.logAppOpen();
  await analytics.setAdFree(false);
  final ads = AdsService();
  await ads.initialize();
  final game = GameController(
    settings.levelFor(settings.lastDifficulty),
    difficulty: settings.lastDifficulty,
  )..hapticsEnabled = settings.haptics;
  runApp(ShikakuApp(
    settings: settings,
    game: game,
    ads: ads,
    analytics: analytics,
  ));
}

class ShikakuApp extends StatelessWidget {
  final SettingsController settings;
  final GameController game;
  final AdsService ads;
  final AnalyticsService analytics;

  const ShikakuApp({
    super.key,
    required this.settings,
    required this.game,
    required this.ads,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return AppScope(
          settings: settings,
          game: game,
          ads: ads,
          analytics: analytics,
          child: MaterialApp(
            title: 'Shikaku',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.build(Brightness.light),
            darkTheme: AppTheme.build(Brightness.dark),
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
