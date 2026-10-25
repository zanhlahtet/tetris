# CLAUDE.md

Mobile (iOS/Android, portrait, offline) Tetris Guideline-style clone in
Godot 4.7 / typed GDScript. Marathon mode only. Rules: `docs/GAME_RULES.md`.

## Architecture
Strict layering; dependencies point down only.

| Layer | Path | Responsibility |
|---|---|---|
| Logic | `src/logic/` | Pure gameplay and board state (`RefCounted`, no Nodes). Fully unit-testable. |
| Session | `src/session/` | `GameSession`: owns board, active piece, upcoming queue, bag (later timers/score); consumes abstract commands. |
| Render | `src/render/` | Draws state with procedural rectangles. Read-only. |
| Input | `src/input/` | Device input -> abstract command signals. No game knowledge. |
| HUD/UI | `src/ui/` | Score, next/hold, touch controls. Reads session, never mutates the board. |
| Composition | `scenes/main.*` | Wires the above together. |

Rules:
- Logic and session code must not reference Nodes, scenes, `Input`, or rendering.
- Grid coordinates are integers; x right, y down; row 0 is the top of the
  hidden buffer (`Board.HIDDEN_ROWS` = 20 hidden rows above 20 visible).
- No physics engine; collisions are grid lookups.
- Base resolution 720x1280, stretch `canvas_items`, aspect `keep`.
  Board cell is 48px (`BoardView.CELL_SIZE`).

Piece model: `Tetromino` (static SRS shape data; type value = board cell id),
`ActivePiece` (type/rotation/origin, never stored in the Board until locked),
`BagRandomizer` (seedable 7-bag; `GameSession.new(seed, true)` for determinism).

## Conventions
- Typed GDScript: annotate variables, parameters and returns.
- `class_name` for shared types; snake_case files; one class per file.
- Keep it simple: no abstractions before a second use, no third-party addons.

## Commands
Godot binary on macOS: `/Applications/Godot.app/Contents/MacOS/Godot`
(alias as `$GODOT`).

- Import/refresh project: `$GODOT --headless --path . --import`
- Run tests (exit code 1 on failure): `$GODOT --headless --path . --script res://tests/run_tests.gd`
- Run game on desktop: `$GODOT --path .`
- Smoke-load main scene: `$GODOT --headless --path . --quit-after 5`

Tests: add `tests/test_<name>.gd` extending `RefCounted` with `var t: Object`
and methods named `test_*`; use `t.check(cond, msg)` / `t.check_eq(a, b, msg)`.
Commit generated `*.uid` files; never commit `.godot/`.

## Git workflow
- `main` is stable. Work on `feat/<milestone>-<name>` branches.
- Small focused commits; imperative messages.
- Push the branch; open PRs only when asked. Never force-push; never merge
  without review.
