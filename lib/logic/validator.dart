import '../models/puzzle.dart';

/// The outcome of checking the player's rectangles against the puzzle rules.
class ValidationResult {
  final bool solved;
  final bool hasOverlap;
  final bool fullyCovered;
  final Set<int> validRectIndices;

  const ValidationResult({
    required this.solved,
    required this.hasOverlap,
    required this.fullyCovered,
    required this.validRectIndices,
  });
}

/// Validates placed rectangles against Shikaku rules:
/// no overlaps, full coverage, and each rectangle holds exactly one clue whose
/// value equals the rectangle's area.
class ShikakuValidator {
  const ShikakuValidator();

  ValidationResult evaluate(Puzzle puzzle, List<PlacedRect> placed) {
    final coverage = List<int>.filled(puzzle.cellCount, 0);
    var hasOverlap = false;

    for (final p in placed) {
      final r = p.rect;
      for (var rr = r.row; rr < r.bottom; rr++) {
        for (var cc = r.col; cc < r.right; cc++) {
          final idx = rr * puzzle.cols + cc;
          if (idx < 0 || idx >= coverage.length) continue;
          coverage[idx]++;
          if (coverage[idx] > 1) hasOverlap = true;
        }
      }
    }

    final fullyCovered = coverage.every((c) => c == 1);

    final validRectIndices = <int>{};
    for (var i = 0; i < placed.length; i++) {
      if (_rectSatisfiesClue(puzzle, placed[i].rect)) {
        validRectIndices.add(i);
      }
    }

    final allCluesSatisfied =
        validRectIndices.length == placed.length &&
        placed.length == puzzle.clues.length;

    final solved = fullyCovered && !hasOverlap && allCluesSatisfied;

    return ValidationResult(
      solved: solved,
      hasOverlap: hasOverlap,
      fullyCovered: fullyCovered,
      validRectIndices: validRectIndices,
    );
  }

  bool _rectSatisfiesClue(Puzzle puzzle, GridRect rect) {
    var cluesInside = 0;
    var matched = false;
    for (final clue in puzzle.clues) {
      if (rect.containsCell(clue.row, clue.col)) {
        cluesInside++;
        if (clue.value == rect.area) matched = true;
      }
    }
    return cluesInside == 1 && matched;
  }
}
