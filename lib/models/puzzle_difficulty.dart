import 'package:flutter/foundation.dart';

/// Logical difficulty tier for puzzle generation and player selection.
enum PuzzleDifficulty {
  easy,
  medium,
  hard,
}

/// Metrics produced by [PuzzleSolver.analyze] for a candidate board.
@immutable
class DifficultyAnalysis {
  final int solutionCount;
  final int clueCount;
  final int cellCount;
  final double averageInitialCandidates;
  final int maxInitialCandidates;
  final int initialForcedClues;
  final int propagationRounds;
  final int forcedPlacements;
  final int guesses;
  final int maxSearchDepth;
  final int visitedNodes;
  final int score;

  const DifficultyAnalysis({
    required this.solutionCount,
    required this.clueCount,
    required this.cellCount,
    required this.averageInitialCandidates,
    required this.maxInitialCandidates,
    required this.initialForcedClues,
    required this.propagationRounds,
    required this.forcedPlacements,
    required this.guesses,
    required this.maxSearchDepth,
    required this.visitedNodes,
    required this.score,
  });

  double get initialForcedRatio =>
      clueCount == 0 ? 0 : initialForcedClues / clueCount;

  bool get isUnique => solutionCount == 1;
}

/// Generation settings and acceptance rules for a difficulty tier.
@immutable
class DifficultyProfile {
  final PuzzleDifficulty difficulty;
  final int minRows;
  final int maxRows;
  final int minCols;
  final int maxCols;
  final int minScore;
  final int maxScore;
  final int maxSearchDepth;
  final double? minInitialForcedRatio;
  final double? maxAverageInitialCandidates;
  final int maxVisitedNodes;
  final double stopProb;
  final int minMaxArea;
  final int maxMaxArea;
  final int maxAttempts;
  final int searchNodeLimit;

  const DifficultyProfile({
    required this.difficulty,
    required this.minRows,
    required this.maxRows,
    required this.minCols,
    required this.maxCols,
    required this.minScore,
    required this.maxScore,
    required this.maxSearchDepth,
    this.minInitialForcedRatio,
    this.maxAverageInitialCandidates,
    required this.maxVisitedNodes,
    required this.stopProb,
    required this.minMaxArea,
    required this.maxMaxArea,
    required this.maxAttempts,
    required this.searchNodeLimit,
  });

  bool accepts(DifficultyAnalysis analysis) {
    if (!analysis.isUnique) return false;
    if (analysis.maxSearchDepth > maxSearchDepth) return false;
    if (analysis.visitedNodes > maxVisitedNodes) return false;
    if (analysis.score < minScore || analysis.score > maxScore) return false;
    if (minInitialForcedRatio != null &&
        analysis.initialForcedRatio < minInitialForcedRatio!) {
      return false;
    }
    if (maxAverageInitialCandidates != null &&
        analysis.averageInitialCandidates > maxAverageInitialCandidates!) {
      return false;
    }
    return true;
  }

  /// How close [analysis] is to this profile (lower is better). Only meaningful
  /// for unique puzzles.
  int distanceFrom(DifficultyAnalysis analysis) {
    var d = 0;
    if (analysis.score < minScore) {
      d += (minScore - analysis.score) * 2;
    } else if (analysis.score > maxScore) {
      d += (analysis.score - maxScore) * 2;
    }
    if (analysis.maxSearchDepth > maxSearchDepth) {
      d += (analysis.maxSearchDepth - maxSearchDepth) * 15;
    }
    if (minInitialForcedRatio != null &&
        analysis.initialForcedRatio < minInitialForcedRatio!) {
      d += ((minInitialForcedRatio! - analysis.initialForcedRatio) * 100).round();
    }
    if (maxAverageInitialCandidates != null &&
        analysis.averageInitialCandidates > maxAverageInitialCandidates!) {
      d += ((analysis.averageInitialCandidates - maxAverageInitialCandidates!) *
              20)
          .round();
    }
    if (analysis.visitedNodes > maxVisitedNodes) {
      d += analysis.visitedNodes - maxVisitedNodes;
    }
    return d;
  }
}

/// Centralized difficulty tuning constants.
abstract final class DifficultyProfiles {
  static const easy = DifficultyProfile(
    difficulty: PuzzleDifficulty.easy,
    minRows: 6,
    maxRows: 7,
    minCols: 7,
    maxCols: 8,
    minScore: 0,
    maxScore: 35,
    maxSearchDepth: 0,
    minInitialForcedRatio: 0.25,
    maxAverageInitialCandidates: 3.0,
    maxVisitedNodes: 500,
    stopProb: 0.40,
    minMaxArea: 10,
    maxMaxArea: 14,
    maxAttempts: 200,
    searchNodeLimit: 5000,
  );

  static const medium = DifficultyProfile(
    difficulty: PuzzleDifficulty.medium,
    minRows: 7,
    maxRows: 8,
    minCols: 8,
    maxCols: 9,
    minScore: 30,
    maxScore: 65,
    maxSearchDepth: 1,
    maxVisitedNodes: 2000,
    stopProb: 0.28,
    minMaxArea: 8,
    maxMaxArea: 16,
    maxAttempts: 200,
    searchNodeLimit: 5000,
  );

  static const hard = DifficultyProfile(
    difficulty: PuzzleDifficulty.hard,
    minRows: 8,
    maxRows: 9,
    minCols: 9,
    maxCols: 11,
    minScore: 55,
    maxScore: 100,
    maxSearchDepth: 3,
    maxVisitedNodes: 5000,
    stopProb: 0.18,
    minMaxArea: 6,
    maxMaxArea: 12,
    maxAttempts: 200,
    searchNodeLimit: 5000,
  );

  static DifficultyProfile forDifficulty(PuzzleDifficulty d) => switch (d) {
        PuzzleDifficulty.easy => easy,
        PuzzleDifficulty.medium => medium,
        PuzzleDifficulty.hard => hard,
      };
}

extension PuzzleDifficultyUi on PuzzleDifficulty {
  String get label => switch (this) {
        PuzzleDifficulty.easy => 'Easy',
        PuzzleDifficulty.medium => 'Medium',
        PuzzleDifficulty.hard => 'Hard',
      };

  String get description => switch (this) {
        PuzzleDifficulty.easy => 'Bigger rectangles, gentler logic.',
        PuzzleDifficulty.medium => 'A balanced challenge.',
        PuzzleDifficulty.hard => 'Tight grids, sharp thinking.',
      };
}
