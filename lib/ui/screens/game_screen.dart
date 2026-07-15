import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../state/app_scope.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/board_view.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/toolbar.dart';
import '../widgets/win_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _eraseMode = false;
  bool _winShown = false;
  GameController? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final game = AppScope.of(context).game;
    if (!identical(game, _game)) {
      _game?.removeListener(_onGameChanged);
      _game = game;
      _game!.addListener(_onGameChanged);
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
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => WinOverlay(
          solvedLevel: scope.game.puzzle.level,
          onContinue: (nextLevel) {
            scope.settings.setLevelFor(scope.game.difficulty, nextLevel);
            scope.game.loadLevel(nextLevel);
            Navigator.of(context).pop();
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
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([game, settings]),
          builder: (context, _) {
            final level = game.puzzle.level;
            return Column(
              children: [
                _Header(
                  title: 'Shikaku ${game.difficulty.label} $level',
                  colors: colors,
                  onBack: () => Navigator.of(context).maybePop(),
                  onHelp: () => _showHelp(context, colors),
                  onSettings: () => SettingsSheet.show(
                    context,
                    settings: settings,
                    game: game,
                  ),
                  onSkip: () {
                    settings.setLevelFor(game.difficulty, level + 1);
                    game.loadLevel(level + 1);
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
                    onEraseToggle: () =>
                        setState(() => _eraseMode = !_eraseMode),
                    onUndo: game.undo,
                    onWand: game.useWand,
                    onHint: game.useHint,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
          'Drag across at least two cells to draw a rectangle. Tap a placed '
          'shape to remove it, or use the eraser tool.',
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
  final VoidCallback onSkip;

  const _Header({
    required this.title,
    required this.colors,
    required this.onBack,
    required this.onHelp,
    required this.onSettings,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
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
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onSkip,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.cell,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.keyboard_double_arrow_right,
                    color: colors.toolbarIcon, size: 20),
              ),
            ),
          ),
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

class _StatusBar extends StatelessWidget {
  final AppColors colors;
  const _StatusBar({required this.colors});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final game = scope.game;
    final settings = scope.settings;
    final placedCells =
        game.placed.fold<int>(0, (sum, p) => sum + p.rect.area);
    final d = game.elapsed;
    final time =
        '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (settings.showTimer)
            Text(time, style: AppTheme.monoLabel(colors)),
          if (settings.showTimer && settings.showSizeCounter)
            const SizedBox(width: 20),
          if (settings.showSizeCounter)
            Text('$placedCells / ${game.puzzle.cellCount}',
                style: AppTheme.monoLabel(colors)),
        ],
      ),
    );
  }
}
