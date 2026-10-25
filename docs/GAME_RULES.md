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
- Super Rotation System (SRS) with standard wall-kick tables (separate for I).
- Hold: one swap per piece; usable again after the next lock.
- Ghost piece shows the hard-drop landing position.

## Gravity, locking
- Gravity: 1000 ms per row at level 1 (`GameSession.gravity_interval_ms`); the
  Guideline level curve arrives with levels. Timing is integer milliseconds.
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
(Right), `soft_drop` (Down), `hard_drop` (Space). Latest direction pressed wins.

## Scoring (Guideline)
- Soft drop: 1 point per cell. Hard drop: 2 points per cell.
- Line clears (x level): single 100, double 300, triple 500, Tetris 800.
- T-spin scoring and back-to-back / combo bonuses: **(TBD)**, may be
  deferred past the first playable release.

## Marathon
- Start at level 1; level up every 10 lines cleared.
- **(decision)** Game ends at level 15 (150 lines) as a win, or on top-out.
- Top-out: a piece locks entirely above the visible board, or a new piece
  cannot spawn because it overlaps existing blocks.

## Out of scope
Multiplayer, online features, other modes, 1980s-style rotation, sound/visual
effects beyond simple coloured blocks.
