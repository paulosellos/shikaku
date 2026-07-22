import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../models/puzzle_difficulty.dart';
import '../../models/store_product.dart';
import '../../state/app_scope.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import 'store_sheet.dart';

/// The Settings bottom sheet: appearance and game preferences.
class SettingsSheet extends StatelessWidget {
  final SettingsController settings;
  final GameController game;

  const SettingsSheet({super.key, required this.settings, required this.game});

  static Future<void> show(
    BuildContext context, {
    required SettingsController settings,
    required GameController game,
    String source = 'game',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsSheet(settings: settings, game: game),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, color: colors.headerText),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Settings', style: AppTheme.title(colors)),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel('Appearance', colors),
              _card(
                colors,
                child: Column(
                  children: [
                    _toggleRow(
                      colors,
                      'Haptics',
                      settings.haptics,
                      (v) {
                        settings.haptics = v;
                        game.hapticsEnabled = v;
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 6, bottom: 12),
                child: Text(
                  'Enhance interactions with gentle haptic feedback',
                  style: TextStyle(color: colors.subtleText, fontSize: 13),
                ),
              ),
              _card(
                colors,
                child: Row(
                  children: [
                    Text('Theme', style: TextStyle(color: colors.headerText, fontSize: 16)),
                    const Spacer(),
                    _themeOption(colors, 'Dark', ThemeMode.dark),
                    _themeOption(colors, 'Light', ThemeMode.light),
                    _themeOption(colors, 'System', ThemeMode.system),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Store', colors),
              _card(
                colors,
                child: GestureDetector(
                  onTap: () {
                    final scope = AppScope.of(context);
                    StoreSheet.show(
                      context,
                      settings: settings,
                      purchases: scope.purchases,
                      analytics: scope.analytics,
                      source: 'settings',
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text(
                        settings.isAdFree ? 'Ad-free unlocked' : 'Remove ads',
                        style:
                            TextStyle(color: colors.headerText, fontSize: 16),
                      ),
                      const Spacer(),
                      if (!settings.isAdFree)
                        Text(
                          scopePriceLabel(context),
                          style: AppTheme.monoLabel(colors),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: colors.subtleText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Game', colors),
              _card(
                colors,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Difficulty',
                        style: TextStyle(color: colors.headerText, fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final d in PuzzleDifficulty.values)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: d != PuzzleDifficulty.values.last ? 6 : 0,
                              ),
                              child: _difficultyOption(colors, d),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _card(
                colors,
                child: _toggleRow(
                  colors,
                  'Show timer',
                  settings.showTimer,
                  (v) => settings.showTimer = v,
                ),
              ),
              const SizedBox(height: 10),
              _card(
                colors,
                child: _toggleRow(
                  colors,
                  'Show size counter',
                  settings.showSizeCounter,
                  (v) => settings.showSizeCounter = v,
                ),
              ),
              const SizedBox(height: 10),
              _card(
                colors,
                child: GestureDetector(
                  onTap: () {
                    game.reset();
                    Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text('Reset level',
                          style: TextStyle(color: colors.headerText, fontSize: 16)),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: colors.subtleText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  AppInfo.display,
                  style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 12,
                    color: colors.subtleText,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text, AppColors colors) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          text,
          style: AppTheme.title(colors).copyWith(fontSize: 20),
        ),
      );

  Widget _card(AppColors colors, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.cell.withValues(alpha: colors.isDark ? 0.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );

  Widget _toggleRow(
    AppColors colors,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Row(
        children: [
          Text(label, style: TextStyle(color: colors.headerText, fontSize: 16)),
          const Spacer(),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: colors.accent,
            onChanged: onChanged,
          ),
        ],
      );

  Widget _difficultyOption(AppColors colors, PuzzleDifficulty difficulty) {
    final selected = game.difficulty == difficulty;
    return GestureDetector(
      onTap: () {
        if (game.difficulty == difficulty) return;
        settings.lastDifficulty = difficulty;
        game.loadLevel(
          settings.levelFor(difficulty),
          difficulty: difficulty,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: colors.subtleText.withValues(alpha: 0.4))
              : null,
        ),
        child: Center(
          child: Text(
            difficulty.label,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 13,
              color: selected ? colors.headerText : colors.subtleText,
            ),
          ),
        ),
      ),
    );
  }

  String scopePriceLabel(BuildContext context) {
    return AppScope.of(context).purchases.priceFor(StoreSkus.removeAds) ??
        '\$4.99';
  }

  Widget _themeOption(AppColors colors, String label, ThemeMode mode) {
    final selected = settings.themeMode == mode;
    return GestureDetector(
      onTap: () => settings.themeMode = mode,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: colors.subtleText.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.mono,
            fontSize: 14,
            color: selected ? colors.headerText : colors.subtleText,
          ),
        ),
      ),
    );
  }
}
