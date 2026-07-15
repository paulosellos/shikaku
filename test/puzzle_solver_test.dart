import 'package:flutter_test/flutter_test.dart';

import 'package:shikaku_game/logic/puzzle_solver.dart';
import 'package:shikaku_game/models/puzzle.dart';
import 'package:shikaku_game/models/puzzle_difficulty.dart';

void main() {
  const solver = PuzzleSolver();

  Puzzle fixture({
    required int rows,
    required int cols,
    required List<Clue> clues,
  }) =>
      Puzzle(
        level: 1,
        difficulty: PuzzleDifficulty.medium,
        rows: rows,
        cols: cols,
        clues: clues,
        solution: const [],
      );

  test('2x2 with two clues has exactly one solution', () {
    final puzzle = fixture(
      rows: 2,
      cols: 2,
      clues: const [
        Clue(0, 0, 2),
        Clue(1, 1, 2),
      ],
    );
    expect(solver.countSolutions(puzzle), 1);
    final analysis = solver.analyze(puzzle);
    expect(analysis.isUnique, isTrue);
    expect(analysis.solutionCount, 1);
  });

  test('under-specified board yields zero complete solutions', () {
    final puzzle = fixture(
      rows: 2,
      cols: 2,
      clues: const [Clue(0, 0, 2)],
    );
    expect(solver.countSolutions(puzzle), 0);
    final analysis = solver.analyze(puzzle);
    expect(analysis.isUnique, isFalse);
  });

  test('impossible clue area yields zero solutions', () {
    final puzzle = fixture(
      rows: 2,
      cols: 2,
      clues: const [Clue(0, 0, 3)],
    );
    expect(solver.countSolutions(puzzle), 0);
  });

  test('analyze reports candidate statistics', () {
    final puzzle = fixture(
      rows: 2,
      cols: 2,
      clues: const [
        Clue(0, 0, 2),
        Clue(1, 1, 2),
      ],
    );
    final analysis = solver.analyze(puzzle);
    expect(analysis.clueCount, 2);
    expect(analysis.cellCount, 4);
    expect(analysis.averageInitialCandidates, greaterThan(0));
    expect(analysis.score, inInclusiveRange(0, 100));
  });
}
