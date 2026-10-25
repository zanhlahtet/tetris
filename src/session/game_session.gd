class_name GameSession
extends RefCounted
## Game session/controller. Owns the Board, bag, upcoming queue and active
## piece, and advances them deterministically: all timing is integer
## milliseconds fed to tick(), so behaviour is identical at any frame rate and
## fully testable without rendering. Consumes abstract commands; never touches
## rendering or input devices.

const PREVIEW_COUNT: int = 3
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
## True after block-out (spawn blocked) or lock-out (piece locked entirely in
## the hidden rows). No further ticking or commands apply until restart().
var game_over: bool = false
## Lock-timer resets used by the current piece (0..MAX_LOCK_RESETS).
var lock_resets: int = 0

var _bag: BagRandomizer
var _gravity_ms: int = 0
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
	game_over = false
	lock_resets = 0
	_gravity_ms = 0
	_lock_ms = 0
	_held_ms = 0
	_repeat_moves = 0


## Milliseconds per row of automatic fall at the current level.
func gravity_interval_ms() -> int:
	return Gravity.interval_ms(stats.level)


## Takes the next piece from the queue and spawns it. Returns false (and leaves
## no active piece) if the spawn position is blocked, which ends the game.
func spawn_next() -> bool:
	var piece := ActivePiece.new(queue.pop_front())
	_fill_queue()
	_gravity_ms = 0
	_lock_ms = 0
	lock_resets = 0
	if not board.can_place(piece.cells()):
		active = null
		game_over = true
		return false
	active = piece
	return true


## True if the active piece cannot move down.
func is_grounded() -> bool:
	return active != null and not _can_move(0, 1)


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
	stats.add_hard_drop(dropped)
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
	_gravity_ms += delta_ms
	var interval: int = gravity_interval_ms()
	if _soft_drop:
		interval = maxi(1, interval / SOFT_DROP_FACTOR)
	while _gravity_ms >= interval:
		_gravity_ms -= interval
		active.origin.y += 1
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
	for offset in Srs.kick_offsets(active.type, from, to):
		var new_origin: Vector2i = active.origin + offset
		if board.can_place(active.cells_at(new_origin, to)):
			active.origin = new_origin
			active.rotation = to
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
	var moved: Array[Vector2i] = []
	for c in active.cells():
		moved.append(c + Vector2i(dx, dy))
	return board.can_place(moved)


## Writes the piece into the board, clears and scores lines, then spawns the
## next piece. Lock-out: a piece locked entirely above the visible rows ends
## the game immediately.
func _lock_piece() -> void:
	var locked_cells: Array[Vector2i] = active.cells()
	var lock_out: bool = true
	for c in locked_cells:
		board.set_cell(c.x, c.y, active.type)
		if board.is_visible_row(c.y):
			lock_out = false
	active = null
	if lock_out:
		game_over = true
		return
	var full: Array[int] = board.full_rows()
	if not full.is_empty():
		board.clear_rows(full)
		stats.add_line_clear(full.size())
	spawn_next()


func _is_playing() -> bool:
	return active != null and not game_over


func _fill_queue() -> void:
	while queue.size() < PREVIEW_COUNT:
		queue.append(_bag.next())
