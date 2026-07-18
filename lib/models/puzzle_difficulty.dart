import 'package:flutter/foundation.dart';

/// Logical difficulty tier for puzzle generation and player selection.
enum PuzzleDifficulty {
  easy,
  medium,
  hard,
}

/// Metrics from logical-only solving (clue single + cell single, no branching).
@immutable
class LogicalSolveAnalysis {
  final bool solved;
  final int clueCount;
  final int cellCount;
  final double averageInitialCandidates;
  final int maxInitialCandidates;
  final int minInitialCandidates;
  final int initialForcedClues;
  final int initialForcedCells;
  final int propagationRounds;
  final int forcedPlacements;

  const LogicalSolveAnalysis({
    required this.solved,
    required this.clueCount,
    required this.cellCount,
    required this.averageInitialCandidates,
    required this.maxInitialCandidates,
    required this.minInitialCandidates,
    required this.initialForcedClues,
    required this.initialForcedCells,
    required this.propagationRounds,
    required this.forcedPlacements,
  });

  double get clueDensity => cellCount == 0 ? 0 : clueCount / cellCount;

  double get averageRegionArea => clueCount == 0 ? 0 : cellCount / clueCount;

  double get initialForcedRatio =>
      clueCount == 0 ? 0 : initialForcedClues / clueCount;
}

/// Combined diagnostics for a generated puzzle (debug / ranking).
@immutable
class DifficultyAnalysis {
  final LogicalSolveAnalysis logical;
  final int solutionCount;
  final int uniquenessNodes;
  final int score;
  final int targetClueCount;

  const DifficultyAnalysis({
    required this.logical,
    required this.solutionCount,
    required this.uniquenessNodes,
    required this.score,
    required this.targetClueCount,
  });

  bool get isUnique => solutionCount == 1;

  int get clueCount => logical.clueCount;

  int get cellCount => logical.cellCount;

  double get averageInitialCandidates => logical.averageInitialCandidates;

  int get maxInitialCandidates => logical.maxInitialCandidates;

  int get initialForcedClues => logical.initialForcedClues;

  int get initialForcedCells => logical.initialForcedCells;

  int get propagationRounds => logical.propagationRounds;

  double get clueDensity => logical.clueDensity;

  double get averageRegionArea => logical.averageRegionArea;

  double get initialForcedRatio => logical.initialForcedRatio;
}

/// Soft quality thresholds for ranking candidates within a tier.
@immutable
class DifficultyProfile {
  final PuzzleDifficulty difficulty;
  final double? minInitialForcedRatio;
  final double? maxInitialForcedRatio;
  final double? minAverageInitialCandidates;
  final double? maxAverageInitialCandidates;
  final int? minPropagationRounds;

  const DifficultyProfile({
    required this.difficulty,
    this.minInitialForcedRatio,
    this.maxInitialForcedRatio,
    this.minAverageInitialCandidates,
    this.maxAverageInitialCandidates,
    this.minPropagationRounds,
  });

  /// Lower is better. Only for structurally valid candidates.
  int softDistanceFrom(LogicalSolveAnalysis logical) {
    var d = 0;
    if (minInitialForcedRatio != null &&
        logical.initialForcedRatio < minInitialForcedRatio!) {
      d += ((minInitialForcedRatio! - logical.initialForcedRatio) * 100).round();
    }
    if (maxInitialForcedRatio != null &&
        logical.initialForcedRatio > maxInitialForcedRatio!) {
      d += ((logical.initialForcedRatio - maxInitialForcedRatio!) * 100).round();
    }
    if (minAverageInitialCandidates != null &&
        logical.averageInitialCandidates < minAverageInitialCandidates!) {
      d += ((minAverageInitialCandidates! - logical.averageInitialCandidates) *
              20)
          .round();
    }
    if (maxAverageInitialCandidates != null &&
        logical.averageInitialCandidates > maxAverageInitialCandidates!) {
      d += ((logical.averageInitialCandidates - maxAverageInitialCandidates!) *
              20)
          .round();
    }
    if (minPropagationRounds != null &&
        logical.propagationRounds < minPropagationRounds!) {
      d += (minPropagationRounds! - logical.propagationRounds) * 5;
    }
    return d;
  }

  bool acceptsSoftTargets(LogicalSolveAnalysis logical) =>
      softDistanceFrom(logical) == 0;
}

/// Centralized difficulty tuning and structural rules.
abstract final class DifficultyProfiles {
  static const maxPartitionAttempts = 80;
  static const cluePlacementAttempts = 8;
  static const searchNodeLimit = 5000;
  static const minRegionArea = 2;

  static const easy = DifficultyProfile(
    difficulty: PuzzleDifficulty.easy,
    minInitialForcedRatio: 0.25,
    maxAverageInitialCandidates: 3.0,
  );

  static const medium = DifficultyProfile(
    difficulty: PuzzleDifficulty.medium,
    minInitialForcedRatio: 0.10,
    maxInitialForcedRatio: 0.35,
  );

  static const hard = DifficultyProfile(
    difficulty: PuzzleDifficulty.hard,
    maxInitialForcedRatio: 0.20,
    minAverageInitialCandidates: 2.5,
    minPropagationRounds: 2,
  );

  static DifficultyProfile forDifficulty(PuzzleDifficulty d) => switch (d) {
        PuzzleDifficulty.easy => easy,
        PuzzleDifficulty.medium => medium,
        PuzzleDifficulty.hard => hard,
      };

  static int boardSizeFor(PuzzleDifficulty difficulty, int level) {
    switch (difficulty) {
      case PuzzleDifficulty.easy:
        return 6;
      case PuzzleDifficulty.medium:
        return 7;
      case PuzzleDifficulty.hard:
        return level <= 20 ? 8 : 9;
    }
  }

  static int minCluesFor(PuzzleDifficulty difficulty, int level) {
    switch (difficulty) {
      case PuzzleDifficulty.easy:
        return 13;
      case PuzzleDifficulty.medium:
        return 12;
      case PuzzleDifficulty.hard:
        return level <= 20 ? 10 : 11;
    }
  }

  static int maxCluesFor(PuzzleDifficulty difficulty, int level) {
    switch (difficulty) {
      case PuzzleDifficulty.easy:
        return 16;
      case PuzzleDifficulty.medium:
        return 15;
      case PuzzleDifficulty.hard:
        return level <= 20 ? 13 : 14;
    }
  }

  /// Deterministic target region / clue count for [level] within tier range.
  static int targetClueCountFor(PuzzleDifficulty difficulty, int level) {
    final min = minCluesFor(difficulty, level);
    final max = maxCluesFor(difficulty, level);
    final high = switch (difficulty) {
      PuzzleDifficulty.easy => 16,
      PuzzleDifficulty.medium => 15,
      PuzzleDifficulty.hard => level <= 20 ? 13 : 14,
    };
    final low = min;
    final startLevel = switch (difficulty) {
      PuzzleDifficulty.easy => 1,
      PuzzleDifficulty.medium => 1,
      PuzzleDifficulty.hard => level <= 20 ? 1 : 21,
    };
    final endLevel = switch (difficulty) {
      PuzzleDifficulty.easy => 20,
      PuzzleDifficulty.medium => 20,
      PuzzleDifficulty.hard => level <= 20 ? 20 : 40,
    };
    return _lerpClue(level, startLevel, endLevel, high, low)
        .clamp(min, max);
  }

  static int _lerpClue(
    int level,
    int startLevel,
    int endLevel,
    int highClues,
    int lowClues,
  ) {
    if (level <= startLevel) return highClues;
    if (level >= endLevel) return lowClues;
    final t = (level - startLevel) / (endLevel - startLevel);
    return (highClues + (lowClues - highClues) * t).round();
  }

  /// Internal 0–100 score from logical metrics (not tier assignment).
  static int scoreFrom({
    required int boardSize,
    required LogicalSolveAnalysis logical,
  }) {
    final sizeComponent = (boardSize / 9).clamp(0.0, 1.0);
    final densityComponent =
        (logical.clueDensity / 0.30).clamp(0.0, 1.0); // ~16/36 ≈ 0.44 max
    final regionComponent =
        (1.0 - (logical.averageRegionArea / 9)).clamp(0.0, 1.0);
    final densityBlend = (densityComponent + regionComponent) / 2;
    final ambiguity =
        ((logical.averageInitialCandidates - 1) / 5).clamp(0.0, 1.0);
    final forcedDifficulty =
        (1.0 - logical.initialForcedRatio).clamp(0.0, 1.0);
    final chainDifficulty =
        (logical.propagationRounds / 12).clamp(0.0, 1.0);

    return (25 * sizeComponent +
            25 * densityBlend +
            20 * ambiguity +
            20 * forcedDifficulty +
            10 * chainDifficulty)
        .round()
        .clamp(0, 100);
  }
}

extension PuzzleDifficultyUi on PuzzleDifficulty {
  String get label => switch (this) {
        PuzzleDifficulty.easy => 'Easy',
        PuzzleDifficulty.medium => 'Medium',
        PuzzleDifficulty.hard => 'Hard',
      };

  String get description => switch (this) {
        PuzzleDifficulty.easy => '6×6 with more clues and clearer openings.',
        PuzzleDifficulty.medium => '7×7 with fewer clues and longer deductions.',
        PuzzleDifficulty.hard => 'Large grids, fewer clues, deeper logic.',
      };
}
