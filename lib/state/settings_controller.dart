import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle_difficulty.dart';

/// User preferences shown in the Settings sheet, persisted with
/// shared_preferences.
class SettingsController extends ChangeNotifier {
  static const _kThemeMode = 'theme_mode';
  static const _kHaptics = 'haptics';
  static const _kShowTimer = 'show_timer';
  static const _kShowSizeCounter = 'show_size_counter';
  static const _kLastPuzzleDifficulty = 'last_difficulty';
  static const _kLevelPrefix = 'current_level_';
  static const _kPuzzlesCompleted = 'puzzles_completed';
  static const _kIsAdFree = 'is_ad_free';
  static const _kInterstitialUpsellShown = 'interstitial_upsell_shown';

  /// Show an interstitial after every N puzzle wins.
  static const interstitialEveryN = 3;

  ThemeMode _themeMode = ThemeMode.system;
  bool _haptics = true;
  bool _showTimer = false;
  bool _showSizeCounter = false;
  PuzzleDifficulty _lastDifficulty = PuzzleDifficulty.medium;
  final Map<PuzzleDifficulty, int> _levels = {
    PuzzleDifficulty.easy: 1,
    PuzzleDifficulty.medium: 1,
    PuzzleDifficulty.hard: 1,
  };
  int _puzzlesCompleted = 0;
  bool _isAdFree = false;
  bool _interstitialUpsellShown = false;

  ThemeMode get themeMode => _themeMode;
  bool get haptics => _haptics;
  bool get showTimer => _showTimer;
  bool get showSizeCounter => _showSizeCounter;
  PuzzleDifficulty get lastDifficulty => _lastDifficulty;

  int levelFor(PuzzleDifficulty difficulty) => _levels[difficulty] ?? 1;

  int get puzzlesCompleted => _puzzlesCompleted;

  bool get isAdFree => _isAdFree;

  bool get interstitialUpsellShown => _interstitialUpsellShown;

  bool get shouldShowInterstitial =>
      !_isAdFree &&
      _puzzlesCompleted > 0 &&
      _puzzlesCompleted % interstitialEveryN == 0;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    _themeMode = ThemeMode.values[(p.getInt(_kThemeMode) ?? ThemeMode.system.index)
        .clamp(0, ThemeMode.values.length - 1)];
    _haptics = p.getBool(_kHaptics) ?? true;
    _showTimer = p.getBool(_kShowTimer) ?? false;
    _showSizeCounter = p.getBool(_kShowSizeCounter) ?? false;
    _lastDifficulty = PuzzleDifficulty.values[(p.getInt(_kLastPuzzleDifficulty) ?? 1)
        .clamp(0, PuzzleDifficulty.values.length - 1)];
    for (final d in PuzzleDifficulty.values) {
      _levels[d] = p.getInt('$_kLevelPrefix${d.name}') ?? 1;
    }
    _puzzlesCompleted = p.getInt(_kPuzzlesCompleted) ?? 0;
    _isAdFree = p.getBool(_kIsAdFree) ?? false;
    _interstitialUpsellShown = p.getBool(_kInterstitialUpsellShown) ?? false;
    notifyListeners();
  }

  set themeMode(ThemeMode value) {
    _themeMode = value;
    _prefs?.setInt(_kThemeMode, value.index);
    notifyListeners();
  }

  set haptics(bool value) {
    _haptics = value;
    _prefs?.setBool(_kHaptics, value);
    notifyListeners();
  }

  set showTimer(bool value) {
    _showTimer = value;
    _prefs?.setBool(_kShowTimer, value);
    notifyListeners();
  }

  set showSizeCounter(bool value) {
    _showSizeCounter = value;
    _prefs?.setBool(_kShowSizeCounter, value);
    notifyListeners();
  }

  set lastDifficulty(PuzzleDifficulty value) {
    _lastDifficulty = value;
    _prefs?.setInt(_kLastPuzzleDifficulty, value.index);
    notifyListeners();
  }

  void setLevelFor(PuzzleDifficulty difficulty, int level) {
    _levels[difficulty] = level;
    _prefs?.setInt('$_kLevelPrefix${difficulty.name}', level);
    notifyListeners();
  }

  void recordPuzzleWin() {
    _puzzlesCompleted++;
    _prefs?.setInt(_kPuzzlesCompleted, _puzzlesCompleted);
    notifyListeners();
  }

  void setAdFree(bool value) {
    if (_isAdFree == value) return;
    _isAdFree = value;
    _prefs?.setBool(_kIsAdFree, value);
    notifyListeners();
  }

  void markInterstitialUpsellShown() {
    if (_interstitialUpsellShown) return;
    _interstitialUpsellShown = true;
    _prefs?.setBool(_kInterstitialUpsellShown, true);
    notifyListeners();
  }
}
