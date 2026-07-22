import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'settings_controller.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';

/// Exposes the shared controllers to the widget tree without extra packages.
class AppScope extends InheritedWidget {
  final GameController game;
  final SettingsController settings;
  final AdsService ads;
  final AnalyticsService analytics;

  const AppScope({
    super.key,
    required this.game,
    required this.settings,
    required this.ads,
    required this.analytics,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      game != oldWidget.game ||
      settings != oldWidget.settings ||
      ads != oldWidget.ads ||
      analytics != oldWidget.analytics;
}
