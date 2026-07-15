import 'package:flutter_test/flutter_test.dart';

import 'package:shikaku_game/logic/generator.dart';
import 'package:shikaku_game/logic/puzzle_solver.dart';
import 'package:shikaku_game/logic/validator.dart';
import 'package:shikaku_game/models/puzzle.dart';
import 'package:shikaku_game/models/puzzle_difficulty.dart';
import 'package:shikaku_game/state/game_controller.dart';

void main() {
  const generator = PuzzleGenerator();
  const solver = PuzzleSolver();
  const validator = ShikakuValidator();

  test('generated puzzle solution tiles the grid and satisfies all clues', () {
    for (var level = 1; level <= 20; level++) {
      for (final difficulty in PuzzleDifficulty.values) {
        final puzzle = generator.generate(level, difficulty: difficulty);

        final placed = <PlacedRect>[];
        for (var i = 0; i < puzzle.solution.length; i++) {
          placed.add(PlacedRect(puzzle.solution[i], i));
        }

        final result = validator.evaluate(puzzle, placed);
        expect(result.solved, isTrue,
            reason: '$difficulty level $level should be solvable');
        expect(result.hasOverlap, isFalse);
        expect(result.fullyCovered, isTrue);

        final totalArea =
            puzzle.solution.fold<int>(0, (sum, r) => sum + r.area);
        expect(totalArea, puzzle.cellCount);

        for (var i = 0; i < puzzle.clues.length; i++) {
          expect(puzzle.clues[i].value, puzzle.solution[i].area);
        }
      }
    }
  });

  test('generated puzzles are unique (solver confirms one solution)', () {
    for (final difficulty in PuzzleDifficulty.values) {
      for (var level = 1; level <= 15; level++) {
        final puzzle = generator.generate(level, difficulty: difficulty, seed: level * 100);
        final count = solver.countSolutions(puzzle);
        expect(count, 1,
            reason: '$difficulty level $level should have exactly one solution');
      }
    }
  });

  test('generation is deterministic for a fixed seed', () {
    for (final difficulty in PuzzleDifficulty.values) {
      final a = generator.generate(5, difficulty: difficulty, seed: 42);
      final b = generator.generate(5, difficulty: difficulty, seed: 42);
      expect(a.rows, b.rows);
      expect(a.cols, b.cols);
      expect(a.clues.length, b.clues.length);
      for (var i = 0; i < a.clues.length; i++) {
        expect(a.clues[i].row, b.clues[i].row);
        expect(a.clues[i].col, b.clues[i].col);
        expect(a.clues[i].value, b.clues[i].value);
      }
    }
  });

  test('difficulty tiers scale grid size easy -> medium -> hard', () {
    int avgCells(PuzzleDifficulty difficulty) {
      var total = 0;
      for (var level = 1; level <= 10; level++) {
        final puzzle =
            generator.generate(level, difficulty: difficulty, seed: level * 17);
        total += puzzle.cellCount;
      }
      return total ~/ 10;
    }

    expect(avgCells(PuzzleDifficulty.easy), lessThan(avgCells(PuzzleDifficulty.medium)));
    expect(avgCells(PuzzleDifficulty.medium), lessThan(avgCells(PuzzleDifficulty.hard)));
  });

  test('no rectangle is a single cell (every clue is >= 2)', () {
    for (var level = 1; level <= 30; level++) {
      final puzzle = generator.generate(level);
      for (final rect in puzzle.solution) {
        expect(rect.area, greaterThanOrEqualTo(2),
            reason: 'level $level produced a 1-cell rectangle');
      }
      for (final clue in puzzle.clues) {
        expect(clue.value, greaterThanOrEqualTo(2));
      }
    }
  });

  test('overlapping rectangles are flagged and not solved', () {
    final puzzle = generator.generate(5);
    final placed = [
      const PlacedRect(GridRect(0, 0, 2, 2), 0),
      const PlacedRect(GridRect(0, 0, 2, 2), 1),
    ];
    final result = validator.evaluate(puzzle, placed);
    expect(result.hasOverlap, isTrue);
    expect(result.solved, isFalse);
  });

  test('GridRect.fromCorners normalises any drag direction', () {
    final a = GridRect.fromCorners(3, 4, 1, 2);
    expect(a.row, 1);
    expect(a.col, 2);
    expect(a.width, 3);
    expect(a.height, 3);
  });

  test('single-cell tap previews but does not commit', () {
    final game = GameController(1)..hapticsEnabled = false;
    game.startDrag(0, 0);
    expect(game.preview?.area, 1);
    game.endDrag();
    expect(game.placed, isEmpty);
  });

  test('single-cell tap on placed shape removes it', () {
    final game = GameController(1)..hapticsEnabled = false;
    game.startDrag(0, 0);
    game.updateDrag(0, 1);
    game.endDrag();
    expect(game.placed.length, 1);

    game.startDrag(0, 0);
    game.endDrag();
    expect(game.placed, isEmpty);
    expect(game.canUndo, isTrue);
  });

  test('two-cell drag commits a rectangle', () {
    final game = GameController(1)..hapticsEnabled = false;
    game.startDrag(0, 0);
    game.updateDrag(0, 1);
    game.endDrag();
    expect(game.placed.length, 1);
    expect(game.placed.first.rect.area, 2);
  });
}
