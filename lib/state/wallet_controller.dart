import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted hint/wand balances from consumable IAP purchases.
class WalletController extends ChangeNotifier {
  static const _kWalletHints = 'wallet_hints';
  static const _kWalletWands = 'wallet_wands';

  int _hints = 0;
  int _wands = 0;
  SharedPreferences? _prefs;

  int get hints => _hints;
  int get wands => _wands;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    _hints = p.getInt(_kWalletHints) ?? 0;
    _wands = p.getInt(_kWalletWands) ?? 0;
    notifyListeners();
  }

  void addHints(int amount) {
    if (amount <= 0) return;
    _hints += amount;
    _prefs?.setInt(_kWalletHints, _hints);
    notifyListeners();
  }

  void addWands(int amount) {
    if (amount <= 0) return;
    _wands += amount;
    _prefs?.setInt(_kWalletWands, _wands);
    notifyListeners();
  }

  bool spendHint() {
    if (_hints <= 0) return false;
    _hints--;
    _prefs?.setInt(_kWalletHints, _hints);
    notifyListeners();
    return true;
  }

  bool spendWand() {
    if (_wands <= 0) return false;
    _wands--;
    _prefs?.setInt(_kWalletWands, _wands);
    notifyListeners();
    return true;
  }
}
