import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/puzzle.dart';
import '../models/puzzle_difficulty.dart';
import 'puzzle_solver.dart';

/// Generates Shikaku puzzles with structural tier rules and logical solvability.
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
    final size = DifficultyProfiles.boardSizeFor(difficulty, level);
    final targetClues = DifficultyProfiles.targetClueCountFor(difficulty, level);
    final minClues = DifficultyProfiles.minCluesFor(difficulty, level);
    final maxClues = DifficultyProfiles.maxCluesFor(difficulty, level);

    Puzzle? bestStructural;
    DifficultyAnalysis? bestStructuralAnalysis;
    var bestSoftDistance = 1 << 30;

    for (var partitionAttempt = 0;
        partitionAttempt < DifficultyProfiles.maxPartitionAttempts;
        partitionAttempt++) {
      final partitionSeed = _mixSeed(baseSeed, partitionAttempt);
      final partitionRng = Random(partitionSeed);
      final parts = _partitionToTarget(
        size,
        partitionRng,
        targetRegionCount: targetClues,
      );
      if (parts == null) continue;

      for (var placementAttempt = 0;
          placementAttempt < DifficultyProfiles.cluePlacementAttempts;
          placementAttempt++) {
        final placementSeed = _mixSeed(partitionSeed, placementAttempt + 1);
        final placementRng = Random(placementSeed);
        final clues = _placeClues(
          parts,
          difficulty,
          placementRng,
          placementAttempt,
        );
        final puzzle = Puzzle(
          level: level,
          difficulty: difficulty,
          rows: size,
          cols: size,
          clues: clues,
          solution: parts,
        );

        if (!_meetsStructuralShape(puzzle, size, minClues, maxClues)) continue;

        final logical = _solver.analyzeLogically(puzzle);
        if (!logical.solved) continue;

        final uniqueness = _solver.uniquenessResult(
          puzzle,
          limit: 2,
          nodeLimit: DifficultyProfiles.searchNodeLimit,
        );
        if (uniqueness.solutionCount != 1) continue;

        final analysis = DifficultyAnalysis(
          logical: logical,
          solutionCount: 1,
          uniquenessNodes: uniqueness.visitedNodes,
          score: DifficultyProfiles.scoreFrom(
            boardSize: size,
            logical: logical,
          ),
          targetClueCount: targetClues,
        );

        final softDistance = profile.softDistanceFrom(logical);
        if (softDistance < bestSoftDistance) {
          bestSoftDistance = softDistance;
          bestStructural = puzzle;
          bestStructuralAnalysis = analysis;
        }

        if (profile.acceptsSoftTargets(logical)) {
          _debugLog(
            level: level,
            difficulty: difficulty,
            puzzle: puzzle,
            analysis: analysis,
            partitionAttempt: partitionAttempt + 1,
            placementAttempt: placementAttempt + 1,
            usedFallback: false,
          );
          return _withAnalysis(puzzle, analysis);
        }
      }
    }

    if (bestStructural != null && bestStructuralAnalysis != null) {
      _debugLog(
        level: level,
        difficulty: difficulty,
        puzzle: bestStructural,
        analysis: bestStructuralAnalysis,
        partitionAttempt: DifficultyProfiles.maxPartitionAttempts,
        placementAttempt: DifficultyProfiles.cluePlacementAttempts,
        usedFallback: true,
      );
      return _withAnalysis(bestStructural, bestStructuralAnalysis);
    }

    throw StateError(
      'Failed to generate structurally valid puzzle for '
      '$difficulty level $level (${size}x$size, target clues $targetClues, '
      'partition attempts ${DifficultyProfiles.maxPartitionAttempts}, '
      'placement attempts ${DifficultyProfiles.cluePlacementAttempts})',
    );
  }

  bool _meetsStructuralShape(
    Puzzle puzzle,
    int size,
    int minClues,
    int maxClues,
  ) {
    if (puzzle.rows != size || puzzle.cols != size) return false;
    if (puzzle.rows != puzzle.cols) return false;
    if (puzzle.clues.length != puzzle.solution.length) return false;
    if (puzzle.clues.length < minClues || puzzle.clues.length > maxClues) {
      return false;
    }
    if (puzzle.solution.any((r) => r.area < DifficultyProfiles.minRegionArea)) {
      return false;
    }
    final totalArea = puzzle.solution.fold<int>(0, (s, r) => s + r.area);
    if (totalArea != puzzle.cellCount) return false;
    for (var i = 0; i < puzzle.clues.length; i++) {
      if (puzzle.clues[i].value != puzzle.solution[i].area) return false;
      if (!puzzle.solution[i]
          .containsCell(puzzle.clues[i].row, puzzle.clues[i].col)) {
        return false;
      }
    }
    return true;
  }

  List<GridRect>? _partitionToTarget(
    int size,
    Random rng, {
    required int targetRegionCount,
    int minRegionArea = DifficultyProfiles.minRegionArea,
  }) {
    if (targetRegionCount < 1) return null;
    if (targetRegionCount == 1) {
      final single = GridRect(0, 0, size, size);
      return single.area >= minRegionArea ? [single] : null;
    }

    var regions = <GridRect>[GridRect(0, 0, size, size)];

    while (regions.length < targetRegionCount) {
      final splittable = <int>[];
      for (var i = 0; i < regions.length; i++) {
        if (_splittableCuts(regions[i], minRegionArea).isNotEmpty) {
          splittable.add(i);
        }
      }
      if (splittable.isEmpty) return null;

      splittable.sort((a, b) => regions[b].area.compareTo(regions[a].area));
      final pickFrom = splittable.take(min(3, splittable.length)).toList();
      final regionIndex = pickFrom[rng.nextInt(pickFrom.length)];
      final region = regions[regionIndex];
      final cuts = _splittableCuts(region, minRegionArea);
      final cut = cuts[rng.nextInt(cuts.length)];

      final children = cut.vertical
          ? [
              GridRect(region.row, region.col, cut.offset, region.height),
              GridRect(
                region.row,
                region.col + cut.offset,
                region.width - cut.offset,
                region.height,
              ),
            ]
          : [
              GridRect(region.row, region.col, region.width, cut.offset),
              GridRect(
                region.row + cut.offset,
                region.col,
                region.width,
                region.height - cut.offset,
              ),
            ];

      if (children.any((c) => c.area < minRegionArea)) return null;

      regions = [
        ...regions.sublist(0, regionIndex),
        ...children,
        ...regions.sublist(regionIndex + 1),
      ];
    }

    if (regions.length != targetRegionCount) return null;
    if (regions.any((r) => r.area < minRegionArea)) return null;
    return regions;
  }

  List<_Cut> _splittableCuts(GridRect region, int minArea) {
    final cuts = <_Cut>[];
    for (final cut in _validCuts(region.width, region.height, minArea)) {
      cuts.add(cut);
    }
    for (final cut in _validCuts(region.height, region.width, minArea)) {
      cuts.add(_Cut(vertical: false, offset: cut.offset));
    }
    return cuts;
  }

  List<_Cut> _validCuts(int span, int other, int minArea) {
    if (span < 2) return const [];
    final unit = (minArea + other - 1) ~/ other;
    final lo = unit < 1 ? 1 : unit;
    final hi = span - lo;
    if (lo > hi) return const [];
    return [
      for (var k = lo; k <= hi; k++) _Cut(vertical: true, offset: k),
    ];
  }

  List<Clue> _placeClues(
    List<GridRect> parts,
    PuzzleDifficulty difficulty,
    Random rng,
    int placementAttempt,
  ) {
    final clues = <Clue>[];
    for (var i = 0; i < parts.length; i++) {
      final r = parts[i];
      final candidates = <(int, int)>[];
      for (var rr = r.row; rr < r.bottom; rr++) {
        for (var cc = r.col; cc < r.right; cc++) {
          candidates.add((rr, cc));
        }
      }
      candidates.sort((a, b) {
        final scoreA = _placementScore(
          a.$1,
          a.$2,
          r,
          difficulty,
          rng,
          placementAttempt,
          i,
        );
        final scoreB = _placementScore(
          b.$1,
          b.$2,
          r,
          difficulty,
          rng,
          placementAttempt,
          i,
        );
        return scoreB.compareTo(scoreA);
      });
      final pick = candidates.first;
      clues.add(Clue(pick.$1, pick.$2, r.area));
    }
    return clues;
  }

  double _placementScore(
    int row,
    int col,
    GridRect rect,
    PuzzleDifficulty difficulty,
    Random rng,
    int placementAttempt,
    int regionIndex,
  ) {
    final centerR = rect.row + rect.height / 2;
    final centerC = rect.col + rect.width / 2;
    final dist = (row - centerR).abs() + (col - centerC).abs();
    final maxDist = rect.height + rect.width;
    final edgeScore = dist / maxDist;
    final centerScore = 1.0 - edgeScore;
    final jitter = rng.nextDouble() * 0.2;

    return switch (difficulty) {
      PuzzleDifficulty.easy => centerScore + jitter,
      PuzzleDifficulty.medium =>
        (placementAttempt + regionIndex).isEven ? centerScore : edgeScore + jitter,
      PuzzleDifficulty.hard => edgeScore + jitter,
    };
  }

  int _seedForLevel(int level, PuzzleDifficulty difficulty) =>
      (level * 2654435761 ^ difficulty.index * 1597334677) & 0x7fffffff;

  int _mixSeed(int a, int b) => (a ^ (b * 9973 + 0x9e3779b9)) & 0x7fffffff;

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

  void _debugLog({
    required int level,
    required PuzzleDifficulty difficulty,
    required Puzzle puzzle,
    required DifficultyAnalysis analysis,
    required int partitionAttempt,
    required int placementAttempt,
    required bool usedFallback,
  }) {
    if (!kDebugMode) return;
    final logical = analysis.logical;
    debugPrint(
      'Level $level | ${difficulty.name} | ${puzzle.cols}x${puzzle.rows} | '
      'target clues ${analysis.targetClueCount} | actual clues ${analysis.clueCount} | '
      'score ${analysis.score} | density ${logical.clueDensity.toStringAsFixed(3)} | '
      'avg area ${logical.averageRegionArea.toStringAsFixed(2)} | '
      'avg candidates ${logical.averageInitialCandidates.toStringAsFixed(1)} | '
      'initial forced clues ${logical.initialForcedClues}/${logical.clueCount} | '
      'initial forced cells ${logical.initialForcedCells} | '
      'rounds ${logical.propagationRounds} | logical solved ${logical.solved} | '
      'solutions ${analysis.solutionCount} | uniqueness nodes ${analysis.uniquenessNodes} | '
      'partition attempt $partitionAttempt | placement attempt $placementAttempt | '
      'fallback $usedFallback',
    );
  }
}

class _Cut {
  final bool vertical;
  final int offset;

  const _Cut({required this.vertical, required this.offset});
}
