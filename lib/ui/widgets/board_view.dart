import 'package:flutter/material.dart';

import '../../models/puzzle.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';

/// Renders the Shikaku grid and translates pointer gestures into rectangle
/// drawing / erasing on the [GameController].
class BoardView extends StatefulWidget {
  final GameController game;
  final bool eraseMode;

  const BoardView({super.key, required this.game, required this.eraseMode});

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  // Real touchscreens rarely report a perfectly still tap: the finger
  // usually drifts a few pixels between pointer-down and pointer-up. Without
  // a dead-zone, that drift can cross a cell boundary and silently turn an
  // intended single-cell tap into a rectangle that doesn't match the cell
  // the player touched. We lock the preview to the starting cell until the
  // finger moves past this threshold, then treat it as a genuine drag.
  static const double _dragDeadZone = 10;

  Offset? _downPosition;
  bool _dragExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final game = widget.game;
    final eraseMode = widget.eraseMode;
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        final puzzle = game.puzzle;
        return LayoutBuilder(
          builder: (context, constraints) {
            final cell = constraints.maxWidth / puzzle.cols;
            final height = cell * puzzle.rows;

            int rowFor(double y) =>
                (y / cell).floor().clamp(0, puzzle.rows - 1);
            int colFor(double x) =>
                (x / cell).floor().clamp(0, puzzle.cols - 1);

            return SizedBox(
              width: constraints.maxWidth,
              height: height,
              child: Listener(
                onPointerDown: (e) {
                  final r = rowFor(e.localPosition.dy);
                  final c = colFor(e.localPosition.dx);
                  if (eraseMode) {
                    game.eraseAt(r, c);
                  } else {
                    _downPosition = e.localPosition;
                    _dragExpanded = false;
                    game.startDrag(r, c);
                  }
                },
                onPointerMove: (e) {
                  if (eraseMode) return;
                  final down = _downPosition;
                  if (down == null) return;
                  if (!_dragExpanded) {
                    final moved = (e.localPosition - down).distance;
                    if (moved < _dragDeadZone) return;
                    _dragExpanded = true;
                  }
                  game.updateDrag(
                    rowFor(e.localPosition.dy),
                    colFor(e.localPosition.dx),
                  );
                },
                onPointerUp: (e) {
                  _downPosition = null;
                  _dragExpanded = false;
                  if (eraseMode) return;
                  game.endDrag();
                },
                onPointerCancel: (e) {
                  _downPosition = null;
                  _dragExpanded = false;
                  if (eraseMode) return;
                  game.endDrag();
                },
                child: CustomPaint(
                  painter: _BoardPainter(
                    puzzle: puzzle,
                    placed: game.placed,
                    preview: game.preview,
                    previewColorIndex: game.previewColorIndex,
                    colors: colors,
                    cell: cell,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final Puzzle puzzle;
  final List<PlacedRect> placed;
  final GridRect? preview;
  final int previewColorIndex;
  final AppColors colors;
  final double cell;

  _BoardPainter({
    required this.puzzle,
    required this.placed,
    required this.preview,
    required this.previewColorIndex,
    required this.colors,
    required this.cell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final margin = cell * 0.055;
    final radius = Radius.circular(cell * 0.2);

    // Empty cells.
    final cellPaint = Paint()..color = colors.cell;
    for (var r = 0; r < puzzle.rows; r++) {
      for (var c = 0; c < puzzle.cols; c++) {
        final rect = Rect.fromLTWH(
          c * cell + margin,
          r * cell + margin,
          cell - 2 * margin,
          cell - 2 * margin,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), cellPaint);
      }
    }

    // Placed rectangles.
    for (final p in placed) {
      final gr = p.rect;
      final rect = Rect.fromLTWH(
        gr.col * cell + margin,
        gr.row * cell + margin,
        gr.width * cell - 2 * margin,
        gr.height * cell - 2 * margin,
      );
      final rrect = RRect.fromRectAndRadius(rect, radius);
      final fill = Paint()..color = RectPalette.at(p.colorIndex, colors.isDark);
      canvas.drawRRect(rrect, fill);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.02
        ..color = Colors.black.withValues(alpha: 0.12);
      canvas.drawRRect(rrect, border);
    }

    // Drag preview — same palette color as the committed shape, semi-transparent.
    final pv = preview;
    if (pv != null) {
      final rect = Rect.fromLTWH(
        pv.col * cell + margin,
        pv.row * cell + margin,
        pv.width * cell - 2 * margin,
        pv.height * cell - 2 * margin,
      );
      final rrect = RRect.fromRectAndRadius(rect, radius);
      final base = RectPalette.at(previewColorIndex, colors.isDark);
      final fill = Paint()..color = base.withValues(alpha: 0.55);
      canvas.drawRRect(rrect, fill);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.02
        ..color = Colors.black.withValues(alpha: 0.18);
      canvas.drawRRect(rrect, border);
    }

    // Clue numbers always stay in their original cell.
    for (final clue in puzzle.clues) {
      final center = Offset(
        clue.col * cell + cell / 2,
        clue.row * cell + cell / 2,
      );
      final owners = placed
          .where((p) => p.rect.containsCell(clue.row, clue.col))
          .length;
      final color = owners == 1 ? colors.rectText : colors.cellText;
      _drawNumber(canvas, clue.value, center, color);
    }
  }

  void _drawNumber(Canvas canvas, int value, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$value',
        style: TextStyle(
          fontFamily: AppTheme.serif,
          fontSize: cell * 0.4,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.placed != placed ||
      old.preview != preview ||
      old.previewColorIndex != previewColorIndex ||
      old.colors.isDark != colors.isDark ||
      old.cell != cell;
}
