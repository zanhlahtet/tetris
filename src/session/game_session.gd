class_name GameSession
extends RefCounted
## Game session/controller. Owns the Board, bag, upcoming queue and active
## piece, and advances them deterministically: all timing is integer
## milliseconds fed to tick(), so behaviour is identical at any frame rate and
## fully testable without rendering. Consumes abstract commands; never touches
## rendering or input devices.

## Presentation events. Emitted after the state change they describe; the
## session never depends on whoever listens (sound, effects).
signal moved
signal rotated
signal held
## The piece was hard-dropped: its landing cells and how many rows it fell.
signal hard_dropped(cells: Array[Vector2i], distance: int)
signal locked
## Rows (pre-collapse indices) removed by the lock that just happened.
signal lines_cleared(rows: Array[int])
signal game_ended

const PREVIEW_COUNT: int = 5
const LOCK_DELAY_MS: int = 500
## Max grounded move/rotate resets of the lock timer per piece.
const MAX_LOCK_RESETS: int = 15
## Soft drop falls this many times faster than gravity.
const SOFT_DROP_FACTOR: int = 20

## Delayed Auto Shift: hold time before a held direction starts repeating.
var das_ms: int = 167
## Auto Repeat Rate: time between repeated moves once DAS has elapsed.
## 0 slides the piece to the wall instantly.
var arr_ms: int = 33

var board: Board
var stats: ScoreKeeper
var active: ActivePiece = null
## Upcoming piece types, next piece first. Always holds PREVIEW_COUNT entries.
var queue: Array[int] = []
## Piece type in the hold slot, or 0 if empty.
var held_type: int = 0
## True once the current piece has used its hold; cleared when a piece locks.
var hold_used: bool = false
## While true, ticks and all commands are ignored (state is untouched).
var paused: bool = false
## What the most recent lock scored (null before the first lock).
var last_lock: ScoreKeeper.LockResult = null
## True after block-out (spawn blocked) or lock-out (piece locked entirely in
## the hidden rows). No further ticking or commands apply until restart().
var game_over: bool = false
## Lock-timer resets used by the current piece (0..MAX_LOCK_RESETS).
var lock_resets: int = 0

var _bag: BagRandomizer
var _gravity_ms: int = 0
## The base interval _gravity_ms was accumulated against (0 = none yet).
var _applied_interval: int = 0
var _lock_ms: int = 0
var _soft_drop: bool = false
var _direction: int = 0  # held horizontal direction: -1, 0 or 1
var _held_ms: int = 0
var _repeat_moves: int = 0


## With no arguments the sequence is random; pass a seed for determinism.
func _init(seed_value: int = 0, use_seed: bool = false) -> void:
	_reset_state(seed_value, use_seed)


## Resets everything to a fresh game and spawns the first piece. Tuning
## (das_ms, arr_ms) and held-key state (direction, soft drop) are kept; the
## DAS timer restarts.
func restart(seed_value: int = 0, use_seed: bool = false) -> void:
	_reset_state(seed_value, use_seed)
	spawn_next()


func _reset_state(seed_value: int, use_seed: bool) -> void:
	board = Board.new()
	stats = ScoreKeeper.new()
	_bag = BagRandomizer.new(seed_value, not use_seed)
	queue.clear()
	_fill_queue()
	active = null
	held_type = 0
	hold_used = false
	paused = false
	last_lock = null
	game_over = false
	lock_resets = 0
	_gravity_ms = 0
	_applied_interval = 0
	_lock_ms = 0
	_held_ms = 0
	_repeat_moves = 0


## Milliseconds per row of automatic fall at this run's current score.
func gravity_interval_ms() -> int:
	return Gravity.interval_for_score(stats.score)


## Takes the next piece from the queue and spawns it. Returns false (and leaves
## no active piece) if the spawn position is blocked, which ends the game.
func spawn_next() -> bool:
	var type: int = queue.pop_front()
	_fill_queue()
	return _spawn(type)


## Spawns a fresh piece of the given type in its canonical orientation and
## position, resetting per-piece timers. Blocked spawn ends the game.
func _spawn(type: int) -> bool:
	var piece := ActivePiece.new(type)
	_gravity_ms = 0
	_lock_ms = 0
	lock_resets = 0
	if not board.can_place(piece.cells()):
		active = null
		_end_game()
		return false
	active = piece
	return true


## Swaps the active piece with the hold slot. Allowed once per piece (until it
## locks). An empty slot takes the piece and spawns the next queued one; an
## occupied slot swaps without touching the queue. The incoming piece spawns in
## its canonical orientation and position; if that is blocked the game ends.
## Returns true if the hold happened.
func hold() -> bool:
	if not _is_playing() or hold_used:
		return false
	var outgoing: int = active.type
	var incoming: int = held_type
	held_type = outgoing
	if incoming == 0:
		spawn_next()
	else:
		_spawn(incoming)
	hold_used = true
	held.emit()
	return true


## Where the active piece would land on a hard drop. Visual aid only: pure
## query, changes no state. Empty when there is no active piece.
func ghost_cells() -> Array[Vector2i]:
	if active == null:
		return []
	var drop: int = 0
	while true:
		var moved: Array[Vector2i] = []
		for c in active.cells():
			moved.append(c + Vector2i(0, drop + 1))
		if not board.can_place(moved):
			break
		drop += 1
	return active.cells_at(active.origin + Vector2i(0, drop), active.rotation)


## True if the active piece cannot move down.
func is_grounded() -> bool:
	return active != null and not _can_move(0, 1)


## Freezes the game. Ignored once the game is over.
func pause() -> void:
	if not game_over:
		paused = true


func resume() -> void:
	paused = false


## Sets the held horizontal direction (-1, 0, 1). A new non-zero direction
## moves one cell immediately and restarts DAS.
func set_direction(direction: int) -> void:
	if direction == _direction:
		return
	_direction = direction
	_held_ms = 0
	_repeat_moves = 0
	if direction != 0 and _is_playing():
		_move_horizontal(direction)


func set_soft_drop(enabled: bool) -> void:
	_soft_drop = enabled


## Drops the piece to the lowest valid position, locks it and spawns the next.
func hard_drop() -> void:
	if not _is_playing():
		return
	var dropped: int = 0
	while _can_move(0, 1):
		active.origin.y += 1
		dropped += 1
	if dropped > 0:
		active.spun = false
	stats.add_hard_drop(dropped)
	hard_dropped.emit(active.cells(), dropped)
	_lock_piece()


## Rotates clockwise using SRS wall kicks. Returns true if the piece rotated.
func rotate_cw() -> bool:
	return _rotate(1)


## Rotates counter-clockwise using SRS wall kicks. Returns true if rotated.
func rotate_ccw() -> bool:
	return _rotate(-1)


## Advances the simulation by delta_ms milliseconds.
func tick(delta_ms: int) -> void:
	if not _is_playing():
		return
	_tick_horizontal(delta_ms)
	if _is_playing():
		_tick_vertical(delta_ms)


func _tick_horizontal(delta_ms: int) -> void:
	if _direction == 0:
		return
	_held_ms += delta_ms
	if _held_ms < das_ms:
		return
	if arr_ms == 0:
		while _move_horizontal(_direction):
			pass
		return
	var due: int = (_held_ms - das_ms) / arr_ms + 1
	while _repeat_moves < due:
		_repeat_moves += 1
		_move_horizontal(_direction)


func _tick_vertical(delta_ms: int) -> void:
	if is_grounded():
		_gravity_ms = 0
		_lock_ms += delta_ms
		if _lock_ms >= LOCK_DELAY_MS:
			_lock_piece()
		return
	var interval: int = gravity_interval_ms()
	# A score threshold crossed mid-fall (soft-drop points) changes the speed:
	# keep the same fraction of the row so the piece neither jumps nor stalls.
	if _applied_interval != 0 and _applied_interval != interval:
		_gravity_ms = _gravity_ms * interval / _applied_interval
	_applied_interval = interval
	_gravity_ms += delta_ms
	if _soft_drop:
		interval = maxi(1, interval / SOFT_DROP_FACTOR)
	while _gravity_ms >= interval:
		_gravity_ms -= interval
		active.origin.y += 1
		active.spun = false
		if _soft_drop:
			stats.add_soft_drop(1)
		if is_grounded():
			_gravity_ms = 0
			_lock_ms = 0
			return


## Returns true if the piece moved.
func _move_horizontal(direction: int) -> bool:
	var was_grounded: bool = is_grounded()
	if not _can_move(direction, 0):
		return false
	active.origin.x += direction
	active.spun = false
	moved.emit()
	_after_move(was_grounded)
	return true


## Tries the SRS kick tests in order; the first non-colliding one wins. A
## failed rotation changes nothing. O never moves, so its rotation is a visual
## no-op that does not touch the lock timer.
func _rotate(step: int) -> bool:
	if not _is_playing():
		return false
	var from: int = active.rotation
	var to: int = posmod(from + step, Tetromino.ROTATION_COUNT)
	if active.type == Tetromino.Type.O:
		active.rotation = to
		return true
	var was_grounded: bool = is_grounded()
	var kicks: Array[Vector2i] = Srs.kick_offsets(active.type, from, to)
	for i in range(kicks.size()):
		var new_origin: Vector2i = active.origin + kicks[i]
		if board.can_place(active.cells_at(new_origin, to)):
			active.origin = new_origin
			active.rotation = to
			active.spun = true
			active.kick_index = i
			rotated.emit()
			_after_move(was_grounded)
			return true
	return false


## Lock timer bookkeeping after any successful horizontal move or rotation.
func _after_move(was_grounded: bool) -> void:
	if was_grounded and is_grounded():
		if lock_resets >= MAX_LOCK_RESETS:
			return  # cap reached: the timer keeps running
		lock_resets += 1
	_lock_ms = 0


func _can_move(dx: int, dy: int) -> bool:
	var shifted: Array[Vector2i] = []
	for c in active.cells():
		shifted.append(c + Vector2i(dx, dy))
	return board.can_place(shifted)


## Writes the piece into the board, clears and scores lines, then spawns the
## next piece. Lock-out: a piece locked entirely above the visible rows ends
## the game immediately.
func _lock_piece() -> void:
	var spin: int = TSpin.detect(board, active)
	var locked_cells: Array[Vector2i] = active.cells()
	var lock_out: bool = true
	for c in locked_cells:
		board.set_cell(c.x, c.y, active.type)
		if board.is_visible_row(c.y):
			lock_out = false
	active = null
	hold_used = false
	locked.emit()
	if lock_out:
		_end_game()
		return
	var full: Array[int] = board.full_rows()
	if not full.is_empty():
		board.clear_rows(full)
		lines_cleared.emit(full)
	last_lock = stats.register_lock(full.size(), spin, not full.is_empty() and board.is_clear())
	spawn_next()


func _end_game() -> void:
	game_over = true
	game_ended.emit()


func _is_playing() -> bool:
	return active != null and not game_over and not paused


func _fill_queue() -> void:
	while queue.size() < PREVIEW_COUNT:
		queue.append(_bag.next())
