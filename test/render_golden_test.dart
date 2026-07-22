import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shikaku_game/services/ads_service.dart';
import 'package:shikaku_game/services/analytics_service.dart';
import 'package:shikaku_game/state/app_scope.dart';
import 'package:shikaku_game/state/game_controller.dart';
import 'package:shikaku_game/state/settings_controller.dart';
import 'package:shikaku_game/theme/app_theme.dart';
import 'package:shikaku_game/ui/screens/game_screen.dart';

/// Renders the real GameScreen at the benchmark's aspect ratio so the UI can be
/// eyeballed against the reference video. Run with `--update-goldens` to emit
/// the PNGs under test/goldens/.
void main() {
  testWidgets('game screen renders (dark, mid-solve)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsController();
    final ads = AdsService();
    final analytics = AnalyticsService();
    final game = GameController(2)..hapticsEnabled = false;

    await tester.pumpWidget(
      AppScope(
        settings: settings,
        game: game,
        ads: ads,
        analytics: analytics,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(Brightness.dark),
          home: const GameScreen(),
        ),
      ),
    );

    // Reveal a few solution rectangles to show colours + numbers.
    final solution = game.puzzle.solution;
    for (var i = 0; i < solution.length && i < 4; i++) {
      final r = solution[i];
      game.startDrag(r.row, r.col);
      game.updateDrag(r.bottom - 1, r.right - 1);
      game.endDrag();
    }
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game_dark.png'),
    );
  });

  testWidgets('game screen renders (light, empty)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsController();
    final ads = AdsService();
    final analytics = AnalyticsService();
    final game = GameController(2)..hapticsEnabled = false;

    await tester.pumpWidget(
      AppScope(
        settings: settings,
        game: game,
        ads: ads,
        analytics: analytics,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(Brightness.light),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game_light.png'),
    );
  });
}
