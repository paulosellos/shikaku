import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences shown in the Settings sheet, persisted with
/// shared_preferences.
class SettingsController extends ChangeNotifier {
  static const _kThemeMode = 'theme_mode';
  static const _kHaptics = 'haptics';
  static const _kShowTimer = 'show_timer';
  static const _kShowSizeCounter = 'show_size_counter';
  static const _kLevel = 'current_level';

  ThemeMode _themeMode = ThemeMode.system;
  bool _haptics = true;
  bool _showTimer = false;
  bool _showSizeCounter = false;
  int _currentLevel = 1;

  ThemeMode get themeMode => _themeMode;
  bool get haptics => _haptics;
  bool get showTimer => _showTimer;
  bool get showSizeCounter => _showSizeCounter;
  int get currentLevel => _currentLevel;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    _themeMode = ThemeMode.values[(p.getInt(_kThemeMode) ?? ThemeMode.system.index)
        .clamp(0, ThemeMode.values.length - 1)];
    _haptics = p.getBool(_kHaptics) ?? true;
    _showTimer = p.getBool(_kShowTimer) ?? false;
    _showSizeCounter = p.getBool(_kShowSizeCounter) ?? false;
    _currentLevel = p.getInt(_kLevel) ?? 1;
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

  set currentLevel(int value) {
    _currentLevel = value;
    _prefs?.setInt(_kLevel, value);
    notifyListeners();
  }
}
