import 'package:flutter/material.dart';

import '../../models/puzzle.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';

/// Renders the Shikaku grid and translates pointer gestures into rectangle
/// drawing / erasing on the [GameController].
class BoardView extends StatelessWidget {
  final GameController game;
  final bool eraseMode;

  const BoardView({super.key, required this.game, required this.eraseMode});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
                    game.startDrag(r, c);
                  }
                },
                onPointerMove: (e) {
                  if (eraseMode) return;
                  game.updateDrag(
                    rowFor(e.localPosition.dy),
                    colFor(e.localPosition.dx),
                  );
                },
                onPointerUp: (e) {
                  if (eraseMode) return;
                  game.endDrag();
                },
                onPointerCancel: (e) {
                  if (eraseMode) return;
                  game.endDrag();
                },
                child: CustomPaint(
                  painter: _BoardPainter(
                    puzzle: puzzle,
                    placed: game.placed,
                    preview: game.preview,
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
  final AppColors colors;
  final double cell;

  _BoardPainter({
    required this.puzzle,
    required this.placed,
    required this.preview,
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
    final consumedClues = <int>{};
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

      final inside = <int>[];
      for (var i = 0; i < puzzle.clues.length; i++) {
        final clue = puzzle.clues[i];
        if (gr.containsCell(clue.row, clue.col)) inside.add(i);
      }
      if (inside.length == 1) {
        consumedClues.add(inside.first);
        _drawNumber(
          canvas,
          puzzle.clues[inside.first].value,
          rect.center,
          colors.rectText,
        );
      }
    }

    // Drag preview.
    final pv = preview;
    if (pv != null) {
      final rect = Rect.fromLTWH(
        pv.col * cell + margin,
        pv.row * cell + margin,
        pv.width * cell - 2 * margin,
        pv.height * cell - 2 * margin,
      );
      final rrect = RRect.fromRectAndRadius(rect, radius);
      final fill = Paint()
        ..color = colors.cellText.withValues(alpha: colors.isDark ? 0.28 : 0.22);
      canvas.drawRRect(rrect, fill);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.03
        ..color = colors.cellText.withValues(alpha: 0.5);
      canvas.drawRRect(rrect, border);
    }

    // Clues not inside a single-owner rectangle: draw in their own cell.
    for (var i = 0; i < puzzle.clues.length; i++) {
      if (consumedClues.contains(i)) continue;
      final clue = puzzle.clues[i];
      final center = Offset(
        clue.col * cell + cell / 2,
        clue.row * cell + cell / 2,
      );
      _drawNumber(canvas, clue.value, center, colors.cellText);
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
      old.colors.isDark != colors.isDark ||
      old.cell != cell;
}
