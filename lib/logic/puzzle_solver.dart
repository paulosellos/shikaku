import 'package:flutter/foundation.dart';

import '../models/puzzle.dart';
import '../models/puzzle_difficulty.dart';

/// Identifies one enumerated rectangle candidate for a clue.
@immutable
class _CandidateRef {
  final int clueIndex;
  final int candidateIndex;

  const _CandidateRef(this.clueIndex, this.candidateIndex);

  @override
  bool operator ==(Object other) =>
      other is _CandidateRef &&
      other.clueIndex == clueIndex &&
      other.candidateIndex == candidateIndex;

  @override
  int get hashCode => Object.hash(clueIndex, candidateIndex);
}

/// A rectangle that could cover a clue, used only by the logical solver.
class _Candidate {
  final int clueIndex;
  final GridRect rect;
  final Set<int> cellIndices;

  const _Candidate({
    required this.clueIndex,
    required this.rect,
    required this.cellIndices,
  });
}

/// Result of a bounded uniqueness search.
@immutable
class UniquenessResult {
  final int solutionCount;
  final int visitedNodes;

  const UniquenessResult({
    required this.solutionCount,
    required this.visitedNodes,
  });
}

/// Solves and analyzes Shikaku puzzles from clues only (never uses the stored
/// generator solution).
class PuzzleSolver {
  const PuzzleSolver();

  int countSolutions(
    Puzzle puzzle, {
    int limit = 2,
    int nodeLimit = 5000,
  }) =>
      _countSolutionsInternal(puzzle, limit: limit, nodeLimit: nodeLimit)
          .solutionCount;

  UniquenessResult uniquenessResult(
    Puzzle puzzle, {
    int limit = 2,
    int nodeLimit = 5000,
  }) =>
      _countSolutionsInternal(puzzle, limit: limit, nodeLimit: nodeLimit);

  /// Propagates clue-single and cell-single rules until stuck. Never branches.
  LogicalSolveAnalysis analyzeLogically(Puzzle puzzle) {
    final candidates = _enumerateCandidates(puzzle);
    final clueCount = puzzle.clues.length;
    final cellCount = puzzle.cellCount;

    if (candidates.any((c) => c.isEmpty)) {
      return _emptyLogical(clueCount, cellCount);
    }

    final initialCounts = candidates.map((c) => c.length).toList();
    final avgCandidates = initialCounts.reduce((a, b) => a + b) / clueCount;
    final maxCandidates = initialCounts.reduce((a, b) => a > b ? a : b);
    final minCandidates = initialCounts.reduce((a, b) => a < b ? a : b);

    final remaining = List.generate(
      clueCount,
      (i) => Set<int>.from(List.generate(candidates[i].length, (j) => j)),
    );
    final selected = <int, int>{};
    final covered = <int>{};
    final propagationRounds = _Counter();
    final forcedPlacements = _Counter();

    final initialForcedClues = _countInitialForcedClues(candidates);
    final initialForcedCells = _countInitialForcedCells(candidates, cellCount);

    final ok = _propagate(
      puzzle,
      candidates,
      remaining,
      selected,
      covered,
      propagationRounds,
      forcedPlacements,
    );

    final solved = ok &&
        selected.length == clueCount &&
        covered.length == cellCount;

    return LogicalSolveAnalysis(
      solved: solved,
      clueCount: clueCount,
      cellCount: cellCount,
      averageInitialCandidates: avgCandidates,
      maxInitialCandidates: maxCandidates,
      minInitialCandidates: minCandidates,
      initialForcedClues: initialForcedClues,
      initialForcedCells: initialForcedCells,
      propagationRounds: propagationRounds.value,
      forcedPlacements: forcedPlacements.value,
    );
  }

  /// Legacy combined API — prefer [analyzeLogically] + [countSolutions].
  DifficultyAnalysis analyze(Puzzle puzzle, {int nodeLimit = 5000}) {
    final logical = analyzeLogically(puzzle);
    final uniqueness = uniquenessResult(puzzle, nodeLimit: nodeLimit);
    return DifficultyAnalysis(
      logical: logical,
      solutionCount: uniqueness.solutionCount.clamp(0, 2),
      uniquenessNodes: uniqueness.visitedNodes,
      score: DifficultyProfiles.scoreFrom(
        boardSize: puzzle.rows,
        logical: logical,
      ),
      targetClueCount: puzzle.clues.length,
    );
  }

  UniquenessResult _countSolutionsInternal(
    Puzzle puzzle, {
    required int limit,
    required int nodeLimit,
  }) {
    final candidates = _enumerateCandidates(puzzle);
    if (candidates.any((c) => c.isEmpty)) {
      return const UniquenessResult(solutionCount: 0, visitedNodes: 0);
    }

    final remaining = List.generate(
      puzzle.clues.length,
      (i) => Set<int>.from(List.generate(candidates[i].length, (j) => j)),
    );
    var count = 0;
    final visitedNodes = _Counter();
    _search(
      puzzle,
      candidates,
      remaining,
      {},
      {},
      0,
      limit: limit,
      nodeLimit: nodeLimit,
      onSolution: () => count++,
      visitedNodes: visitedNodes,
      guesses: _Counter(),
      getSolutionCount: () => count,
    );
    return UniquenessResult(
      solutionCount: count.clamp(0, 2),
      visitedNodes: visitedNodes.value,
    );
  }

  List<List<_Candidate>> _enumerateCandidates(Puzzle puzzle) {
    final result = <List<_Candidate>>[];
    for (var i = 0; i < puzzle.clues.length; i++) {
      final clue = puzzle.clues[i];
      final area = clue.value;
      final seen = <String>{};
      final list = <_Candidate>[];

      for (var w = 1; w <= area; w++) {
        if (area % w != 0) continue;
        final h = area ~/ w;
        if (w > puzzle.cols || h > puzzle.rows) continue;

        final maxRowBound = puzzle.rows - h;
        final maxColBound = puzzle.cols - w;
        if (maxRowBound < 0 || maxColBound < 0) continue;

        final minRow = (clue.row - h + 1).clamp(0, maxRowBound);
        final maxRow = clue.row.clamp(0, maxRowBound);
        final minCol = (clue.col - w + 1).clamp(0, maxColBound);
        final maxCol = clue.col.clamp(0, maxColBound);

        for (var r = minRow; r <= maxRow; r++) {
          for (var c = minCol; c <= maxCol; c++) {
            final rect = GridRect(r, c, w, h);
            if (!rect.containsCell(clue.row, clue.col)) continue;

            var otherClues = 0;
            for (var j = 0; j < puzzle.clues.length; j++) {
              if (j == i) continue;
              if (rect.containsCell(puzzle.clues[j].row, puzzle.clues[j].col)) {
                otherClues++;
              }
            }
            if (otherClues > 0) continue;

            final key = '${rect.row},${rect.col},${rect.width},${rect.height}';
            if (seen.contains(key)) continue;
            seen.add(key);

            final cells = <int>{};
            for (var rr = rect.row; rr < rect.bottom; rr++) {
              for (var cc = rect.col; cc < rect.right; cc++) {
                cells.add(rr * puzzle.cols + cc);
              }
            }
            list.add(_Candidate(clueIndex: i, rect: rect, cellIndices: cells));
          }
        }
      }
      result.add(list);
    }
    return result;
  }

  int _countInitialForcedClues(List<List<_Candidate>> candidates) {
    var forced = 0;
    for (final list in candidates) {
      if (list.length == 1) forced++;
    }
    return forced;
  }

  int _countInitialForcedCells(
    List<List<_Candidate>> candidates,
    int cellCount,
  ) {
    var forced = 0;
    for (var cell = 0; cell < cellCount; cell++) {
      if (_candidateRefsForCell(candidates, cell, const {}).length == 1) {
        forced++;
      }
    }
    return forced;
  }

  Set<_CandidateRef> _candidateRefsForCell(
    List<List<_Candidate>> allCandidates,
    int cell,
    Set<int> selectedClues,
  ) {
    final refs = <_CandidateRef>{};
    for (var clue = 0; clue < allCandidates.length; clue++) {
      if (selectedClues.contains(clue)) continue;
      for (var ci = 0; ci < allCandidates[clue].length; ci++) {
        if (allCandidates[clue][ci].cellIndices.contains(cell)) {
          refs.add(_CandidateRef(clue, ci));
        }
      }
    }
    return refs;
  }

  Set<_CandidateRef> _activeCandidateRefsForCell(
    List<List<_Candidate>> allCandidates,
    List<Set<int>> remaining,
    Map<int, int> selected,
    int cell,
  ) {
    final refs = <_CandidateRef>{};
    for (var clue = 0; clue < remaining.length; clue++) {
      if (selected.containsKey(clue)) continue;
      for (final ci in remaining[clue]) {
        if (allCandidates[clue][ci].cellIndices.contains(cell)) {
          refs.add(_CandidateRef(clue, ci));
        }
      }
    }
    return refs;
  }

  bool _propagate(
    Puzzle puzzle,
    List<List<_Candidate>> allCandidates,
    List<Set<int>> remaining,
    Map<int, int> selected,
    Set<int> covered,
    _Counter propagationRounds,
    _Counter forcedPlacements,
  ) {
    var changed = true;
    while (changed) {
      changed = false;
      propagationRounds.value++;

      for (var clue = 0; clue < remaining.length; clue++) {
        if (selected.containsKey(clue)) continue;
        if (remaining[clue].isEmpty) return false;
        if (remaining[clue].length == 1) {
          final candIdx = remaining[clue].first;
          if (!_selectCandidate(
            allCandidates,
            remaining,
            selected,
            covered,
            clue,
            candIdx,
          )) {
            return false;
          }
          forcedPlacements.value++;
          changed = true;
        }
      }

      for (var cell = 0; cell < puzzle.cellCount; cell++) {
        if (covered.contains(cell)) continue;
        final refs = _activeCandidateRefsForCell(
          allCandidates,
          remaining,
          selected,
          cell,
        );
        if (refs.isEmpty) return false;
        if (refs.length == 1) {
          final ref = refs.first;
          if (!_selectCandidate(
            allCandidates,
            remaining,
            selected,
            covered,
            ref.clueIndex,
            ref.candidateIndex,
          )) {
            return false;
          }
          forcedPlacements.value++;
          changed = true;
        }
      }
    }
    return true;
  }

  bool _selectCandidate(
    List<List<_Candidate>> allCandidates,
    List<Set<int>> remaining,
    Map<int, int> selected,
    Set<int> covered,
    int clue,
    int candIdx,
  ) {
    if (selected.containsKey(clue)) return selected[clue] == candIdx;
    final cand = allCandidates[clue][candIdx];
    for (final cell in cand.cellIndices) {
      if (covered.contains(cell)) return false;
    }

    selected[clue] = candIdx;
    covered.addAll(cand.cellIndices);
    remaining[clue].clear();

    for (var other = 0; other < remaining.length; other++) {
      if (other == clue) continue;
      remaining[other].removeWhere((ci) {
        final otherCand = allCandidates[other][ci];
        return otherCand.cellIndices.any(covered.contains);
      });
      if (remaining[other].isEmpty && !selected.containsKey(other)) {
        return false;
      }
    }
    return true;
  }

  void _search(
    Puzzle puzzle,
    List<List<_Candidate>> allCandidates,
    List<Set<int>> remaining,
    Map<int, int> selected,
    Set<int> covered,
    int depth, {
    required int limit,
    required int nodeLimit,
    required void Function() onSolution,
    required _Counter visitedNodes,
    required _Counter guesses,
    required int Function() getSolutionCount,
  }) {
    if (getSolutionCount() >= limit) return;

    visitedNodes.value++;
    if (visitedNodes.value > nodeLimit) return;

    final remCopy = remaining.map(Set<int>.from).toList();
    final selCopy = Map<int, int>.from(selected);
    final covCopy = Set<int>.from(covered);
    final propRounds = _Counter();
    final forced = _Counter();

    if (!_propagate(
      puzzle,
      allCandidates,
      remCopy,
      selCopy,
      covCopy,
      propRounds,
      forced,
    )) {
      return;
    }

    if (selCopy.length == puzzle.clues.length &&
        covCopy.length == puzzle.cellCount) {
      onSolution();
      return;
    }

    var bestClue = -1;
    var bestCount = 999;
    for (var i = 0; i < remCopy.length; i++) {
      if (selCopy.containsKey(i)) continue;
      final n = remCopy[i].length;
      if (n > 1 && n < bestCount) {
        bestCount = n;
        bestClue = i;
      }
    }

    if (bestClue != -1) {
      final options = List<int>.from(remCopy[bestClue]);
      for (final candIdx in options) {
        if (getSolutionCount() >= limit) return;
        guesses.value++;
        final nextRem = remCopy.map(Set<int>.from).toList();
        final nextSel = Map<int, int>.from(selCopy);
        final nextCov = Set<int>.from(covCopy);
        if (_selectCandidate(
          allCandidates,
          nextRem,
          nextSel,
          nextCov,
          bestClue,
          candIdx,
        )) {
          _search(
            puzzle,
            allCandidates,
            nextRem,
            nextSel,
            nextCov,
            depth + 1,
            limit: limit,
            nodeLimit: nodeLimit,
            onSolution: onSolution,
            visitedNodes: visitedNodes,
            guesses: guesses,
            getSolutionCount: getSolutionCount,
          );
        }
      }
      return;
    }

    for (var cell = 0; cell < puzzle.cellCount; cell++) {
      if (covCopy.contains(cell)) continue;
      final refs = _activeCandidateRefsForCell(
        allCandidates,
        remCopy,
        selCopy,
        cell,
      );
      if (refs.length > 1) {
        for (final ref in refs) {
          if (getSolutionCount() >= limit) return;
          guesses.value++;
          final nextRem = remCopy.map(Set<int>.from).toList();
          final nextSel = Map<int, int>.from(selCopy);
          final nextCov = Set<int>.from(covCopy);
          if (_selectCandidate(
            allCandidates,
            nextRem,
            nextSel,
            nextCov,
            ref.clueIndex,
            ref.candidateIndex,
          )) {
            _search(
              puzzle,
              allCandidates,
              nextRem,
              nextSel,
              nextCov,
              depth + 1,
              limit: limit,
              nodeLimit: nodeLimit,
              onSolution: onSolution,
              visitedNodes: visitedNodes,
              guesses: guesses,
              getSolutionCount: getSolutionCount,
            );
          }
        }
        return;
      }
    }
  }

  LogicalSolveAnalysis _emptyLogical(int clueCount, int cellCount) =>
      LogicalSolveAnalysis(
        solved: false,
        clueCount: clueCount,
        cellCount: cellCount,
        averageInitialCandidates: 0,
        maxInitialCandidates: 0,
        minInitialCandidates: 0,
        initialForcedClues: 0,
        initialForcedCells: 0,
        propagationRounds: 0,
        forcedPlacements: 0,
      );
}

class _Counter {
  int value = 0;
}
