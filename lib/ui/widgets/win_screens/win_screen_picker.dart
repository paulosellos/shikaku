import '../../../models/puzzle_difficulty.dart';
import 'win_screen_variant.dart';

/// Chooses a win screen variant from solve context.
abstract final class WinScreenPicker {
  static const manyUndosThreshold = 3;

  static WinScreenVariant pick({
    required PuzzleDifficulty difficulty,
    required int boardSize,
    required Duration elapsed,
    required int hintsUsed,
    required int wandUsed,
    required int undoCount,
  }) {
    if (wandUsed > 0 || undoCount >= manyUndosThreshold) {
      return WinScreenVariant.closeCall;
    }
    if (hintsUsed > 0) {
      return WinScreenVariant.steady;
    }
    if (elapsed < speedThreshold(difficulty, boardSize)) {
      return WinScreenVariant.speed;
    }
    return WinScreenVariant.flawless;
  }

  /// Difficulty-scaled time limit for a [speed] win (no hints or wand).
  static Duration speedThreshold(PuzzleDifficulty difficulty, int boardSize) {
    final baseSeconds = 28 + boardSize * 6;
    final factor = switch (difficulty) {
      PuzzleDifficulty.easy => 1.25,
      PuzzleDifficulty.medium => 1.0,
      PuzzleDifficulty.hard => 0.85,
    };
    return Duration(
      milliseconds: (baseSeconds * 1000 * factor).round(),
    );
  }
}
