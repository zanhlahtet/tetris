# Game Rules

Modern Tetris Guideline-style rules, single-player Marathon mode, offline.
Items marked **(decision)** are variant-specific choices; items marked **(TBD)**
are to be finalised in the milestone that implements them.

## Board
- 10 columns x 20 visible rows, plus 20 hidden rows above (40 total).
- Integer grid; (0,0) is top-left of the hidden buffer, y grows downward.
  Visible rows are y = 20..39.
- Pieces spawn in the hidden area, partly overlapping the top visible rows.

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
- Gravity speed set by level using the Guideline curve.
- Soft drop: **(decision)** fixed multiple of gravity (20x), no score cap tweaks.
- Hard drop locks immediately.
- Lock delay: 0.5 s, resets on successful move/rotate, with **(decision)**
  a cap of 15 resets per piece (step-reset / "extended placement").
- Auto-repeat (DAS/ARR) for horizontal movement; touch values **(TBD)**.

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
