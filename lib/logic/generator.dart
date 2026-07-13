import 'dart:math';

import '../models/puzzle.dart';

/// Generates Shikaku puzzles by recursively partitioning the grid into
/// rectangles. The partition itself is a guaranteed-valid solution; a clue is
/// then dropped into a random cell of each rectangle.
class PuzzleGenerator {
  const PuzzleGenerator();

  Puzzle generate(int level, {int? seed}) {
    final rng = Random(seed ?? _seedForLevel(level));

    final cols = (6 + level ~/ 12).clamp(6, 9);
    final rows = (7 + level ~/ 10).clamp(7, 11);
    final maxArea = (8 + level ~/ 6).clamp(8, 18);

    // Retry a few times so we avoid degenerate partitions (e.g. all 1x1).
    List<GridRect> parts = const [];
    for (var attempt = 0; attempt < 12; attempt++) {
      parts = _partition(rows, cols, rng, maxArea: maxArea);
      final maxLeaf = parts.fold<int>(0, (m, r) => max(m, r.area));
      if (parts.length >= 3 && maxLeaf >= 3) break;
    }

    final clues = <Clue>[];
    for (final r in parts) {
      final cellIndex = rng.nextInt(r.area);
      final rr = r.row + cellIndex ~/ r.width;
      final cc = r.col + cellIndex % r.width;
      clues.add(Clue(rr, cc, r.area));
    }

    return Puzzle(
      level: level,
      rows: rows,
      cols: cols,
      clues: clues,
      solution: parts,
    );
  }

  int _seedForLevel(int level) => level * 2654435761 & 0x7fffffff;

  List<GridRect> _partition(
    int rows,
    int cols,
    Random rng, {
    required int maxArea,
    double stopProb = 0.28,
    int minArea = 2,
  }) {
    final result = <GridRect>[];
    final stack = <GridRect>[GridRect(0, 0, cols, rows)];

    while (stack.isNotEmpty) {
      final r = stack.removeLast();

      // Only allow cuts where BOTH resulting pieces keep at least [minArea]
      // cells, so no rectangle (and therefore no clue) is ever a single cell.
      final vCuts = _validCuts(r.width, r.height, minArea);
      final hCuts = _validCuts(r.height, r.width, minArea);
      final canSplit = vCuts.isNotEmpty || hCuts.isNotEmpty;
      final mustSplit = r.area > maxArea;

      if (!canSplit || (!mustSplit && rng.nextDouble() < stopProb)) {
        result.add(r);
        continue;
      }

      bool splitVertical;
      if (vCuts.isNotEmpty && hCuts.isNotEmpty) {
        // Bias splitting along the longer side to keep rectangles tidy.
        if (r.width == r.height) {
          splitVertical = rng.nextBool();
        } else {
          splitVertical =
              r.width > r.height ? rng.nextDouble() < 0.7 : rng.nextDouble() < 0.3;
        }
      } else {
        splitVertical = vCuts.isNotEmpty;
      }

      if (splitVertical) {
        final cut = vCuts[rng.nextInt(vCuts.length)];
        stack.add(GridRect(r.row, r.col, cut, r.height));
        stack.add(GridRect(r.row, r.col + cut, r.width - cut, r.height));
      } else {
        final cut = hCuts[rng.nextInt(hCuts.length)];
        stack.add(GridRect(r.row, r.col, r.width, cut));
        stack.add(GridRect(r.row + cut, r.col, r.width, r.height - cut));
      }
    }

    return result;
  }

  /// Cut positions (1.._span-1) along an axis of length [span] where each side,
  /// multiplied by the perpendicular [other] extent, keeps at least [minArea].
  List<int> _validCuts(int span, int other, int minArea) {
    if (span < 2) return const [];
    final unit = (minArea + other - 1) ~/ other; // min cells per side on axis
    final lo = unit < 1 ? 1 : unit;
    final hi = span - lo;
    if (lo > hi) return const [];
    return [for (var k = lo; k <= hi; k++) k];
  }
}
