import 'package:flutter/foundation.dart';

/// AdMob app and unit IDs. Debug builds use Google test units.
abstract final class AdsConfig {
  /// Shikaku Puzzle — from AdMob console.
  static const androidAppId = 'ca-app-pub-8370960272492509~4481902531';

  /// interstitial-v0 production unit.
  static const productionInterstitialUnitId =
      'ca-app-pub-8370960272492509/8640639397';

  /// No rewarded unit in AdMob yet — test ID until one is created.
  static const rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

  static const testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static const testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static bool get useTestAds => kDebugMode;

  static String interstitialAdUnitId() =>
      useTestAds ? testInterstitialUnitId : productionInterstitialUnitId;

  static String rewardedAdUnitId() =>
      useTestAds ? testRewardedUnitId : rewardedUnitId;

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
