import 'package:flutter_test/flutter_test.dart';

import 'package:shikaku_game/logic/generator.dart';
import 'package:shikaku_game/logic/puzzle_solver.dart';
import 'package:shikaku_game/logic/validator.dart';
import 'package:shikaku_game/models/puzzle.dart';
import 'package:shikaku_game/models/puzzle_difficulty.dart';

void main() {
  const generator = PuzzleGenerator();
  const solver = PuzzleSolver();
  const validator = ShikakuValidator();

  group('target helpers', () {
    test('board sizes match v2 rules', () {
      expect(DifficultyProfiles.boardSizeFor(PuzzleDifficulty.easy, 1), 6);
      expect(DifficultyProfiles.boardSizeFor(PuzzleDifficulty.medium, 5), 7);
      expect(DifficultyProfiles.boardSizeFor(PuzzleDifficulty.hard, 20), 8);
      expect(DifficultyProfiles.boardSizeFor(PuzzleDifficulty.hard, 21), 9);
    });

    test('target clue counts stay within tier ranges', () {
      for (var level = 1; level <= 40; level++) {
        for (final d in PuzzleDifficulty.values) {
          final target = DifficultyProfiles.targetClueCountFor(d, level);
          final min = DifficultyProfiles.minCluesFor(d, level);
          final max = DifficultyProfiles.maxCluesFor(d, level);
          expect(target, inInclusiveRange(min, max));
        }
      }
    });

    test('early levels target higher clue counts than late levels', () {
      expect(
        DifficultyProfiles.targetClueCountFor(PuzzleDifficulty.easy, 1),
        greaterThan(
          DifficultyProfiles.targetClueCountFor(PuzzleDifficulty.easy, 20),
        ),
      );
      expect(
        DifficultyProfiles.targetClueCountFor(PuzzleDifficulty.hard, 21),
        greaterThan(
          DifficultyProfiles.targetClueCountFor(PuzzleDifficulty.hard, 40),
        ),
      );
    });
  });

  test('generated boards are exact square sizes', () {
    final easy = generator.generate(3, difficulty: PuzzleDifficulty.easy, seed: 1);
    final medium =
        generator.generate(3, difficulty: PuzzleDifficulty.medium, seed: 1);
    final hard20 =
        generator.generate(20, difficulty: PuzzleDifficulty.hard, seed: 1);
    final hard21 =
        generator.generate(21, difficulty: PuzzleDifficulty.hard, seed: 1);

    expect(easy.rows, 6);
    expect(easy.cols, 6);
    expect(medium.rows, 7);
    expect(medium.cols, 7);
    expect(hard20.rows, 8);
    expect(hard20.cols, 8);
    expect(hard21.rows, 9);
    expect(hard21.cols, 9);
  });

  test('generated puzzles are logically solvable and unique', () {
    for (final difficulty in PuzzleDifficulty.values) {
      final maxLevel = difficulty == PuzzleDifficulty.hard ? 25 : 15;
      for (var level = 1; level <= maxLevel; level++) {
        final puzzle =
            generator.generate(level, difficulty: difficulty, seed: level * 31);
        final logical = solver.analyzeLogically(puzzle);
        expect(logical.solved, isTrue,
            reason: '$difficulty level $level must be logically solvable');
        expect(solver.countSolutions(puzzle, limit: 2), 1,
            reason: '$difficulty level $level must be unique');
      }
    }
  });

  test('clue counts stay within approved ranges', () {
    for (var level = 1; level <= 25; level++) {
      final easy = generator.generate(level, difficulty: PuzzleDifficulty.easy, seed: level);
      expect(easy.clues.length, inInclusiveRange(13, 16));

      final medium =
          generator.generate(level, difficulty: PuzzleDifficulty.medium, seed: level);
      expect(medium.clues.length, inInclusiveRange(12, 15));

      final hard =
          generator.generate(level, difficulty: PuzzleDifficulty.hard, seed: level);
      if (level <= 20) {
        expect(hard.clues.length, inInclusiveRange(10, 13));
      } else {
        expect(hard.clues.length, inInclusiveRange(11, 14));
      }
    }
  });

  test('structural validity of stored solutions', () {
    for (final difficulty in PuzzleDifficulty.values) {
      for (var level = 1; level <= 10; level++) {
        final puzzle =
            generator.generate(level, difficulty: difficulty, seed: level * 7);
        expect(puzzle.rows, puzzle.cols);

        final placed = [
          for (var i = 0; i < puzzle.solution.length; i++)
            PlacedRect(puzzle.solution[i], i),
        ];
        final result = validator.evaluate(puzzle, placed);
        expect(result.solved, isTrue);
        expect(result.hasOverlap, isFalse);
        expect(result.fullyCovered, isTrue);

        for (final rect in puzzle.solution) {
          expect(rect.area, greaterThanOrEqualTo(2));
        }
        expect(puzzle.solution.length, puzzle.clues.length);
      }
    }
  });

  test('deterministic generation', () {
    for (final difficulty in PuzzleDifficulty.values) {
      final a = generator.generate(5, difficulty: difficulty, seed: 99);
      final b = generator.generate(5, difficulty: difficulty, seed: 99);
      expect(a.rows, b.rows);
      expect(a.cols, b.cols);
      expect(a.clues.length, b.clues.length);
      for (var i = 0; i < a.clues.length; i++) {
        expect(a.clues[i].row, b.clues[i].row);
        expect(a.clues[i].col, b.clues[i].col);
        expect(a.clues[i].value, b.clues[i].value);
        expect(a.solution[i], b.solution[i]);
      }
    }
  });

  test('aggregate difficulty trends', () {
    double avg(Iterable<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

    final easyDensity = <double>[];
    final mediumDensity = <double>[];
    final hardDensity = <double>[];
    final easyForced = <double>[];
    final hardForced = <double>[];
    final easyCandidates = <double>[];
    final hardCandidates = <double>[];

    for (var level = 1; level <= 15; level++) {
      final easy =
          generator.generate(level, difficulty: PuzzleDifficulty.easy, seed: level);
      final medium =
          generator.generate(level, difficulty: PuzzleDifficulty.medium, seed: level);
      final hard =
          generator.generate(level, difficulty: PuzzleDifficulty.hard, seed: level);

      final easyLogical = solver.analyzeLogically(easy);
      final mediumLogical = solver.analyzeLogically(medium);
      final hardLogical = solver.analyzeLogically(hard);

      easyDensity.add(easyLogical.clueDensity);
      mediumDensity.add(mediumLogical.clueDensity);
      hardDensity.add(hardLogical.clueDensity);
      easyForced.add(easyLogical.initialForcedRatio);
      hardForced.add(hardLogical.initialForcedRatio);
      easyCandidates.add(easyLogical.averageInitialCandidates);
      hardCandidates.add(hardLogical.averageInitialCandidates);
    }

    expect(avg(easyDensity), greaterThan(avg(mediumDensity)));
    expect(avg(mediumDensity), greaterThan(avg(hardDensity)));
    expect(avg(easyForced), greaterThan(avg(hardForced)));
    expect(avg(easyCandidates), lessThan(avg(hardCandidates)));
  });
}
