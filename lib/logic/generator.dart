import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/puzzle.dart';
import '../models/puzzle_difficulty.dart';
import 'puzzle_solver.dart';

/// Generates Shikaku puzzles with uniqueness and difficulty validation.
class PuzzleGenerator {
  const PuzzleGenerator();

  final PuzzleSolver _solver = const PuzzleSolver();

  Puzzle generate(
    int level, {
    PuzzleDifficulty difficulty = PuzzleDifficulty.medium,
    int? seed,
  }) {
    final profile = DifficultyProfiles.forDifficulty(difficulty);
    final baseSeed = seed ?? _seedForLevel(level, difficulty);
    final rows = _rowsFor(level, profile);
    final cols = _colsFor(level, profile);
    final maxArea = _maxAreaFor(level, profile);

    Puzzle? bestMatch;
    Puzzle? bestUnique;
    var bestDistance = 1 << 30;

    for (var attempt = 0; attempt < profile.maxAttempts; attempt++) {
      final rng = Random(baseSeed + attempt * 9973);
      final parts = _partition(
        rows,
        cols,
        rng,
        maxArea: maxArea,
        stopProb: profile.stopProb,
      );
      if (parts.any((r) => r.area < 2)) continue;

      final clues = _placeClues(parts, difficulty, rng);
      final puzzle = Puzzle(
        level: level,
        difficulty: difficulty,
        rows: rows,
        cols: cols,
        clues: clues,
        solution: parts,
      );

      final analysis = _solver.analyze(puzzle, nodeLimit: profile.searchNodeLimit);
      if (!analysis.isUnique) continue;

      if (bestUnique == null || profile.distanceFrom(analysis) < bestDistance) {
        bestUnique = puzzle;
        bestDistance = profile.distanceFrom(analysis);
      }

      if (profile.accepts(analysis)) {
        bestMatch = _withAnalysis(puzzle, analysis);
        _debugLog(level, difficulty, puzzle, analysis, attempt + 1);
        return bestMatch;
      }
    }

    if (bestUnique != null) {
      final analysis =
          _solver.analyze(bestUnique, nodeLimit: profile.searchNodeLimit);
      _debugLog(level, difficulty, bestUnique, analysis, profile.maxAttempts);
      return _withAnalysis(bestUnique, analysis);
    }

    return _fallbackPuzzle(level, difficulty, baseSeed, profile);
  }

  Puzzle _fallbackPuzzle(
    int level,
    PuzzleDifficulty difficulty,
    int baseSeed,
    DifficultyProfile profile,
  ) {
    final rng = Random(baseSeed + 424242);
    final rows = _rowsFor(level, profile);
    final cols = _colsFor(level, profile);
    for (var attempt = 0; attempt < 50; attempt++) {
      final parts = _partition(
        rows,
        cols,
        Random(baseSeed + attempt),
        maxArea: profile.maxMaxArea,
        stopProb: profile.stopProb,
      );
      if (parts.any((r) => r.area < 2)) continue;
      final clues = _placeClues(parts, difficulty, rng);
      final puzzle = Puzzle(
        level: level,
        difficulty: difficulty,
        rows: rows,
        cols: cols,
        clues: clues,
        solution: parts,
      );
      if (_solver.countSolutions(puzzle, nodeLimit: profile.searchNodeLimit) == 1) {
        return puzzle;
      }
    }
    throw StateError('Failed to generate a unique puzzle for level $level');
  }

  int _seedForLevel(int level, PuzzleDifficulty difficulty) =>
      (level * 2654435761 ^ difficulty.index * 1597334677) & 0x7fffffff;

  int _rowsFor(int level, DifficultyProfile profile) {
    final span = profile.maxRows - profile.minRows;
    return profile.minRows + (level ~/ 8).clamp(0, span);
  }

  int _colsFor(int level, DifficultyProfile profile) {
    final span = profile.maxCols - profile.minCols;
    return profile.minCols + (level ~/ 7).clamp(0, span);
  }

  int _maxAreaFor(int level, DifficultyProfile profile) {
    final span = profile.maxMaxArea - profile.minMaxArea;
    return profile.minMaxArea + (level ~/ 5).clamp(0, span);
  }

  List<Clue> _placeClues(
    List<GridRect> parts,
    PuzzleDifficulty difficulty,
    Random rng,
  ) {
    final clues = <Clue>[];
    for (final r in parts) {
      final candidates = <(int, int)>[];
      for (var rr = r.row; rr < r.bottom; rr++) {
        for (var cc = r.col; cc < r.right; cc++) {
          candidates.add((rr, cc));
        }
      }
      candidates.sort((a, b) {
        final scoreA = _cluePositionScore(a.$1, a.$2, r, difficulty, rng);
        final scoreB = _cluePositionScore(b.$1, b.$2, r, difficulty, rng);
        return scoreB.compareTo(scoreA);
      });
      final pick = candidates.first;
      clues.add(Clue(pick.$1, pick.$2, r.area));
    }
    return clues;
  }

  double _cluePositionScore(
    int row,
    int col,
    GridRect rect,
    PuzzleDifficulty difficulty,
    Random rng,
  ) {
    final centerR = rect.row + rect.height / 2;
    final centerC = rect.col + rect.width / 2;
    final dist = (row - centerR).abs() + (col - centerC).abs();
    final maxDist = rect.height + rect.width;
    final edgeScore = dist / maxDist;
    final centerScore = 1.0 - edgeScore;
    final jitter = rng.nextDouble() * 0.15;

    return switch (difficulty) {
      PuzzleDifficulty.easy => centerScore + jitter,
      PuzzleDifficulty.medium => rng.nextDouble(),
      PuzzleDifficulty.hard => edgeScore + jitter,
    };
  }

  List<GridRect> _partition(
    int rows,
    int cols,
    Random rng, {
    required int maxArea,
    required double stopProb,
    int minArea = 2,
  }) {
    final result = <GridRect>[];
    final stack = <GridRect>[GridRect(0, 0, cols, rows)];

    while (stack.isNotEmpty) {
      final r = stack.removeLast();
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

  List<int> _validCuts(int span, int other, int minArea) {
    if (span < 2) return const [];
    final unit = (minArea + other - 1) ~/ other;
    final lo = unit < 1 ? 1 : unit;
    final hi = span - lo;
    if (lo > hi) return const [];
    return [for (var k = lo; k <= hi; k++) k];
  }

  Puzzle _withAnalysis(Puzzle puzzle, DifficultyAnalysis analysis) {
    if (kDebugMode) {
      return Puzzle(
        level: puzzle.level,
        difficulty: puzzle.difficulty,
        rows: puzzle.rows,
        cols: puzzle.cols,
        clues: puzzle.clues,
        solution: puzzle.solution,
        difficultyAnalysis: analysis,
      );
    }
    return puzzle;
  }

  void _debugLog(
    int level,
    PuzzleDifficulty difficulty,
    Puzzle puzzle,
    DifficultyAnalysis analysis,
    int attempts,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      'Level $level | ${difficulty.name} | ${puzzle.cols}x${puzzle.rows} | '
      'clues ${analysis.clueCount} | score ${analysis.score} | '
      'avg candidates ${analysis.averageInitialCandidates.toStringAsFixed(1)} | '
      'forced ${analysis.initialForcedClues}/${analysis.clueCount} | '
      'rounds ${analysis.propagationRounds} | depth ${analysis.maxSearchDepth} | '
      'nodes ${analysis.visitedNodes} | solutions ${analysis.solutionCount} | '
      'attempts $attempts',
    );
  }
}
