import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../analytics/analytics_events.dart';
import '../firebase_options.dart';
import '../models/puzzle_difficulty.dart';

/// Thin wrapper around Firebase Analytics with safe no-op fallback.
class AnalyticsService {
  FirebaseAnalytics? _analytics;
  bool _enabled = false;

  bool get isEnabled => _enabled;

  Future<void> initialize() async {
    if (_enabled) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _analytics = FirebaseAnalytics.instance;
      _enabled = true;
    } catch (e) {
      debugPrint('Analytics disabled: $e');
    }
  }

  Future<void> setAdFree(bool value) async {
    await _setUserProperty('is_ad_free', value ? 'true' : 'false');
  }

  Future<void> logAppOpen() => _log(AnalyticsEvents.appOpen, {
        AnalyticsEvents.platform: _platformName,
      });

  Future<void> logSplashCompleted() =>
      _log(AnalyticsEvents.splashCompleted, const {});

  Future<void> logHomeViewed({
    required PuzzleDifficulty lastDifficulty,
    required int lastLevel,
  }) =>
      _log(AnalyticsEvents.homeViewed, {
        AnalyticsEvents.lastDifficulty: lastDifficulty.name,
        AnalyticsEvents.lastLevel: lastLevel,
      });

  Future<void> logDifficultySelected(PuzzleDifficulty difficulty) =>
      _log(AnalyticsEvents.difficultySelected, {
        AnalyticsEvents.difficulty: difficulty.name,
      });

  Future<void> logPlayTapped({
    required PuzzleDifficulty difficulty,
    required int level,
    required String source,
  }) =>
      _log(AnalyticsEvents.playTapped, {
        AnalyticsEvents.difficulty: difficulty.name,
        AnalyticsEvents.level: level,
        AnalyticsEvents.source: source,
      });

  Future<void> logSettingsOpened(String source) =>
      _log(AnalyticsEvents.settingsOpened, {
        AnalyticsEvents.source: source,
      });

  Future<void> logGameStarted({
    required PuzzleDifficulty difficulty,
    required int level,
    required int boardSize,
  }) =>
      _log(AnalyticsEvents.gameStarted, {
        AnalyticsEvents.difficulty: difficulty.name,
        AnalyticsEvents.level: level,
        AnalyticsEvents.boardSize: boardSize,
      });

  Future<void> logPuzzleCompleted({
    required PuzzleDifficulty difficulty,
    required int level,
    required int elapsedSec,
    required int hintsUsed,
    required int wandUsed,
    required int undoCount,
    required String winVariant,
    required bool flawless,
  }) =>
      _log(AnalyticsEvents.puzzleCompleted, {
        AnalyticsEvents.difficulty: difficulty.name,
        AnalyticsEvents.level: level,
        AnalyticsEvents.elapsedSec: elapsedSec,
        AnalyticsEvents.hintsUsed: hintsUsed,
        AnalyticsEvents.wandUsedCount: wandUsed,
        AnalyticsEvents.undoCount: undoCount,
        AnalyticsEvents.winVariant: winVariant,
        AnalyticsEvents.flawless: flawless ? 1 : 0,
      });

  Future<void> logPuzzleAbandoned({
    required PuzzleDifficulty difficulty,
    required int level,
    required int elapsedSec,
  }) =>
      _log(AnalyticsEvents.puzzleAbandoned, {
        AnalyticsEvents.difficulty: difficulty.name,
        AnalyticsEvents.level: level,
        AnalyticsEvents.elapsedSec: elapsedSec,
      });

  Future<void> logHintUsed({
    required int hintsRemaining,
    required int ghostCount,
  }) =>
      _log(AnalyticsEvents.hintUsed, {
        AnalyticsEvents.hintsRemaining: hintsRemaining,
        AnalyticsEvents.ghostCount: ghostCount,
      });

  Future<void> logWandUsed({required int wandsRemaining}) =>
      _log(AnalyticsEvents.wandUsed, {
        AnalyticsEvents.wandsRemaining: wandsRemaining,
      });

  Future<void> logUndoUsed({required int undoCount}) =>
      _log(AnalyticsEvents.undoUsed, {
        AnalyticsEvents.undoCount: undoCount,
      });

  Future<void> logPowerupDepleted(String type) =>
      _log(AnalyticsEvents.powerupDepleted, {
        AnalyticsEvents.type: type,
      });

  Future<void> logRewardedAdOffered({
    required String type,
    required int rewardAmount,
  }) =>
      _log(AnalyticsEvents.rewardedAdOffered, {
        AnalyticsEvents.type: type,
        AnalyticsEvents.rewardAmount: rewardAmount,
      });

  Future<void> logRewardedAdCompleted({
    required String type,
    required int rewardAmount,
  }) =>
      _log(AnalyticsEvents.rewardedAdCompleted, {
        AnalyticsEvents.type: type,
        AnalyticsEvents.rewardAmount: rewardAmount,
      });

  Future<void> logRewardedAdDismissed(String type) =>
      _log(AnalyticsEvents.rewardedAdDismissed, {
        AnalyticsEvents.type: type,
      });

  Future<void> logInterstitialShown({required int puzzlesCompleted}) =>
      _log(AnalyticsEvents.interstitialShown, {
        AnalyticsEvents.puzzlesCompleted: puzzlesCompleted,
      });

  Future<void> logInterstitialDismissed() =>
      _log(AnalyticsEvents.interstitialDismissed, const {});

  Future<void> logStoreOpened(String source) =>
      _log(AnalyticsEvents.storeOpened, {
        AnalyticsEvents.source: source,
      });

  Future<void> logPurchaseStarted({required String sku, String? price}) =>
      _log(AnalyticsEvents.purchaseStarted, {
        AnalyticsEvents.sku: sku,
        if (price != null) AnalyticsEvents.price: price,
      });

  Future<void> logPurchaseCompleted({required String sku, String? price}) =>
      _log(AnalyticsEvents.purchaseCompleted, {
        AnalyticsEvents.sku: sku,
        if (price != null) AnalyticsEvents.price: price,
      });

  Future<void> logPurchaseFailed({required String sku, String? errorCode}) =>
      _log(AnalyticsEvents.purchaseFailed, {
        AnalyticsEvents.sku: sku,
        if (errorCode != null) AnalyticsEvents.errorCode: errorCode,
      });

  Future<void> logRestorePurchases({required int restoredCount}) =>
      _log(AnalyticsEvents.restorePurchases, {
        AnalyticsEvents.restoredCount: restoredCount,
      });

  Future<void> logLeaderboardOpened() =>
      _log(AnalyticsEvents.leaderboardOpened, const {});

  Future<void> _log(String name, Map<String, Object> params) async {
    if (!_enabled || _analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics event failed ($name): $e');
    }
  }

  Future<void> _setUserProperty(String name, String value) async {
    if (!_enabled || _analytics == null) return;
    try {
      await _analytics!.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics user property failed ($name): $e');
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }
}
