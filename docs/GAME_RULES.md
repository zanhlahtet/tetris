# Game Rules

Modern Tetris Guideline-style rules, single-player Marathon mode, offline.
Items marked **(decision)** are variant-specific choices; items marked **(TBD)**
are to be finalised in the milestone that implements them.

## Board
- 10 columns x 20 visible rows, plus 20 hidden rows above (40 total).
- Integer grid; (0,0) is top-left of the hidden buffer, y grows downward.
  Visible rows are y = 20..39.
- Pieces spawn with their lower row on the first visible row (y = 20) and their
  upper row in the hidden buffer (y = 19). **(decision)** Spawn is checked
  against locked cells; a blocked spawn is a top-out.

## Pieces
- Seven tetrominoes: I, O, T, S, Z, J, L, each a fixed colour.
- Spawn orientation per Guideline: flat side down, horizontally centred
  (3-wide pieces at columns 3-5, I and O centred).
- 7-bag randomizer: pieces are drawn from a shuffled bag of all seven.
- Next queue: **(decision)** show 3 upcoming pieces.

## Movement and rotation
- Left/right shift, soft drop, hard drop, clockwise and counter-clockwise rotation.
- Super Rotation System (SRS): states 0 (spawn), R, 2, L. Each rotation tries
  the 5 standard kick tests in order and uses the first that fits; if none fit
  the rotation fails and the piece is unchanged. J/L/S/T/Z share one table, I has
  its own. **(decision)** O has no kicks and its rotation is a no-op that does
  not reset the lock timer. Kick data is in `src/logic/srs.gd`, transcribed
  y-up as published and flipped to Godot's y-down at lookup.
- Hold: one swap per piece; usable again after the next lock.
- Ghost piece shows the hard-drop landing position.

## Gravity, locking
- Gravity follows the Guideline curve, seconds per row =
  `(0.8 - (level - 1) * 0.007) ^ (level - 1)`, rounded to whole milliseconds
  (`src/logic/gravity.gd`): L1 1000, L2 793, L5 355, L10 64, L15 7 ms/row.
  **(decision)** The curve is clamped at level 15; later levels use that speed.
  Timing is integer milliseconds.
- Soft drop: **(decision)** 20x gravity while held.
- Hard drop moves to the lowest valid position and locks immediately.
- Lock delay: 500 ms starting when the piece lands. A successful move or
  rotation while the piece is still grounded resets the timer, up to
  **15 resets per piece** (**decision**: the counter is never refilled by
  falling lower). After 15 the timer keeps running even if the piece moves.
  Moves while airborne cost nothing.
- A locked piece is written to the board and the next piece spawns at once.
  If the spawn is blocked, the game is over. (Line clears: later milestone.)
- DAS/ARR (`GameSession.das_ms` / `arr_ms`): a direction press moves one cell
  immediately; after **DAS 167 ms** it repeats every **ARR 33 ms** (about
  10 and 2 frames at 60 Hz). ARR 0 slides to the wall. Touch values **(TBD)**.
- Holding a direction carries over to the next piece without a new DAS wait.

## Controls (desktop)
Input Map actions in `project.godot`: `move_left` (Left), `move_right`
(Right), `soft_drop` (Down), `hard_drop` (Space), `rotate_cw` (Up, X),
`rotate_ccw` (Z), `restart` (R). Latest direction pressed wins.

## Scoring (`src/logic/score_keeper.gd`)
- Soft drop: 1 point per cell fallen while soft drop is held. Hard drop: 2
  points per cell. Natural gravity falls score nothing.
- Line clears, multiplied by the level in effect *before* the clear:
  single 100, double 300, triple 500, four lines 800.
- Lines clear instantly on lock (no clear animation or entry delay yet).
- T-spin, back-to-back and combo scoring: **(TBD)**, M7; `ScoreKeeper` is the
  extension point.

## Marathon
- Start at level 1; level = 1 + total lines / 10.
- **(decision)** No level cap or win condition for now (the earlier idea of
  ending at level 15 is deferred); the game runs until top-out.
- Game over, either:
  - **Block-out**: a new piece cannot spawn because it overlaps locked cells.
  - **Lock-out**: a piece locks with all four blocks in the hidden rows
    (above the visible board). Checked before line clears.
  A piece locking partly in the visible rows is not a lock-out.
- Restart (`restart` action, R on desktop) resets board, queue, bag, score,
  lines, level and timers; DAS/ARR settings and held keys are kept.

## Out of scope
Multiplayer, online features, other modes, 1980s-style rotation, sound/visual
effects beyond simple coloured blocks.
