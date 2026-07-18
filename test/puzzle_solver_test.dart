import 'package:flutter_test/flutter_test.dart';

import 'package:shikaku_game/logic/generator.dart';
import 'package:shikaku_game/logic/puzzle_solver.dart';
import 'package:shikaku_game/models/puzzle.dart';
import 'package:shikaku_game/models/puzzle_difficulty.dart';

void main() {
  const solver = PuzzleSolver();
  const generator = PuzzleGenerator();

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

  test('2x2 with diagonal clues has two solutions and is not logically solved', () {
    final puzzle = fixture(
      rows: 2,
      cols: 2,
      clues: const [
        Clue(0, 0, 2),
        Clue(1, 1, 2),
      ],
    );
    expect(solver.countSolutions(puzzle), 2);
    expect(solver.analyzeLogically(puzzle).solved, isFalse);
  });

  test('generated puzzle is unique and logically solvable', () {
    final puzzle =
        generator.generate(1, difficulty: PuzzleDifficulty.easy, seed: 42);
    expect(solver.countSolutions(puzzle), 1);
    expect(solver.analyzeLogically(puzzle).solved, isTrue);
  });

  test('cell with multiple candidates from same clue is not treated as forced', () {
    final puzzle = fixture(
      rows: 4,
      cols: 4,
      clues: const [Clue(1, 1, 4)],
    );
    final logical = solver.analyzeLogically(puzzle);
    // Old bug: every cell "owned" by the single clue looked forced.
    expect(logical.initialForcedCells, lessThan(puzzle.cellCount));
  });

  test('under-specified board yields zero complete solutions', () {
    final puzzle = fixture(
      rows: 2,
      cols: 2,
      clues: const [Clue(0, 0, 2)],
    );
    expect(solver.countSolutions(puzzle), 0);
    final logical = solver.analyzeLogically(puzzle);
    expect(logical.solved, isFalse);
  });

  test('impossible clue area yields zero solutions', () {
    final puzzle = fixture(
      rows: 2,
      cols: 2,
      clues: const [Clue(0, 0, 3)],
    );
    expect(solver.countSolutions(puzzle), 0);
  });

  test('analyzeLogically reports candidate statistics', () {
    final puzzle =
        generator.generate(3, difficulty: PuzzleDifficulty.medium, seed: 7);
    final logical = solver.analyzeLogically(puzzle);
    expect(logical.clueCount, puzzle.clues.length);
    expect(logical.cellCount, puzzle.cellCount);
    expect(logical.averageInitialCandidates, greaterThan(0));
    expect(logical.solved, isTrue);
  });

  test('logical solve never branches', () {
    final puzzle =
        generator.generate(5, difficulty: PuzzleDifficulty.hard, seed: 11);
    final logical = solver.analyzeLogically(puzzle);
    expect(logical.solved, isTrue);
  });
}
