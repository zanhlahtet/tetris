# CLAUDE.md

Mobile (iOS/Android, portrait, offline) Tetris Guideline-style clone in
Godot 4.7 / typed GDScript. Marathon mode only. Rules: `docs/GAME_RULES.md`.

## Architecture
Strict layering; dependencies point down only.

| Layer | Path | Responsibility |
|---|---|---|
| Logic | `src/logic/` | Pure gameplay and board state (`RefCounted`, no Nodes). Fully unit-testable. |
| Session | `src/session/` | `GameSession`: owns board, active piece, upcoming queue, bag (later timers/score); consumes abstract commands. |
| Render | `src/render/` | Draws state with procedural rectangles. Read-only. `RetroDraw` holds the palette and the one tile/panel renderer shared by board and previews. |
| Input | `src/input/` | Device input -> abstract command signals. No game knowledge. |
| HUD/UI | `src/ui/` | Score, next/hold, touch controls. Reads session, never mutates the board. |
| Audio | `src/audio/` | `SfxSynth` generates the effects; `Sfx` plays them from session events. No asset files. |
| Persistence | `src/persist/` | `SaveData`: high score and preferences in `user://save.cfg`. |
| Composition | `scenes/main.*` | Wires the above together, owns saving and app-lifecycle handling. |

Rules:
- Logic and session code must not reference Nodes, scenes, `Input`, or rendering.
- Grid coordinates are integers; x right, y down; row 0 is the top of the
  hidden buffer (`Board.HIDDEN_ROWS` = 20 hidden rows above 20 visible).
- No physics engine; collisions are grid lookups.
- Base resolution 720x1280, stretch `canvas_items`, aspect `expand`: taller or
  wider screens get extra viewport, never letterboxing. `GameLayout.compute(safe_rect)`
  (pure, tested) places every element from the usable area; `scenes/main.gd`
  feeds it the platform safe area on phones and re-applies on resize.
- Touch: `TouchControls` hit-tests raw `InputEventScreenTouch/Drag` (GUI Buttons
  only route one pointer) and emits `action_changed`; `ControllerSkin` (pure drawing helpers) paints the controller look (D-pad, X/O face buttons, PAUSE; no HOLD/DROP buttons, those are keyboard-only); `main.gd` turns that into
  `InputEventAction`s, so touch and keyboard share `InputHandler`. It must never
  reference the session or board. Desktop emulates touch from the mouse.
- Pause/Game Over screens are `Overlay` (GUI buttons); `GameSession.paused`
  freezes ticks and commands. The app auto-pauses when it loses focus.

Piece model: `Tetromino` (static SRS shape data; type value = board cell id),
`ActivePiece` (type/rotation/origin, never stored in the Board until locked),
`BagRandomizer` (seedable 7-bag; `GameSession.new(seed, true)` for determinism).

Session simulation: `GameSession.tick(delta_ms)` takes integer milliseconds and
is the only source of time; commands are `set_direction`, `set_soft_drop`,
`hard_drop`, `rotate_cw`, `rotate_ccw`, `restart`, `hold`. `ghost_cells()` is a pure query used by the view. `session.stats` (`ScoreKeeper`) holds score, lines, level and the Back-to-Back/combo chains;
`session.last_lock` is the last lock's scored result (HUD award text). `TSpin.detect`
is the three-corner test; `ActivePiece.spun/kick_index` feed it; `Gravity` maps level to ms/row. The HUD reads them. SRS kick tables live in `Srs` (published
y-up data, returned y-down). Tests drive it directly with no scene or rendering. `scenes/main.gd`
converts frame delta to whole ms. Input is read only via Input Map actions in
`InputHandler`.

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

## Events, effects and persistence
`GameSession` emits presentation signals (`moved`, `rotated`, `held`, `hard_dropped`,
`locked`, `lines_cleared`, `game_ended`); sound (`Sfx`) and visual effects
(`BoardView`) only listen. Session logic must never depend on them. Preferences
and the high score live in `SaveData`; load failures fall back to defaults.

## Building for devices
See `docs/BUILDING.md`. `export_presets.cfg` is committed without credentials;
never commit keystores, provisioning profiles or team-specific secrets.

## Fonts
Pixelify Sans (OFL) in `assets/fonts/`, default theme font via `project.godot`; `RetroFont.bold()` for drawn/emphasised text. Hold slot is hidden on mobile (`GameLayout.compute(safe, show_hold)`).
