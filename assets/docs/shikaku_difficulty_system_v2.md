# Cursor Implementation Prompt: Improve the Shikaku Difficulty System

Repository: `https://github.com/paulosellos/shikaku`

Implement the changes directly in the current Flutter project.

Before editing anything, inspect the current implementation, especially:

- `lib/models/puzzle_difficulty.dart`
- `lib/models/puzzle.dart`
- `lib/logic/generator.dart`
- `lib/logic/puzzle_solver.dart`
- `lib/logic/validator.dart`
- `lib/state/game_controller.dart`
- `lib/state/settings_controller.dart`
- Difficulty-related UI
- `test/widget_test.dart`
- Any other generator or solver tests

Do not replace working infrastructure unnecessarily. The project already has:

- `PuzzleDifficulty.easy`, `medium`, and `hard`
- Difficulty profiles
- A procedural partition generator
- Candidate enumeration
- Constraint propagation
- Bounded backtracking
- Uniqueness checking
- An internal difficulty score
- Persisted difficulty and separate level progress
- Difficulty selection in the UI
- Stored solutions for hints and the wand

The objective is to correct and improve how difficulty is generated and measured.

---

## Product decisions

These decisions are final for this iteration.

### Board sizes

- Easy: always `6×6`
- Medium: always `7×7`
- Hard levels 1–20: `8×8`
- Hard level 21 onward: `9×9`

All generated boards must be square.

### Initial target clue ranges

- Easy `6×6`: 13–16 clues
- Medium `7×7`: 12–15 clues
- Hard `8×8`: 10–13 clues
- Hard `9×9`: 11–14 clues

These are centralized initial calibration values.

### Solving philosophy

- Every generated puzzle must have exactly one solution.
- No puzzle should require guessing from the player.
- Backtracking may be used internally to prove uniqueness.
- Backtracking must not be treated as part of the intended player solve path.
- This iteration must use the existing basic logical rules only:
  - clue single
  - cell single
- Do not implement advanced deduction rules in this iteration.

### Internal score

Keep a numerical difficulty score for:

- Debugging
- Ranking candidate puzzles within a tier
- Future calibration

Do not use the score as the primary or sole definition of Easy, Medium, or Hard.

### Fallback behavior

If an ideal candidate cannot be found, return the closest candidate that still satisfies every structural requirement.

Never silently return a puzzle that violates its tier’s:

- Board size
- Clue-count range
- Unique-solution requirement
- Logical-solvability requirement
- Minimum rectangle area
- Search safety limits

### Clue placement

Implement multi-placement analysis now.

For each valid partition, try several deterministic clue-position combinations and select the placement that best matches the requested tier.

### Compatibility

The app has no released players.

It is acceptable for existing levels to generate different puzzles after this change. Preserve saved level numbers and selected difficulty, but no migration or compatibility layer for old generated boards is required.

---

# 1. Fix the solver correctness issue first

The current solver tracks cell options with a map keyed by clue, similar to:

```dart
final options = <int, int>{};

for (...) {
  if (candidateCoversCell) {
    options[clue] = candidateIndex;
  }
}
```

This is incorrect.

A single clue may have multiple different candidate rectangles that cover the same cell. Keying the collection by clue collapses those candidates into one entry.

That can cause the solver to:

- Treat a cell as forced when multiple rectangle candidates remain
- Arbitrarily select one candidate
- Underestimate ambiguity
- Distort difficulty analysis
- Drop valid search branches
- Potentially report incorrect uniqueness results

Replace this logic everywhere it appears, including:

- Cell-single propagation
- Initial forced-move analysis
- Cell-based search branching
- Any helper that counts cell ownership or options

Track unique rectangle candidates, not only clue owners.

A private reference type is acceptable:

```dart
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
```

A cell is a cell single only when exactly one compatible rectangle candidate remains:

```dart
candidateRefs.length == 1
```

It is not enough for only one clue to be capable of owning the cell.

Add a regression test where:

- One uncovered cell is covered by multiple candidate rectangles
- Those candidates belong to the same clue
- The cell must not be treated as a forced rectangle

Complete this fix before using solver metrics to classify generated puzzles.

---

# 2. Separate the logical solve from uniqueness search

The current analyzer mixes logical propagation and recursive search metrics.

Refactor the responsibilities so the system can distinguish:

## Logical player solve

Uses only:

- Clue single
- Cell single

It must not branch or guess.

Expose an API similar to:

```dart
LogicalSolveAnalysis analyzeLogically(Puzzle puzzle);
```

The exact model name may differ, but it should report at least:

```dart
final bool solved;
final int clueCount;
final int cellCount;
final double averageInitialCandidates;
final int maxInitialCandidates;
final int initialForcedClues;
final int initialForcedCells;
final int propagationRounds;
final int forcedPlacements;
```

The logical analyzer must solve from clues only and must never inspect `puzzle.solution`.

## Uniqueness proof

May use bounded backtracking.

Keep or improve:

```dart
int countSolutions(
  Puzzle puzzle, {
  int limit = 2,
  int nodeLimit = 5000,
});
```

It must:

- Stop after finding two solutions
- Respect the node limit
- Return 0, 1, or 2
- Solve from clues only
- Never use the stored generated solution

Search metrics may still be logged separately, but search depth and guesses must not determine whether a puzzle is intended to require player guessing.

## Required acceptance condition

Every generated puzzle must satisfy both:

```dart
logicalAnalysis.solved == true
```

and:

```dart
solver.countSolutions(puzzle, limit: 2) == 1
```

This means the puzzle is logically solvable with the supported human rules and also has exactly one solution.

---

# 3. Redesign the difficulty profile around square size and clue density

Update `DifficultyProfile` in `lib/models/puzzle_difficulty.dart`.

Remove the rectangular-grid model:

```dart
minRows
maxRows
minCols
maxCols
```

Replace it with explicit square-board configuration.

One possible design:

```dart
@immutable
class DifficultyProfile {
  final PuzzleDifficulty difficulty;
  final int Function(int level) boardSizeForLevel;
  final int Function(int level) minCluesForLevel;
  final int Function(int level) maxCluesForLevel;

  // Soft quality targets
  final double? minInitialForcedRatio;
  final double? maxInitialForcedRatio;
  final double? minAverageInitialCandidates;
  final double? maxAverageInitialCandidates;
  final int? minPropagationRounds;

  // Generation and safety
  final int maxPartitionAttempts;
  final int cluePlacementAttempts;
  final int searchNodeLimit;
}
```

A static method or switch-based helpers may be preferable to storing functions in const profiles. Use the cleanest Dart design for centralized configuration.

Add useful derived metrics to the analysis model:

```dart
double get clueDensity => clueCount / cellCount;
double get averageRegionArea => cellCount / clueCount;
```

If useful, also include:

```dart
final int initialForcedCells;
final int minCandidateCount;
final int maxCandidateCount;
```

Keep all thresholds and generation constants in one place.

Do not scatter tier values throughout the generator.

---

# 4. Implement exact square-board progression

The generator must resolve the board size as follows:

```dart
int boardSizeFor(PuzzleDifficulty difficulty, int level) {
  switch (difficulty) {
    case PuzzleDifficulty.easy:
      return 6;
    case PuzzleDifficulty.medium:
      return 7;
    case PuzzleDifficulty.hard:
      return level <= 20 ? 8 : 9;
  }
}
```

Every generated puzzle must satisfy:

```dart
puzzle.rows == puzzle.cols
```

and the exact tier/level size above.

Remove `_rowsFor()` and `_colsFor()` or refactor them into one board-size method.

The board size is a structural rule. It must also be respected by fallback generation.

---

# 5. Make clue count an explicit generation target

The current generator indirectly determines clue count through:

- `stopProb`
- Maximum region area
- Random recursive cuts

This makes difficulty unpredictable and currently tends to create more small regions for Hard.

Replace that behavior with an explicit target region count.

Because each generated solution region produces one clue:

```text
target region count = target clue count
```

For each candidate partition:

1. Resolve a deterministic target clue count within the tier’s range.
2. Generate exactly that number of regions.
3. Reject a partition that cannot reach the target cleanly.
4. Place one clue in each region.
5. Analyze the resulting puzzle.

A suitable signature:

```dart
List<GridRect>? _partitionToTarget(
  int size,
  Random rng, {
  required int targetRegionCount,
  int minRegionArea = 2,
});
```

## Target clue progression

Use deterministic level progression inside the approved ranges.

Suggested initial mapping:

### Easy

- Level 1 starts near 16 clues
- Gradually decrease toward 13 clues by level 20
- Clamp at 13 for later levels

### Medium

- Level 1 starts near 15 clues
- Gradually decrease toward 12 clues by level 20
- Clamp at 12 for later levels

### Hard 8×8

- Levels 1–20 gradually decrease from 13 clues to 10 clues

### Hard 9×9

- Level 21 starts near 14 clues
- Gradually decrease toward 11 clues by level 40
- Clamp at 11 for later levels

Keep the exact interpolation method deterministic and centralized.

Integer rounding must not produce values outside the approved ranges.

A direct helper is appropriate:

```dart
int targetClueCountFor(
  PuzzleDifficulty difficulty,
  int level,
);
```

The same level, difficulty, and seed must always produce the same target and puzzle.

---

# 6. Replace stop-probability partitioning with target-count partitioning

Refactor `_partition()`.

Recommended approach:

1. Start with one region covering the whole square board.
2. While `regions.length < targetRegionCount`:
   - Find regions that can be split into two rectangles with area at least 2.
   - Choose a splittable region using deterministic weighted randomness.
   - Prefer larger regions so the partition remains balanced.
   - Enumerate valid vertical and horizontal cuts.
   - Select a valid cut.
   - Replace the parent with the two children.
3. Return the partition only when the exact target count is reached.
4. Reject and retry when no valid split can reach the target.

Maintain:

- Full grid coverage
- No overlaps
- Rectangle areas of at least 2
- Determinism

Avoid relying on `maxArea` as the main difficulty control.

A maximum region area may remain as a safety or shape-quality guard, but Hard must not be assigned a lower maximum area than Easy in a way that forces Hard to contain more clues.

## Shape-quality preferences

Treat these as soft ranking signals, not absolute bans unless necessary:

- Avoid excessive full-width or full-height strips
- Avoid too many `1×N` regions
- Prefer a mix of widths, heights, and areas
- Avoid partitions where most clues have only one possible rectangle before solving
- Do not optimize only for very large rectangles; large but obvious strips can still be easy

---

# 7. Implement multi-placement clue analysis

For every structurally valid partition, generate multiple deterministic clue placements.

Start with:

```dart
cluePlacementAttempts = 8
```

Keep it centralized and easy to tune.

For each placement attempt:

1. Place one clue inside every solution rectangle.
2. Build a candidate puzzle.
3. Run the corrected logical analyzer.
4. Reject it if it cannot be solved without guessing.
5. Check the structural clue-count and board-size rules.
6. Check uniqueness with `countSolutions(..., limit: 2)`.
7. Calculate internal quality metrics and score.
8. Rank it against the requested tier.

Do not assume that:

- Center placement always means Easy
- Edge placement always means Hard

Instead, let measured ambiguity and forced moves determine placement quality.

Use weighted randomness to create different candidate placements, but preserve determinism.

## Placement preference by tier

### Easy

Prefer placements with:

- More valid opening moves
- Higher initial forced ratio
- Lower average candidate count
- Shorter propagation chains

### Medium

Prefer placements with:

- Moderate ambiguity
- Some obvious moves, but fewer than Easy
- Longer propagation than Easy
- A balanced candidate distribution

### Hard

Prefer placements with:

- Fewer obvious opening moves
- Higher average candidate count
- More interacting candidate rectangles
- Longer logical propagation
- Still fully solvable using only clue singles and cell singles

The chosen Hard placement must never require branching in the logical solve.

---

# 8. Redefine structural requirements versus soft quality targets

Implement two levels of acceptance.

## Structural requirements

A candidate must never violate these:

- Correct square board size
- Clue count within the approved tier range
- Region count equals clue count
- Every solution region has area at least 2
- Full board coverage
- No overlapping solution regions
- Every region contains exactly one clue
- Clue value equals region area
- Logical analyzer solves the puzzle without guessing
- Exactly one solution
- Search stays within safety limits

A fallback candidate must satisfy all structural requirements.

## Soft quality targets

Use these to rank candidates and decide whether to continue searching:

- Initial forced ratio
- Average initial candidate count
- Maximum initial candidate count
- Propagation rounds
- Shape diversity
- Number of narrow regions
- Internal score

Suggested starting targets:

### Easy

- `initialForcedRatio >= 0.25`
- `averageInitialCandidates <= 3.0`
- Prefer higher forced ratio and fewer propagation rounds

### Medium

- Prefer `initialForcedRatio` roughly between 0.10 and 0.35
- Prefer average candidate count above Easy
- Prefer more propagation rounds than Easy

### Hard

- Prefer `initialForcedRatio <= 0.20`
- Prefer `averageInitialCandidates >= 2.5`
- Prefer longer propagation chains
- Prefer fewer immediately forced clues than Medium

These are soft initial calibration values.

Do not fail generation solely because one soft threshold is narrowly missed if the fallback satisfies every structural requirement.

---

# 9. Keep the internal score, but change its role

Keep `DifficultyAnalysis.score` or an equivalent diagnostic score from 0 to 100.

Remove search depth and guesses as major difficulty contributors because puzzles must not require player guessing.

Suggested score components:

```text
25% board-size component
25% clue-density / average-region-area component
20% average candidate ambiguity
20% inverse initial forced ratio
10% logical propagation length
```

Normalize every component to 0–1.

The score should:

- Help rank placements and partitions
- Appear in debug logs
- Support future telemetry calibration
- Not override structural tier rules
- Not allow a wrong-size or wrong-density puzzle into a tier

A high score does not make a puzzle Hard if it violates the Hard board or clue-count rules.

A low score does not make a structurally Hard puzzle Easy.

---

# 10. Improve fallback selection

The current generator tracks a closest unique puzzle and may return it even when it misses the requested difficulty profile.

Change fallback selection so only structurally valid candidates are eligible.

Maintain a best candidate per generation request:

```dart
Puzzle? bestStructuralCandidate;
DifficultyAnalysis? bestStructuralAnalysis;
```

Rank eligible candidates using tier-specific soft distance.

If no ideal match is found:

- Return the best structurally valid candidate
- Include analysis in debug mode
- Log which soft targets were missed

If no structurally valid candidate is found after bounded attempts:

- Throw a clear `StateError`
- Include difficulty, level, board size, target clue count, partition attempts, and placement attempts in the error message

Do not return an ambiguous puzzle or a puzzle requiring logical guessing.

---

# 11. Preserve deterministic generation

The same inputs must always produce the same puzzle:

```text
level + difficulty + explicit seed
```

When no explicit seed is supplied, derive one from:

```text
level + difficulty
```

Determinism must cover:

- Board size
- Target clue count
- Partition
- Clue placements
- Chosen candidate
- Stored solution
- Difficulty analysis in debug mode

Use deterministic sub-seeds for:

- Partition attempt
- Clue-placement attempt

Do not reuse one mutable `Random` in a way that makes later behavior depend on rejected candidates or debug-only operations.

A pattern such as this is appropriate:

```dart
final partitionSeed = mix(baseSeed, partitionAttempt);
final placementSeed = mix(partitionSeed, placementAttempt);
```

---

# 12. Update difficulty labels and descriptions

The existing difficulty UI and persistence can remain.

Update the user-facing descriptions so they reflect the new model.

Suggested copy:

```dart
PuzzleDifficulty.easy => '6×6 with more clues and clearer openings.',
PuzzleDifficulty.medium => '7×7 with fewer clues and longer deductions.',
PuzzleDifficulty.hard => 'Large grids, fewer clues, deeper logic.',
```

Keep descriptions concise enough for the existing cards.

Do not redesign the Home screen, Settings sheet, or game screen.

Ensure the UI correctly reflects:

- Hard levels 1–20 as 8×8
- Hard level 21 onward as 9×9

No progress migration is needed.

---

# 13. Keep gameplay behavior unchanged

Do not break:

- Drag-to-draw
- Eraser behavior
- Undo
- Hints
- Wand
- Timer
- Haptics
- Level progression
- Difficulty persistence
- Separate level progress per difficulty
- Validator behavior
- Light and dark themes

The generated `solution` must remain aligned with `clues` because hints and the wand depend on it.

The validator should continue to accept any valid player tiling. Uniqueness guarantees that the valid tiling matches the stored solution logically.

---

# 14. Add and update tests

Expand the logic tests substantially.

## Solver regression

Add a manually constructed fixture proving that:

- One cell can be covered by multiple candidates from the same clue
- Those candidates are kept as separate candidate references
- The cell is not considered forced
- Uniqueness counting explores all valid rectangle candidates

## Exact board sizes

Test multiple levels:

```dart
expect(easy.rows, 6);
expect(easy.cols, 6);

expect(medium.rows, 7);
expect(medium.cols, 7);

expect(hardLevel20.rows, 8);
expect(hardLevel20.cols, 8);

expect(hardLevel21.rows, 9);
expect(hardLevel21.cols, 9);
```

Also assert:

```dart
expect(puzzle.rows, puzzle.cols);
```

for all generated puzzles.

## Clue ranges

For a deterministic sample:

- Easy has 13–16 clues
- Medium has 12–15 clues
- Hard 8×8 has 10–13 clues
- Hard 9×9 has 11–14 clues

Test the boundary at Hard levels 20 and 21.

## Target progression

Verify that early levels start toward the high end of each clue range and later levels move toward the low end.

Do not require strict monotonic reduction every single level if deterministic variation is intentionally used, but the resolved target helper must stay within range and follow the planned progression.

Prefer directly testing the target-resolution helper if it is publicly testable or exposed with `@visibleForTesting`.

## Logical solvability

For multiple generated levels in every tier:

```dart
final logical = solver.analyzeLogically(puzzle);

expect(logical.solved, isTrue);
```

If the logical model contains guesses or search depth, assert zero:

```dart
expect(logical.guesses, 0);
expect(logical.maxSearchDepth, 0);
```

## Uniqueness

For at least:

- Easy levels 1–30
- Medium levels 1–30
- Hard levels 1–40

Use deterministic seeds and assert:

```dart
expect(
  solver.countSolutions(puzzle, limit: 2),
  1,
);
```

## Structural validity

For every sampled puzzle:

- Solution covers every cell exactly once
- Solution rectangles do not overlap
- Every rectangle has area at least 2
- Every rectangle contains exactly one clue
- Every clue value equals its rectangle area
- Number of solution rectangles equals number of clues
- Validator accepts the stored solution

## Difficulty ordering

Across a deterministic sample, verify aggregate trends:

```text
Easy clue density > Medium clue density > Hard clue density
Easy average region area < Medium average region area < Hard average region area
Easy average initial forced ratio > Hard average initial forced ratio
Easy average initial candidates < Hard average initial candidates
```

Do not require every individual puzzle to be perfectly ordered.

Use aggregate averages to avoid brittle tests.

## Determinism

Generate the same level, difficulty, and seed twice.

Assert equality of:

- Rows and columns
- Clue count
- Every clue position and value
- Every solution rectangle
- Difficulty analysis fields
- Target clue count if stored

## Fallback safety

Create a testable configuration with deliberately strict soft targets and limited attempts.

Verify that fallback:

- May miss a soft target
- Still has correct size
- Still has an allowed clue count
- Is logically solvable
- Is unique
- Has no one-cell regions

## Existing tests

Preserve or update existing tests for:

- Validator overlap detection
- `GridRect.fromCorners`
- Single-cell touch behavior
- Two-cell drag behavior
- No one-cell rectangles
- Stored solution validity

---

# 15. Add debug calibration output

In debug mode, log a compact line for generated puzzles.

Example:

```text
Level 12 | hard | 8x8 | target clues 11 | actual clues 11 |
score 72 | density 0.172 | avg area 5.82 |
avg candidates 3.6 | initial forced clues 1/11 |
initial forced cells 2 | rounds 7 | logical solved true |
solutions 1 | uniqueness nodes 34 |
partition attempt 18 | placement attempt 6 | fallback false
```

For Hard level 21+, the log should show `9x9`.

Do not log during release builds.

Keep the log stable and readable so generated samples can later be exported and compared.

---

# 16. Performance requirements

Puzzle generation must remain bounded.

Centralize:

- Maximum partition attempts
- Clue-placement attempts per partition
- Uniqueness node limit

Avoid running the expensive uniqueness search for obviously poor candidates.

Preferred pipeline:

1. Generate exact-count partition
2. Generate clue placement
3. Enumerate candidates
4. Reject contradictions
5. Run logical-only solve
6. Reject if not logically solvable
7. Check structural and soft metrics
8. Run uniqueness proof for promising placements
9. Rank accepted candidates

Do not add isolates or background processing unless the current synchronous generation becomes observably slow and the change is necessary. Keep this iteration focused on generator and solver correctness.

Do not create an unbounded loop.

---

# 17. Suggested file-level changes

## `lib/models/puzzle_difficulty.dart`

- Preserve the difficulty enum
- Redesign `DifficultyProfile`
- Replace row/column ranges with square-size rules
- Add clue-count ranges and target helpers
- Add soft quality thresholds
- Add clue density and average region area metrics
- Keep internal score
- Update descriptions

## `lib/logic/puzzle_solver.dart`

- Fix candidate collapsing by clue
- Track candidate rectangles uniquely
- Correct cell-single propagation
- Correct initial forced-cell analysis
- Correct cell-based search branching
- Add logical-only analysis
- Keep bounded uniqueness counting
- Ensure both systems solve from clues only
- Keep advanced deductions out of scope

## `lib/logic/generator.dart`

- Use one square board size
- Resolve explicit target clue count
- Generate partitions to exact region count
- Try multiple clue placements
- Require logical solve without guessing
- Require exactly one solution
- Rank by tier-specific soft quality
- Restrict fallback to structurally valid candidates
- Preserve determinism
- Improve debug output

## `lib/models/puzzle.dart`

- Keep the current fields unless additional analysis metadata is useful
- Preserve clue-to-solution alignment
- Continue attaching analysis only in debug mode if appropriate

## UI and state files

- Keep existing difficulty persistence and separate levels
- Update descriptions only
- Do not redesign unrelated UI
- Confirm Hard level 21 correctly loads a 9×9 puzzle

## Tests

- Add solver fixtures
- Add exact-size tests
- Add clue-range tests
- Add logical-solvability tests
- Add aggregate difficulty-ordering tests
- Add fallback structural-safety tests
- Preserve existing gameplay tests

---

# 18. Out of scope

Do not implement these in this iteration:

- Advanced human deduction rules
- Locked groups
- Shared-cell ownership deductions beyond the corrected cell-single rule
- Contradiction-based candidate elimination as a player-facing rule
- Telemetry or analytics
- New difficulty tiers
- Expert mode
- Daily challenges
- Remote puzzle storage
- UI redesign
- Migration for previously generated puzzles
- Changes to hints or wand behavior

---

# Definition of done

The work is complete when all of the following are true:

- Easy always generates 6×6 boards
- Medium always generates 7×7 boards
- Hard levels 1–20 generate 8×8 boards
- Hard level 21 onward generates 9×9 boards
- Every board is square
- Every puzzle stays within its approved clue-count range
- Hard has fewer clues and larger average regions than easier tiers in aggregate
- The solver no longer collapses multiple rectangle candidates from the same clue
- Every generated puzzle is solvable using only clue singles and cell singles
- No generated puzzle requires player guessing
- Every generated puzzle has exactly one solution
- Every solution rectangle has area at least 2
- Fallback never violates structural tier requirements
- Generation remains deterministic
- Difficulty score remains available internally
- Existing gameplay behavior remains unchanged
- Existing progress and difficulty persistence still work
- `flutter analyze` passes
- `flutter test` passes

---

# Final response required from Cursor

After implementing the changes, provide a concise report containing:

1. Files created
2. Files modified
3. Solver bug fix summary
4. New board-size rules
5. New clue-count rules
6. Partition-generation approach
7. Clue-placement analysis approach
8. Logical-solvability and uniqueness strategy
9. Fallback behavior
10. Internal score changes
11. Tests added or updated
12. `flutter analyze` result
13. `flutter test` result
14. Any thresholds that should be calibrated after manually playing generated puzzles

Implement the changes directly rather than only describing them.
