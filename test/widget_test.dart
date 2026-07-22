import 'package:flutter_test/flutter_test.dart';

import 'package:shikaku_game/logic/generator.dart';
import 'package:shikaku_game/logic/validator.dart';
import 'package:shikaku_game/models/puzzle.dart';
import 'package:shikaku_game/models/puzzle_difficulty.dart';
import 'package:shikaku_game/state/game_controller.dart';

void main() {
  const generator = PuzzleGenerator();
  const validator = ShikakuValidator();

  test('generated puzzle solution tiles the grid and satisfies all clues', () {
    for (var level = 1; level <= 10; level++) {
      for (final difficulty in PuzzleDifficulty.values) {
        final puzzle = generator.generate(level, difficulty: difficulty, seed: level);

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

  test('no rectangle is a single cell (every clue is >= 2)', () {
    for (var level = 1; level <= 15; level++) {
      final puzzle = generator.generate(level, seed: level);
      for (final rect in puzzle.solution) {
        expect(rect.area, greaterThanOrEqualTo(2));
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

  test('previewAreaMatchesClue when area equals single contained clue', () {
    for (var seed = 1; seed <= 80; seed++) {
      final game = GameController(1, seed: seed)..hapticsEnabled = false;
      final puzzle = game.puzzle;
      for (var i = 0; i < puzzle.clues.length; i++) {
        final clue = puzzle.clues[i];
        final sol = puzzle.solution[i];
        if (sol.width < 2 || sol.height < 2) continue;

        final endCol = clue.col + clue.value - 1;
        if (endCol >= puzzle.cols) continue;
        final strip = GridRect(clue.row, clue.col, clue.value, 1);
        if (strip == sol) continue;

        var cluesInside = 0;
        for (final other in puzzle.clues) {
          if (strip.containsCell(other.row, other.col)) cluesInside++;
        }
        if (cluesInside != 1) continue;

        game.startDrag(clue.row, clue.col);
        game.updateDrag(clue.row, endCol);
        expect(game.preview!.area, clue.value);
        expect(game.preview, isNot(sol));
        expect(game.previewAreaMatchesClue, isTrue);
        return;
      }
    }
    fail('could not find a puzzle with a wrong-shape area match');
  });

  test('hint shows ghost preview without placing a rectangle', () {
    final game = GameController(1, seed: 42)..hapticsEnabled = false;
    final before = game.placed.length;
    final hintsBefore = game.hintsLeft;

    game.useHint();

    expect(game.hintsLeft, hintsBefore - 1);
    expect(game.hintsUsed, 1);
    expect(game.hintGhosts, hasLength(1));
    expect(game.placed.length, before);
  });

  test('multiple hints stack on the board up to charges used', () {
    final game = GameController(1, seed: 42)..hapticsEnabled = false;
    final startingHints = game.hintsLeft;
    for (var i = 0; i < startingHints; i++) {
      game.useHint();
    }

    expect(game.hintGhosts, hasLength(startingHints));
    expect(game.hintsLeft, 0);
    expect(
      game.hintGhosts.map((h) => h.clueIndex).toSet(),
      hasLength(startingHints),
    );
  });

  test('hint does not consume charge when every unsolved region is ghosted', () {
    final game = GameController(1, seed: 42)..hapticsEnabled = false;
    while (game.hintsLeft > 0) {
      final before = game.hintGhosts.length;
      game.useHint();
      if (game.hintGhosts.length == before) break;
    }
    final ghosted = game.hintGhosts.length;
    final hintsAfter = game.hintsLeft;
    game.useHint();
    expect(game.hintsLeft, hintsAfter);
    expect(game.hintGhosts, hasLength(ghosted));
  });

  test('placing a hinted rectangle removes only that ghost', () {
    final game = GameController(1, seed: 42)..hapticsEnabled = false;
    game.useHint();
    game.useHint();
    expect(game.hintGhosts, hasLength(2));

    final first = game.hintGhosts.first;
    final sol = first.rect;
    game.startDrag(sol.row, sol.col);
    game.updateDrag(sol.bottom - 1, sol.right - 1);
    game.endDrag();

    expect(game.hintGhosts, hasLength(1));
    expect(game.hintGhosts.first.clueIndex, isNot(first.clueIndex));
  });

  test('wand places exactly one rectangle', () {
    final game = GameController(1, seed: 42)..hapticsEnabled = false;
    final totalClues = game.puzzle.clues.length;

    game.useWand();

    expect(game.wandUsed, 1);
    expect(game.wandsLeft, 0);
    expect(game.placed.length, 1);
    expect(game.placed.first.wandPlaced, isTrue);
    expect(totalClues, greaterThan(1));
    expect(game.solved, isFalse);
  });

  test('wand prefers last interacted clue region', () {
    GameController? game;
  (int clueIndex, GridRect rect)? preferred;
    for (var seed = 1; seed <= 50; seed++) {
      final candidate = GameController(1, seed: seed)..hapticsEnabled = false;
      final regions = <(int, GridRect)>[
        for (var i = 0; i < candidate.puzzle.solution.length; i++)
          (i, candidate.puzzle.solution[i]),
      ]..sort((a, b) => a.$2.area.compareTo(b.$2.area));
      if (regions.length >= 2 &&
          regions.first.$2.area < regions.last.$2.area) {
        game = candidate;
        preferred = regions.last;
        break;
      }
    }

    expect(game, isNotNull, reason: 'need varied region sizes');
    final target = preferred!;
    final clue = game!.puzzle.clues[target.$1];
    game.startDrag(clue.row, clue.col);
    game.endDrag();
    game.useWand();

    expect(game.placed.length, 1);
    expect(game.placed.first.rect, target.$2);
    expect(game.placed.first.wandPlaced, isTrue);
  });

  test('wand-placed rectangle cannot be removed by tap or eraser', () {
    final game = GameController(1, seed: 42)..hapticsEnabled = false;
    game.useWand();
    expect(game.placed, hasLength(1));

    final wandRect = game.placed.first.rect;
    game.eraseAt(wandRect.row, wandRect.col);
    expect(game.placed, hasLength(1));

    game.startDrag(wandRect.row, wandRect.col);
    game.endDrag();
    expect(game.placed, hasLength(1));
    expect(game.isRemovableAt(wandRect.row, wandRect.col), isFalse);
  });

  test('drawing over a wand-placed rectangle is blocked', () {
    final game = GameController(1, seed: 42)..hapticsEnabled = false;
    game.useWand();
    final wandRect = game.placed.first.rect;

    game.startDrag(wandRect.row, wandRect.col);
    game.updateDrag(wandRect.bottom - 1, wandRect.right - 1);
    game.endDrag();

    expect(game.placed, hasLength(1));
    expect(game.placed.first.wandPlaced, isTrue);
    expect(game.placed.first.rect, wandRect);
  });
}
