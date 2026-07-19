import 'package:flutter_test/flutter_test.dart';

import 'package:shikaku_game/models/puzzle_difficulty.dart';
import 'package:shikaku_game/ui/widgets/win_screens/win_screen_picker.dart';
import 'package:shikaku_game/ui/widgets/win_screens/win_screen_variant.dart';

void main() {
  group('WinScreenPicker', () {
    test('close call when wand was used', () {
      expect(
        WinScreenPicker.pick(
          difficulty: PuzzleDifficulty.medium,
          boardSize: 7,
          elapsed: const Duration(seconds: 10),
          hintsUsed: 0,
          wandUsed: 1,
          undoCount: 0,
        ),
        WinScreenVariant.closeCall,
      );
    });

    test('close call when many undos without wand', () {
      expect(
        WinScreenPicker.pick(
          difficulty: PuzzleDifficulty.easy,
          boardSize: 6,
          elapsed: const Duration(minutes: 5),
          hintsUsed: 0,
          wandUsed: 0,
          undoCount: WinScreenPicker.manyUndosThreshold,
        ),
        WinScreenVariant.closeCall,
      );
    });

    test('steady when hints used but no wand', () {
      expect(
        WinScreenPicker.pick(
          difficulty: PuzzleDifficulty.hard,
          boardSize: 8,
          elapsed: const Duration(seconds: 20),
          hintsUsed: 2,
          wandUsed: 0,
          undoCount: 1,
        ),
        WinScreenVariant.steady,
      );
    });

    test('speed when clean solve under threshold', () {
      final threshold =
          WinScreenPicker.speedThreshold(PuzzleDifficulty.medium, 7);
      expect(
        WinScreenPicker.pick(
          difficulty: PuzzleDifficulty.medium,
          boardSize: 7,
          elapsed: threshold - const Duration(seconds: 1),
          hintsUsed: 0,
          wandUsed: 0,
          undoCount: 0,
        ),
        WinScreenVariant.speed,
      );
    });

    test('flawless on slow clean solve', () {
      final threshold =
          WinScreenPicker.speedThreshold(PuzzleDifficulty.easy, 6);
      expect(
        WinScreenPicker.pick(
          difficulty: PuzzleDifficulty.easy,
          boardSize: 6,
          elapsed: threshold + const Duration(seconds: 30),
          hintsUsed: 0,
          wandUsed: 0,
          undoCount: 0,
        ),
        WinScreenVariant.flawless,
      );
    });

    test('wand beats speed and steady', () {
      expect(
        WinScreenPicker.pick(
          difficulty: PuzzleDifficulty.easy,
          boardSize: 6,
          elapsed: const Duration(seconds: 5),
          hintsUsed: 3,
          wandUsed: 1,
          undoCount: 0,
        ),
        WinScreenVariant.closeCall,
      );
    });
  });
}
