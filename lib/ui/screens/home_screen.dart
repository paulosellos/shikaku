import 'package:flutter/material.dart';

import '../../models/puzzle_difficulty.dart';
import '../../models/store_product.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../widgets/mascot.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/store_sheet.dart';
import 'game_screen.dart';

/// The main menu: pick a difficulty, jump back into your last game, or open
/// settings / leaderboard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scope = AppScope.of(context);
      scope.analytics.logHomeViewed(
        lastDifficulty: scope.settings.lastDifficulty,
        lastLevel: scope.settings.levelFor(scope.settings.lastDifficulty),
      );
    });
  }

  void _play(
    BuildContext context, {
    required PuzzleDifficulty difficulty,
    required String source,
  }) {
    final scope = AppScope.of(context);
    final level = scope.settings.levelFor(difficulty);
    scope.settings.lastDifficulty = difficulty;
    if (source == 'difficulty_card') {
      scope.analytics.logDifficultySelected(difficulty);
    }
    scope.analytics.logPlayTapped(
      difficulty: difficulty,
      level: level,
      source: source,
    );
    scope.game.loadLevel(level, difficulty: difficulty);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: scope.settings,
          builder: (context, _) {
            final lastDifficulty = scope.settings.lastDifficulty;
            final lastLevel = scope.settings.levelFor(lastDifficulty);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () {
                        scope.analytics.logSettingsOpened('home');
                        SettingsSheet.show(
                          context,
                          settings: scope.settings,
                          game: scope.game,
                        );
                      },
                      icon: Icon(Icons.settings_outlined,
                          color: colors.headerText),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Mascot(size: 120),
                  const SizedBox(height: 16),
                  Text('Shikaku', style: AppTheme.heading(colors)),
                  const SizedBox(height: 4),
                  Text(
                    'Draw rectangles. Trust the numbers.',
                    style: TextStyle(
                      fontFamily: AppTheme.serif,
                      fontSize: 14,
                      color: colors.subtleText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _play(
                        context,
                        difficulty: lastDifficulty,
                        source: 'continue',
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Play ${lastDifficulty.label} $lastLevel',
                            style: AppTheme.monoLabel(
                              colors,
                            ).copyWith(fontSize: 17, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choose a difficulty',
                        style: AppTheme.title(colors).copyWith(fontSize: 18)),
                  ),
                  const SizedBox(height: 12),
                  for (final d in PuzzleDifficulty.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PuzzleDifficultyCard(
                        difficulty: d,
                        level: scope.settings.levelFor(d),
                        selected: d == lastDifficulty,
                        colors: colors,
                        onTap: () => _play(
                          context,
                          difficulty: d,
                          source: 'difficulty_card',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (!scope.settings.isAdFree)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => StoreSheet.show(
                          context,
                          settings: scope.settings,
                          purchases: scope.purchases,
                          analytics: scope.analytics,
                          source: 'home',
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: colors.cell,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.block, color: colors.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Go ad-free',
                                  style: TextStyle(
                                    color: colors.headerText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                scope.purchases
                                        .priceFor(StoreSkus.removeAds) ??
                                    '\$4.99',
                                style: AppTheme.monoLabel(colors),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _LeaderboardRow(colors: colors),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PuzzleDifficultyCard extends StatelessWidget {
  final PuzzleDifficulty difficulty;
  final int level;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _PuzzleDifficultyCard({
    required this.difficulty,
    required this.level,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (difficulty) {
      PuzzleDifficulty.easy => RectPalette.at(0, colors.isDark),
      PuzzleDifficulty.medium => RectPalette.at(1, colors.isDark),
      PuzzleDifficulty.hard => RectPalette.at(7, colors.isDark),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.cell,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: colors.accent, width: 2)
              : Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(difficulty.label,
                      style: AppTheme.title(colors).copyWith(fontSize: 17)),
                  Text(
                    difficulty.description,
                    style: TextStyle(color: colors.subtleText, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text('Lv $level', style: AppTheme.monoLabel(colors)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: colors.subtleText),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final AppColors colors;
  const _LeaderboardRow({required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppScope.of(context).analytics.logLeaderboardOpened();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leaderboard is coming soon!')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.cell.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: colors.subtleText),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Leaderboard',
                  style: TextStyle(color: colors.headerText, fontSize: 15)),
            ),
            Text('Coming soon',
                style: TextStyle(color: colors.subtleText, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
