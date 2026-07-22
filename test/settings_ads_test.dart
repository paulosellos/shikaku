import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shikaku_game/state/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('interstitial triggers every 3 puzzle wins', () async {
    final settings = SettingsController();
    await settings.load();

    expect(settings.shouldShowInterstitial, isFalse);

    settings.recordPuzzleWin();
    expect(settings.shouldShowInterstitial, isFalse);

    settings.recordPuzzleWin();
    expect(settings.shouldShowInterstitial, isFalse);

    settings.recordPuzzleWin();
    expect(settings.shouldShowInterstitial, isTrue);

    settings.recordPuzzleWin();
    expect(settings.shouldShowInterstitial, isFalse);
  });

  test('ad-free users skip interstitials', () async {
    final settings = SettingsController();
    await settings.load();
    settings.setAdFree(true);

    settings.recordPuzzleWin();
    settings.recordPuzzleWin();
    settings.recordPuzzleWin();
    expect(settings.shouldShowInterstitial, isFalse);
  });
}
