# Game Rules

Modern Tetris Guideline-style rules, single-player Marathon mode, offline.
Items marked **(decision)** are variant-specific choices; items marked **(TBD)**
are to be finalised in the milestone that implements them.

## Board
- **(decision)** 10 columns x **24** visible rows (a taller-than-Guideline
  playfield for phones), plus 20 hidden rows above (44 total). The logical
  size is the same on every device; only the drawn cell size changes with the
  screen, never the number of rows.
- Integer grid; (0,0) is top-left of the hidden buffer, y grows downward.
  Visible rows are y = 20..43; the floor row is y = 43.
- Pieces spawn with their lower row on the first visible row (y = 20) and their
  upper row in the hidden buffer (y = 19). **(decision)** Spawn is checked
  against locked cells; a blocked spawn is a top-out.

## Pieces
- Seven tetrominoes: I, O, T, S, Z, J, L, each a fixed colour.
- Spawn orientation per Guideline: flat side down, horizontally centred
  (3-wide pieces at columns 3-5, I and O centred).
- 7-bag randomizer: pieces are drawn from a shuffled bag of all seven.
- Next queue: **(decision)** show 5 upcoming pieces.

## Movement and rotation
- Left/right shift, soft drop, hard drop, clockwise and counter-clockwise rotation.
- Super Rotation System (SRS): states 0 (spawn), R, 2, L. Each rotation tries
  the 5 standard kick tests in order and uses the first that fits; if none fit
  the rotation fails and the piece is unchanged. J/L/S/T/Z share one table, I has
  its own. **(decision)** O has no kicks and its rotation is a no-op that does
  not reset the lock timer. Kick data is in `src/logic/srs.gd`, transcribed
  y-up as published and flipped to Godot's y-down at lookup.
- Hold: one use per piece; available again once the piece locks. An empty slot
  takes the piece and spawns the next queued one; an occupied slot swaps without
  touching the queue. The incoming piece always spawns in its canonical
  orientation and position. If it cannot spawn, the game is over (block-out).
- Ghost piece shows the exact hard-drop landing position. It is visual only and
  can be toggled off; it has no effect on collision or gameplay.

## Gravity, locking
- **Gravity is score-based (custom variant).** This intentionally differs from
  the Guideline level curve. Fall speed depends only on the current run's
  score, via one table in `src/logic/gravity.gd`. Every point source counts
  (line clears, T-Spins, combos, soft and hard drop points). The saved high
  score never affects it, restarting returns to 1000 ms, and since score only
  rises within a run, the game never gets slower.

  | Score from | ms per row |
  |---|---|
  | 0 | 1000 |
  | 1,250 | 850 |
  | 3,750 | 700 |
  | 7,500 | 550 |
  | 12,500 | 430 |
  | 18,750 | 340 |
  | 27,500 | 270 |
  | 37,500 | 240 |
  | 50,000 | 210 |
  | 68,750 | 190 |
  | 93,750+ | 170 (cap) |

  Never faster than one row per 170 ms. When a threshold is crossed mid-fall
  the piece keeps the same fraction of its current row, so there is no jump.
  **LEVEL** still rises every 10 cleared lines and still multiplies line-clear
  points, but no longer affects gravity. Timing is integer milliseconds.
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

## Controls
Input Map actions in `project.godot`: `move_left` (Left), `move_right`
(Right), `soft_drop` (Down), `hard_drop` (Space), `rotate_cw` (Up, X),
`rotate_ccw` (Z), `restart` (R), `hold` (C or Shift), `toggle_ghost` (G), `toggle_sound` (M), `pause` (Esc or P). Latest direction pressed wins.

**Screen layout** (portrait, `src/ui/game_layout.gd`). The project stretches
with `canvas_items` + aspect `expand`, so on any phone the game fills the
whole display (no letterbox bars) with square, undistorted cells; the navy
background is the viewport clear colour and reaches behind the notch and home
indicator, while every element stays inside the platform safe area. Top to
bottom: a horizontal HUD (SCORE, LINES, LEVEL, BEST: four equal sections,
caption over value, centred, large numbers shrink to fit), the 10 x 24 board
centred on the screen, then the controller. NEXT sits vertically centred beside
the board (right column); the last-lock award text (e.g. T-SPIN DOUBLE,
BACK-TO-BACK, COMBO) sits in the left column, centred beside the board, and
HOLD (desktop only) tops that column. Cells are the largest that fit; spare
height is split evenly into the HUD-board and board-controller gaps.

The on-screen controller (bottom of the screen) presses the same actions: a
D-pad on the left (left, right, down = soft drop; the up arm is decoration),
one large round X button (counter-clockwise rotation) on the right, and a
PAUSE pill between them. There is no touch O button: clockwise rotation,
hold and hard drop have no touch control (and the hold slot is hidden on
phones); they remain keyboard actions (`rotate_cw` is Up or X on a keyboard).
The board sits at the top of the safe area; on shorter screens the cells
shrink uniformly so the 24 rows always fit above the controller.
Holding LEFT/RIGHT uses the normal DAS/ARR. Multiple
fingers work at once, and a finger can slide between LEFT, RIGHT and SOFT.
A finger that started on the D-pad stays tracked until it is lifted: leaving
the D-pad releases the held direction, and coming back resumes without
lifting (with a 10 px hysteresis so a boundary wobble does not flicker).
X and PAUSE fire once on touch-down and never re-fire when a finger slides
back onto them. Pausing, losing focus or a layout change releases everything.
Pressed buttons are drawn recessed; X/PAUSE stay drawn pressed for at least
90 ms so a fast tap is visible (the action itself is not delayed).
Gestures are not implemented. The ghost toggle is keyboard-only.

Pausing (button, Esc/P, or the app losing focus) freezes all time and input;
a Pause overlay offers Resume and Restart, and Game Over shows the final
score with Restart.

## Scoring (`src/logic/score_keeper.gd`, `src/logic/t_spin.gd`)
Follows the Tetris Guideline scoring as publicly documented (tetris.wiki).
All line-based points are multiplied by the level in effect *before* the lock
(a clear that levels you up is still paid at the old level). Every lock is
scored exactly once, by `ScoreKeeper.register_lock()`.

| Action | Base points |
|---|---|
| Soft drop | 1 per cell fallen while held (gravity falls score nothing) |
| Hard drop | 2 per cell |
| Single / Double / Triple / Tetris | 100 / 300 / 500 / 800 |
| T-Spin Mini (0 / 1 / 2 lines) | 100 / 200 / 400 |
| T-Spin (0 / 1 / 2 / 3 lines) | 400 / 800 / 1200 / 1600 |
| Combo | 50 x combo x level, from the second consecutive clearing lock |
| Perfect clear (1 / 2 / 3 / 4 lines) | 800 / 1200 / 1800 / 2000, **added** to the clear score |
| Back-to-Back Tetris perfect clear | 3200 instead of 2000 |

**T-Spin detection (three-corner rule).** A lock is a T-Spin when the piece is
a T, its last successful action was a rotation, and at least three of the four
corners of its 3x3 box are occupied (locked cells, walls and the floor all
count). It is a full T-Spin if both *front* corners (the two on the side the
T's nub points to) are occupied, otherwise a Mini. If the rotation used the
fifth SRS kick test (the 1x2 kick) a Mini is promoted to a full T-Spin. Any
horizontal move, gravity/soft-drop step or hard drop that actually moves the
piece after the rotation cancels the spin; a hard drop of zero cells (piece
already resting) does not. Hold gives a fresh piece, so the spin never carries.

**Back-to-Back.** Difficult clears are Tetrises and any T-Spin or T-Spin Mini
that clears at least one line. The first starts the chain; each following
difficult clear scores 1.5x its base points (before the level multiplier and
combo bonus). A Single, Double or Triple without a T-Spin breaks the chain.
Locks that clear no lines (including T-Spins with no lines) neither break nor
extend it.

**Combo.** The counter is -1 with no chain, 0 on the first clearing lock, then
increments on each consecutive clearing lock; any lock that clears nothing
resets it. The bonus is 50 x counter x level, added on top of the action score
(including T-Spins and perfect clears).

**Perfect clear.** Detected after the lines are removed: the whole board,
including the hidden rows, is empty. A perfect clear needs at least one cleared
line.

### Intentional differences from other published implementations
- **No "immobile" test.** Some games (e.g. TETR.IO) require the T to be unable
  to move after the spin; this game uses the Guideline three-corner rule only.
- **Perfect clear is additive.** The bonus is paid in addition to the normal
  clear points (Tetris Guideline / modern console games). Some games replace
  the line score instead. The Back-to-Back Tetris bonus (3200) replaces the 2000
  bonus, while the Tetris itself still gets its own 1.5x.
- **Zero-line T-Spins** score (100/400 x level) but do not touch Back-to-Back and
  do reset the combo (a lock without a clear).
- **T-Spin Mini with 3+ lines** cannot occur under SRS; if it were reported it
  would be scored as a full T-Spin.
- **Scores are not capped,** and lock-outs (game over) award nothing.
- **Hard drop keeps a spin only if the piece does not move.** Rotating in the air
  and then hard-dropping is not a T-Spin even if the landing spot would be.
- The perfect-clear and Back-to-Back scores, and the 1.5x on mini/T-Spin
  clears, follow the Guideline tables; where games disagree this file is the
  reference for tests.

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

## Feedback, sound and saved data
- Effects are deliberately small and short: a white flash over each cleared row
  (0.2 s), a faint streak above a hard-dropped piece (0.15 s), and a red tint
  fading in over the board at game over. No particles.
- Sounds are generated at startup (square-wave blips, no audio files): move,
  rotate, hold, hard-drop thud, lock tick, a clear jingle that gets longer with
  more lines, and a falling game-over tune. Sound can be turned off from the
  Pause overlay (SOUND button) or with M.
- Saved locally in `user://save.cfg`, never transmitted: the high score, the
  sound preference and the ghost preference. A missing or corrupt file just
  resets to defaults. The high score is also committed when the app is
  backgrounded or closed mid-game.
- Backgrounding or losing focus pauses the game and releases all held inputs;
  it stays paused until you resume. The Android back button pauses.
- A single frame is simulated for at most 100 ms, so a hitch never causes a
  burst of catch-up movement.

## Out of scope
Multiplayer, online features, other modes, 1980s-style rotation, sound/visual
effects beyond simple coloured blocks.
