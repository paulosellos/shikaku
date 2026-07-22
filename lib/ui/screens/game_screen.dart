import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/puzzle_difficulty.dart';
import '../../state/app_scope.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/board_view.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/store_sheet.dart';
import '../widgets/toolbar.dart';
import '../widgets/win_overlay.dart';
import '../widgets/win_screens/win_screen_picker.dart';
import '../widgets/win_screens/win_screen_variant.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _eraseMode = false;
  bool _winShown = false;
  bool _loggedGameStart = false;
  GameController? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final game = AppScope.of(context).game;
    if (!identical(game, _game)) {
      _game?.removeListener(_onGameChanged);
      _game = game;
      _game!.addListener(_onGameChanged);
      _loggedGameStart = false;
    }
    if (!_loggedGameStart) {
      _loggedGameStart = true;
      final scope = AppScope.of(context);
      scope.analytics.logGameStarted(
        difficulty: game.difficulty,
        level: game.puzzle.level,
        boardSize: game.puzzle.rows,
      );
    }
  }

  void _onGameChanged() {
    final game = _game;
    if (game != null && game.solved && !_winShown && mounted) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWin());
    }
  }

  Future<void> _showWin() async {
    final scope = AppScope.of(context);
    final game = scope.game;
    final variant = WinScreenPicker.pick(
      difficulty: game.difficulty,
      boardSize: game.puzzle.rows,
      elapsed: game.elapsed,
      hintsUsed: game.hintsUsed,
      wandUsed: game.wandUsed,
      undoCount: game.undoCount,
    );
    scope.analytics.logPuzzleCompleted(
      difficulty: game.difficulty,
      level: game.puzzle.level,
      elapsedSec: game.elapsed.inSeconds,
      hintsUsed: game.hintsUsed,
      wandUsed: game.wandUsed,
      undoCount: game.undoCount,
      winVariant: variant.name,
      flawless: game.hintsUsed == 0 && game.wandUsed == 0,
    );
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => WinOverlay(
          solvedLevel: game.puzzle.level,
          elapsed: game.elapsed,
          variant: variant,
          onContinue: () async {
            final nextLevel = game.puzzle.level + 1;
            Navigator.of(context).pop();
            scope.settings.recordPuzzleWin();
            scope.settings.setLevelFor(game.difficulty, nextLevel);
            if (scope.settings.shouldShowInterstitial &&
                scope.ads.isInterstitialReady) {
              await scope.analytics.logInterstitialShown(
                puzzlesCompleted: scope.settings.puzzlesCompleted,
              );
              await scope.ads.showInterstitialAd();
              await scope.analytics.logInterstitialDismissed();
              if (mounted &&
                  !scope.settings.isAdFree &&
                  !scope.settings.interstitialUpsellShown) {
                scope.settings.markInterstitialUpsellShown();
                await _showAdFreeUpsell(context, scope);
              }
            }
            game.loadLevel(nextLevel);
          },
        ),
      ),
    );
    _winShown = false;
    if (mounted) setState(() => _eraseMode = false);
  }

  @override
  void dispose() {
    _game?.removeListener(_onGameChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final game = scope.game;
    final settings = scope.settings;
    final ads = scope.ads;
    final colors = AppColors.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop || game.solved) return;
        scope.analytics.logPuzzleAbandoned(
          difficulty: game.difficulty,
          level: game.puzzle.level,
          elapsedSec: game.elapsed.inSeconds,
        );
      },
      child: Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([game, settings, ads]),
          builder: (context, _) {
            final level = game.puzzle.level;
            return Column(
              children: [
                _Header(
                  title: 'Shikaku ${game.difficulty.label} $level',
                  colors: colors,
                  onBack: () => Navigator.of(context).maybePop(),
                  onHelp: () => _showHelp(context, colors),
                  onSettings: () {
                    scope.analytics.logSettingsOpened('game');
                    SettingsSheet.show(
                      context,
                      settings: settings,
                      game: game,
                    );
                  },
                ),
                if (settings.showTimer || settings.showSizeCounter)
                  _StatusBar(colors: colors),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: BoardView(game: game, eraseMode: _eraseMode),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: GameToolbar(
                    eraseActive: _eraseMode,
                    canUndo: game.canUndo,
                    wandsLeft: game.wandsLeft,
                    hintsLeft: game.hintsLeft,
                    wandRewardAvailable:
                        game.wandsLeft == 0 && ads.isRewardedReady,
                    hintRewardAvailable:
                        game.hintsLeft == 0 && ads.isRewardedReady,
                    onEraseToggle: () =>
                        setState(() => _eraseMode = !_eraseMode),
                    onUndo: () {
                      game.undo();
                      scope.analytics.logUndoUsed(undoCount: game.undoCount);
                    },
                    onWand: () => _onWandTap(context, game, colors),
                    onHint: () => _onHintTap(context, game, colors),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Future<void> _showAdFreeUpsell(BuildContext context, AppScope scope) async {
    final colors = AppColors.of(context);
    final openStore = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.background,
        title: Text('Tired of ads?', style: AppTheme.title(colors)),
        content: Text(
          'Remove interstitial ads forever with a one-time purchase.',
          style: TextStyle(color: colors.headerText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Not now', style: TextStyle(color: colors.subtleText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                Text('View store', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
    if (openStore == true && context.mounted) {
      await StoreSheet.show(
        context,
        settings: scope.settings,
        purchases: scope.purchases,
        analytics: scope.analytics,
        source: 'interstitial_upsell',
      );
    }
  }

  Future<void> _onWandTap(
    BuildContext context,
    GameController game,
    AppColors colors,
  ) async {
    if (game.solved) return;
    if (game.wandsLeft > 0) {
      await _confirmWand(context, game, colors);
      return;
    }
    AppScope.of(context).analytics.logPowerupDepleted('wand');
    await _offerRewardedWand(context, colors);
  }

  Future<void> _onHintTap(
    BuildContext context,
    GameController game,
    AppColors colors,
  ) async {
    if (game.solved) return;
    final scope = AppScope.of(context);
    if (game.hintsLeft > 0) {
      game.useHint();
      scope.analytics.logHintUsed(
        hintsRemaining: game.hintsLeft,
        ghostCount: game.hintGhosts.length,
      );
      return;
    }
    scope.analytics.logPowerupDepleted('hint');
    await _offerRewardedHints(context, colors);
  }

  Future<void> _offerRewardedWand(BuildContext context, AppColors colors) async {
    final scope = AppScope.of(context);
    if (!scope.ads.isRewardedReady) return;
    const rewardAmount = 1;
    await scope.analytics.logRewardedAdOffered(
      type: 'wand',
      rewardAmount: rewardAmount,
    );
    final watch = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.background,
        title: Text('Out of wand charges', style: AppTheme.title(colors)),
        content: Text(
          'Watch a short video to earn +1 magic wand charge.',
          style: TextStyle(color: colors.headerText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Not now', style: TextStyle(color: colors.subtleText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Watch ad', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
    if (watch != true || !context.mounted) {
      if (watch == false) {
        await scope.analytics.logRewardedAdDismissed('wand');
      }
      return;
    }
    final earned = await scope.ads.showRewardedAd();
    if (earned && context.mounted) {
      scope.game.addWandCharges(rewardAmount);
      await scope.analytics.logRewardedAdCompleted(
        type: 'wand',
        rewardAmount: rewardAmount,
      );
    } else if (context.mounted) {
      await scope.analytics.logRewardedAdDismissed('wand');
    }
  }

  Future<void> _offerRewardedHints(
    BuildContext context,
    AppColors colors,
  ) async {
    final scope = AppScope.of(context);
    if (!scope.ads.isRewardedReady) return;
    const rewardAmount = 2;
    await scope.analytics.logRewardedAdOffered(
      type: 'hint',
      rewardAmount: rewardAmount,
    );
    final watch = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.background,
        title: Text('Out of hints', style: AppTheme.title(colors)),
        content: Text(
          'Watch a short video to earn +2 hint charges.',
          style: TextStyle(color: colors.headerText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Not now', style: TextStyle(color: colors.subtleText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Watch ad', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
    if (watch != true || !context.mounted) {
      if (watch == false) {
        await scope.analytics.logRewardedAdDismissed('hint');
      }
      return;
    }
    final earned = await scope.ads.showRewardedAd();
    if (earned && context.mounted) {
      scope.game.addHintCharges(rewardAmount);
      await scope.analytics.logRewardedAdCompleted(
        type: 'hint',
        rewardAmount: rewardAmount,
      );
    } else if (context.mounted) {
      await scope.analytics.logRewardedAdDismissed('hint');
    }
  }

  Future<void> _confirmWand(
    BuildContext context,
    GameController game,
    AppColors colors,
  ) async {
    if (game.wandsLeft <= 0 || game.solved) return;
    final use = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.background,
        title: Text('Use magic wand?', style: AppTheme.title(colors)),
        content: Text(
          'This will place one correct rectangle for you. You only have '
          '${game.wandsLeft} charge${game.wandsLeft == 1 ? '' : 's'} left.',
          style: TextStyle(color: colors.headerText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.subtleText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Use wand', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
    if (use == true && context.mounted) {
      game.useWand();
      AppScope.of(context).analytics.logWandUsed(
        wandsRemaining: game.wandsLeft,
      );
    }
  }

  void _showHelp(BuildContext context, AppColors colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.background,
        title: Text('How to play', style: AppTheme.title(colors)),
        content: Text(
          'Divide the whole grid into rectangles. Each rectangle must contain '
          'exactly one number, and that number equals the number of cells in '
          'the rectangle. Rectangles cannot overlap.\n\n'
          'Drag across at least two cells to draw a rectangle. Tap or long-press '
          'a placed shape to remove it, or toggle the eraser tool.\n\n'
          'Hints show a ghost outline without placing it. The magic wand '
          'places one correct rectangle.\n\n'
          'When you run out of hints or wand charges, you can watch a short '
          'video to earn more.',
          style: TextStyle(color: colors.headerText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final AppColors colors;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onSettings;

  const _Header({
    required this.title,
    required this.colors,
    required this.onBack,
    required this.onHelp,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _iconButton(Icons.arrow_back, onBack),
          Expanded(
            child: Center(
              child: Text(title, style: AppTheme.title(colors)),
            ),
          ),
          _iconButton(Icons.chat_bubble_outline_rounded, onHelp),
          const SizedBox(width: 8),
          _iconButton(Icons.settings_outlined, onSettings),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: colors.headerText, size: 26),
        ),
      );
}

class _StatusBar extends StatefulWidget {
  final AppColors colors;
  const _StatusBar({required this.colors});

  @override
  State<_StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<_StatusBar> {
  Timer? _timer;
  GameController? _game;
  SettingsController? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (!identical(_game, scope.game) ||
        !identical(_settings, scope.settings)) {
      _game?.removeListener(_onListenableChanged);
      _settings?.removeListener(_onListenableChanged);
      _game = scope.game;
      _settings = scope.settings;
      _game!.addListener(_onListenableChanged);
      _settings!.addListener(_onListenableChanged);
      _syncTimer();
    }
  }

  void _onListenableChanged() {
    _syncTimer();
    if (mounted) setState(() {});
  }

  void _syncTimer() {
    final shouldTick =
        (_settings?.showTimer ?? false) && !(_game?.solved ?? true);
    if (shouldTick && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!shouldTick) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _game?.removeListener(_onListenableChanged);
    _settings?.removeListener(_onListenableChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game ?? AppScope.of(context).game;
    final settings = _settings ?? AppScope.of(context).settings;
    final placedCells =
        game.placed.fold<int>(0, (sum, p) => sum + p.rect.area);
    final d = game.elapsed;
    final time = AppTheme.formatElapsed(d);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (settings.showTimer)
            Text(time, style: AppTheme.monoLabel(widget.colors)),
          if (settings.showTimer && settings.showSizeCounter)
            const SizedBox(width: 20),
          if (settings.showSizeCounter)
            Text('$placedCells / ${game.puzzle.cellCount}',
                style: AppTheme.monoLabel(widget.colors)),
        ],
      ),
    );
  }
}
