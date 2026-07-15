import '../models/puzzle.dart';
import '../models/puzzle_difficulty.dart';

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

/// Solves and analyzes Shikaku puzzles from clues only (never uses the stored
/// generator solution).
class PuzzleSolver {
  const PuzzleSolver();

  int countSolutions(Puzzle puzzle, {int limit = 2, int nodeLimit = 5000}) {
    final candidates = _enumerateCandidates(puzzle);
    if (candidates.any((c) => c.isEmpty)) return 0;

    final remaining = List.generate(
      puzzle.clues.length,
      (i) => Set<int>.from(List.generate(candidates[i].length, (j) => j)),
    );
    var count = 0;
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
      visitedNodes: _Counter(),
      maxDepth: _Counter(),
      guesses: _Counter(),
      getSolutionCount: () => count,
    );
    return count;
  }

  DifficultyAnalysis analyze(Puzzle puzzle, {int nodeLimit = 5000}) {
    final candidates = _enumerateCandidates(puzzle);
    final clueCount = puzzle.clues.length;
    final cellCount = puzzle.cellCount;

    if (candidates.any((c) => c.isEmpty)) {
      return _emptyAnalysis(clueCount, cellCount, solutionCount: 0);
    }

    final initialCounts = candidates.map((c) => c.length).toList();
    final avgCandidates = initialCounts.isEmpty
        ? 0.0
        : initialCounts.reduce((a, b) => a + b) / initialCounts.length;
    final maxCandidates =
        initialCounts.isEmpty ? 0 : initialCounts.reduce((a, b) => a > b ? a : b);

    final initialForced = _countInitialForced(candidates, puzzle.cellCount);

    final propagationRounds = _Counter();
    final forcedPlacements = _Counter();
    final guesses = _Counter();
    final maxDepth = _Counter();
    final visitedNodes = _Counter();
    var solutionCount = 0;

    _search(
      puzzle,
      candidates,
      List.generate(
        clueCount,
        (i) => Set<int>.from(List.generate(candidates[i].length, (j) => j)),
      ),
      {},
      {},
      0,
      limit: 2,
      nodeLimit: nodeLimit,
      onSolution: () => solutionCount++,
      visitedNodes: visitedNodes,
      maxDepth: maxDepth,
      guesses: guesses,
      propagationRounds: propagationRounds,
      forcedPlacements: forcedPlacements,
      getSolutionCount: () => solutionCount,
    );

    return _analysisFrom(
      solutionCount: solutionCount,
      clueCount: clueCount,
      cellCount: cellCount,
      avgCandidates: avgCandidates,
      maxCandidates: maxCandidates,
      initialForced: initialForced,
      propagationRounds: propagationRounds.value,
      forcedPlacements: forcedPlacements.value,
      guesses: guesses.value,
      maxDepth: maxDepth.value,
      visitedNodes: visitedNodes.value,
    );
  }

  List<List<_Candidate>> _enumerateCandidates(Puzzle puzzle) {
    final clueCells = <(int, int)>[];
    for (var i = 0; i < puzzle.clues.length; i++) {
      clueCells.add((puzzle.clues[i].row, puzzle.clues[i].col));
    }

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

  int _countInitialForced(List<List<_Candidate>> candidates, int cellCount) {
    var forced = 0;
    for (var i = 0; i < candidates.length; i++) {
      if (candidates[i].length == 1) forced++;
    }
    for (var cell = 0; cell < cellCount; cell++) {
      final owners = <int>{};
      for (var i = 0; i < candidates.length; i++) {
        for (final cand in candidates[i]) {
          if (cand.cellIndices.contains(cell)) owners.add(i);
        }
      }
      if (owners.length == 1) {
        final only = owners.first;
        if (candidates[only].length > 1) forced++;
      }
    }
    return forced;
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
        final options = <int, int>{};
        for (var clue = 0; clue < remaining.length; clue++) {
          if (selected.containsKey(clue)) continue;
          for (final candIdx in remaining[clue]) {
            if (allCandidates[clue][candIdx].cellIndices.contains(cell)) {
              options[clue] = candIdx;
            }
          }
        }
        if (options.isEmpty) return false;
        if (options.length == 1) {
          final entry = options.entries.first;
          if (!_selectCandidate(
            allCandidates,
            remaining,
            selected,
            covered,
            entry.key,
            entry.value,
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
        if (otherCand.cellIndices.any(covered.contains)) return true;
        return false;
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
    int nodeLimit = 5000,
    required void Function() onSolution,
    required _Counter visitedNodes,
    required _Counter maxDepth,
    required _Counter guesses,
    _Counter? propagationRounds,
    _Counter? forcedPlacements,
    required int Function() getSolutionCount,
  }) {
    if (getSolutionCount() >= limit) return;

    visitedNodes.value++;
    if (visitedNodes.value > nodeLimit) return;
    if (depth > maxDepth.value) maxDepth.value = depth;

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

    propagationRounds?.value += propRounds.value;
    forcedPlacements?.value += forced.value;

    if (selCopy.length == puzzle.clues.length && covCopy.length == puzzle.cellCount) {
      onSolution();
      return;
    }

    // Pick unresolved clue with fewest remaining candidates (>1).
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

    if (bestClue == -1) {
      // Try cell-based branching if no clue with >1 option.
      for (var cell = 0; cell < puzzle.cellCount; cell++) {
        if (covCopy.contains(cell)) continue;
        final options = <int, int>{};
        for (var clue = 0; clue < remCopy.length; clue++) {
          if (selCopy.containsKey(clue)) continue;
          for (final candIdx in remCopy[clue]) {
            if (allCandidates[clue][candIdx].cellIndices.contains(cell)) {
              options[clue] = candIdx;
            }
          }
        }
        if (options.length > 1) {
          for (final entry in options.entries) {
            guesses.value++;
            final nextRem = remCopy.map(Set<int>.from).toList();
            final nextSel = Map<int, int>.from(selCopy);
            final nextCov = Set<int>.from(covCopy);
            if (_selectCandidate(
              allCandidates,
              nextRem,
              nextSel,
              nextCov,
              entry.key,
              entry.value,
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
                maxDepth: maxDepth,
                guesses: guesses,
                propagationRounds: propagationRounds,
                forcedPlacements: forcedPlacements,
                getSolutionCount: getSolutionCount,
              );
            }
          }
          return;
        }
      }
      return;
    }

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
          maxDepth: maxDepth,
          guesses: guesses,
          propagationRounds: propagationRounds,
          forcedPlacements: forcedPlacements,
          getSolutionCount: getSolutionCount,
        );
      }
    }
  }

  DifficultyAnalysis _analysisFrom({
    required int solutionCount,
    required int clueCount,
    required int cellCount,
    required double avgCandidates,
    required int maxCandidates,
    required int initialForced,
    required int propagationRounds,
    required int forcedPlacements,
    required int guesses,
    required int maxDepth,
    required int visitedNodes,
  }) {
    final forcedRatio = clueCount == 0 ? 0.0 : initialForced / clueCount;
    final ambiguity = ((avgCandidates - 1) / 5).clamp(0.0, 1.0);
    final forcedDifficulty = (1.0 - forcedRatio).clamp(0.0, 1.0);
    final chainDifficulty = (propagationRounds / 10).clamp(0.0, 1.0);
    final searchDifficulty = (maxDepth / 3).clamp(0.0, 1.0);
    final nodeDifficulty =
        (visitedNodes <= 0 ? 0.0 : (visitedNodes / 5000).clamp(0.0, 1.0));
    final sizeDifficulty =
        (cellCount / 100).clamp(0.0, 1.0); // ~9x11 = 99 cells

    final score = (25 * ambiguity +
            20 * forcedDifficulty +
            15 * chainDifficulty +
            25 * searchDifficulty +
            10 * nodeDifficulty +
            5 * sizeDifficulty)
        .round()
        .clamp(0, 100);

    return DifficultyAnalysis(
      solutionCount: solutionCount.clamp(0, 2),
      clueCount: clueCount,
      cellCount: cellCount,
      averageInitialCandidates: avgCandidates,
      maxInitialCandidates: maxCandidates,
      initialForcedClues: initialForced,
      propagationRounds: propagationRounds,
      forcedPlacements: forcedPlacements,
      guesses: guesses,
      maxSearchDepth: maxDepth,
      visitedNodes: visitedNodes,
      score: score,
    );
  }

  DifficultyAnalysis _emptyAnalysis(
    int clueCount,
    int cellCount, {
    required int solutionCount,
  }) =>
      DifficultyAnalysis(
        solutionCount: solutionCount,
        clueCount: clueCount,
        cellCount: cellCount,
        averageInitialCandidates: 0,
        maxInitialCandidates: 0,
        initialForcedClues: 0,
        propagationRounds: 0,
        forcedPlacements: 0,
        guesses: 0,
        maxSearchDepth: 0,
        visitedNodes: 0,
        score: 100,
      );
}

class _Counter {
  int value = 0;
}
