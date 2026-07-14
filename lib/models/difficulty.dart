/// Difficulty tiers selectable from the Home screen. Each tier tracks its own
/// level progress independently in [SettingsController].
///
/// Note: the puzzle generator does not yet vary its parameters per tier (see
/// roadmap step 2) — for now each difficulty is simply its own separate level
/// counter, all using the same generation curve. Tuning grid size/area per
/// tier is a follow-up.
enum Difficulty { easy, medium, hard }

extension DifficultyX on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };

  String get description => switch (this) {
        Difficulty.easy => 'Bigger rectangles, gentler boards.',
        Difficulty.medium => 'A balanced challenge.',
        Difficulty.hard => 'Tight grids, sharp thinking.',
      };
}
