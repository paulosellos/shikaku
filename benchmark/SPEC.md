# Shikaku Benchmark - UI/Mechanics Spec

Derived from `shikaku-benchmark.mp4` (1080x2400 portrait, ~72s). Frames in `benchmark/frames/`.

## Game
Shikaku: partition the whole grid into rectangles. Each rectangle contains exactly one
number, and that number equals the rectangle's area. Rectangles never overlap and must
cover every cell.

- Benchmark board is **7 columns x 8 rows** (clues sum to 56 = 7x8).
- Level label format: `Shikaku <level>-<variant>` (e.g. "Shikaku 30-2").

## Layout
- **Header**: back arrow (left), centered serif title, help icon, settings gear (right),
  and a ">>" skip-to-next button beneath the gear.
- **Board**: centered grid of rounded-square cells with small gaps.
- **Bottom toolbar** (4 rounded buttons): eraser, undo, magic-wand (auto-place, badge
  count e.g. "1"), hint lightbulb (badge count e.g. "6").

## Interaction
- Drag from a cell to draw/extend a rectangle. A semi-transparent preview follows the
  drag; on release it commits with a solid pastel fill and a subtle border.
- The owning clue number is centered in each committed rectangle.
- Eraser removes a rectangle; undo reverts the last action.
- Rectangles use a rotating palette of pastels: green, slate-blue, teal, mauve/pink,
  purple, yellow, tan, salmon/red, light-blue.

## Themes
- **Dark**: background very dark navy (~#141821); empty cells dark slate (~#2b2f38);
  clue text white.
- **Light**: background warm off-white (~#f4efec); empty cells white; clue text near-black.
- Headings use a serif font; some values (Dark/Light/System, "New game at level N") use
  monospace.

## Settings (bottom sheet)
- Title "Settings" with X close.
- **Appearance**: Haptics toggle ("Enhance interactions with gentle haptic feedback");
  Theme segmented control Dark / Light / System.
- **Game**: Show timer toggle; Show size counter toggle; Reset level row (chevron).

## Win screen
- Board animates into a mascot (rounded square split into colored rectangles with a
  checkmark "face").
- Serif headline "Flawless!" (red) + subtitle "You trusted your logic and it paid off
  perfectly."
- "New game at level N" row with a slider and a dice button.
- Row of mascot characters.
- "Continue" button.
