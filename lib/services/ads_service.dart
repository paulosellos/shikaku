import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Loads and shows AdMob interstitial and rewarded ads (Android only for now).
class AdsService extends ChangeNotifier {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _initialized = false;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  bool get isSupported => AdsConfig.isSupportedPlatform;
  bool get isInitialized => _initialized;
  bool get isInterstitialReady => _interstitial != null;
  bool get isRewardedReady => _rewarded != null;

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
    _loadRewarded();
    notifyListeners();
  }

  void _loadInterstitial() {
    if (!isSupported || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _loadingInterstitial = false;
          notifyListeners();
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!isSupported || _loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdsConfig.rewardedAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _loadingRewarded = false;
          notifyListeners();
        },
      ),
    );
  }

  /// Shows a loaded interstitial. Returns when dismissed or if unavailable.
  Future<void> showInterstitialAd() async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissed) {
        dismissed.dispose();
        _interstitial = null;
        notifyListeners();
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (failed, error) {
        debugPrint('Interstitial failed to show: $error');
        failed.dispose();
        _interstitial = null;
        notifyListeners();
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );

    _interstitial = null;
    notifyListeners();
    await ad.show();
    return completer.future;
  }

  /// Shows a rewarded ad. Returns true if the user earned the reward.
  Future<bool> showRewardedAd() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissed) {
        dismissed.dispose();
        _rewarded = null;
        notifyListeners();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (failed, error) {
        debugPrint('Rewarded ad failed to show: $error');
        failed.dispose();
        _rewarded = null;
        notifyListeners();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewarded = null;
    notifyListeners();
    await ad.show(
      onUserEarnedReward: (_, __) => earned = true,
    );
    return completer.future;
  }

  @override
  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }
}
