import 'package:flutter/foundation.dart';

import 'puzzle_difficulty.dart';

/// An axis-aligned rectangle over grid cells. [row]/[col] is the top-left cell
/// (inclusive); [right]/[bottom] are exclusive.
@immutable
class GridRect {
  final int row;
  final int col;
  final int width;
  final int height;

  const GridRect(this.row, this.col, this.width, this.height);

  int get area => width * height;
  int get right => col + width;
  int get bottom => row + height;

  bool containsCell(int r, int c) =>
      r >= row && r < bottom && c >= col && c < right;

  bool intersects(GridRect o) =>
      col < o.right && o.col < right && row < o.bottom && o.row < bottom;

  /// Builds a rectangle spanning two arbitrary corner cells (inclusive).
  factory GridRect.fromCorners(int r1, int c1, int r2, int c2) {
    final top = r1 < r2 ? r1 : r2;
    final left = c1 < c2 ? c1 : c2;
    final bottom = r1 > r2 ? r1 : r2;
    final right = c1 > c2 ? c1 : c2;
    return GridRect(top, left, right - left + 1, bottom - top + 1);
  }

  @override
  bool operator ==(Object other) =>
      other is GridRect &&
      other.row == row &&
      other.col == col &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(row, col, width, height);

  @override
  String toString() => 'GridRect(r:$row, c:$col, w:$width, h:$height)';
}

/// A numbered clue: the cell that holds a number equal to its rectangle's area.
@immutable
class Clue {
  final int row;
  final int col;
  final int value;

  const Clue(this.row, this.col, this.value);
}

/// A generated Shikaku puzzle. [solution] is aligned by index with [clues]:
/// `solution[i]` is the rectangle that owns `clues[i]`.
@immutable
class Puzzle {
  final int level;
  final PuzzleDifficulty difficulty;
  final int rows;
  final int cols;
  final List<Clue> clues;
  final List<GridRect> solution;
  final DifficultyAnalysis? difficultyAnalysis;

  const Puzzle({
    required this.level,
    this.difficulty = PuzzleDifficulty.medium,
    required this.rows,
    required this.cols,
    required this.clues,
    required this.solution,
    this.difficultyAnalysis,
  });

  int get cellCount => rows * cols;
}

/// A rectangle the player has drawn, with its palette colour slot.
@immutable
class PlacedRect {
  final GridRect rect;
  final int colorIndex;

  const PlacedRect(this.rect, this.colorIndex);
}

/// A ghost hint outline for one unsolved region (not placed on the board).
@immutable
class HintGhost {
  final int clueIndex;
  final GridRect rect;
  final int colorIndex;

  const HintGhost({
    required this.clueIndex,
    required this.rect,
    required this.colorIndex,
  });
}
