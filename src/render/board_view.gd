class_name BoardView
extends Node2D
## Draws a GameSession's board and active piece with procedural rectangles.
## Read-only view of game state; hidden rows are not drawn.

const BACKGROUND_COLOR := Color(0.08, 0.08, 0.11)
const GRID_COLOR := Color(1, 1, 1, 0.07)
const BLOCK_INSET: float = 1.0
const GHOST_FILL_ALPHA: float = 0.18
const GHOST_OUTLINE_ALPHA: float = 0.6
const LINE_CLEAR_FLASH_SECONDS: float = 0.2
const LINE_CLEAR_FLASH_COLOR := Color(1, 1, 1, 0.6)
const HARD_DROP_TRAIL_SECONDS: float = 0.15
const HARD_DROP_TRAIL_ALPHA: float = 0.3
const GAME_OVER_FADE_SECONDS: float = 0.5
const GAME_OVER_TINT := Color(0.7, 0.05, 0.05, 0.35)

const PIECE_COLORS: Dictionary = {
	Tetromino.Type.I: Color(0.2, 0.85, 0.95),
	Tetromino.Type.O: Color(0.95, 0.85, 0.2),
	Tetromino.Type.T: Color(0.7, 0.35, 0.85),
	Tetromino.Type.S: Color(0.3, 0.8, 0.35),
	Tetromino.Type.Z: Color(0.9, 0.3, 0.3),
	Tetromino.Type.J: Color(0.3, 0.4, 0.9),
	Tetromino.Type.L: Color(0.95, 0.6, 0.2),
}

## Pixel size of one board cell; set by the layout.
var cell_size: int = 48

## Ghost piece visibility (view option only; never affects gameplay).
var show_ghost: bool = true

var _session: GameSession
## Short-lived visual effects, in board-cell units (see _add_effect).
var _effects: Array[Dictionary] = []
var _game_over_seconds: float = 0.0


func bind(session: GameSession) -> void:
	_session = session
	session.lines_cleared.connect(_on_lines_cleared)
	session.hard_dropped.connect(_on_hard_dropped)
	queue_redraw()


func _process(delta: float) -> void:
	var animating: bool = not _effects.is_empty()
	for effect in _effects:
		effect["age"] += delta
	_effects = _effects.filter(func(e: Dictionary) -> bool: return e["age"] < e["duration"])
	if _session != null and _session.game_over:
		_game_over_seconds += delta
	else:
		_game_over_seconds = 0.0
	var fading: bool = _game_over_seconds > 0.0 and _game_over_seconds < GAME_OVER_FADE_SECONDS + delta
	if animating or fading:
		queue_redraw()


## Flashes each cleared row (the board has already collapsed; this is feedback only).
func _on_lines_cleared(rows: Array[int]) -> void:
	for y in rows:
		if _session.board.is_visible_row(y):
			_add_effect(Rect2(0, y - Board.HIDDEN_ROWS, Board.WIDTH, 1), LINE_CLEAR_FLASH_COLOR, LINE_CLEAR_FLASH_SECONDS)


## A faint streak above each landed block showing the distance it fell.
func _on_hard_dropped(cells: Array[Vector2i], distance: int) -> void:
	if distance <= 0:
		return
	var color: Color = PIECE_COLORS[_session.active.type]
	color.a = HARD_DROP_TRAIL_ALPHA
	for c in cells:
		var top: int = maxi(c.y - distance, Board.HIDDEN_ROWS)
		if c.y > top:
			_add_effect(Rect2(c.x, top - Board.HIDDEN_ROWS, 1, c.y - top), color, HARD_DROP_TRAIL_SECONDS)


func _add_effect(rect: Rect2, color: Color, duration: float) -> void:
	_effects.append({"rect": rect, "color": color, "age": 0.0, "duration": duration})
	queue_redraw()


func set_cell_size(value: int) -> void:
	cell_size = value
	queue_redraw()


func board_pixel_size() -> Vector2:
	return Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * cell_size


func _draw() -> void:
	var size := board_pixel_size()
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	for x in range(Board.WIDTH + 1):
		draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, size.y), GRID_COLOR)
	for y in range(Board.VISIBLE_ROWS + 1):
		draw_line(Vector2(0, y * cell_size), Vector2(size.x, y * cell_size), GRID_COLOR)
	if _session == null:
		return
	for y in range(Board.HIDDEN_ROWS, Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			var id: int = _session.board.get_cell(x, y)
			if id != Board.EMPTY:
				_draw_block(x, y, id)
	_draw_effects()
	if _session.active != null:
		if show_ghost:
			for c in _session.ghost_cells():
				_draw_ghost_block(c.x, c.y, _session.active.type)
		for c in _session.active.cells():
			_draw_block(c.x, c.y, _session.active.type)
	if _game_over_seconds > 0.0:
		_draw_game_over_tint()


func _draw_block(x: int, y: int, type: int) -> void:
	if not _session.board.is_visible_row(y):
		return
	var pos := Vector2(x, y - Board.HIDDEN_ROWS) * cell_size
	var rect := Rect2(pos, Vector2(cell_size, cell_size)).grow(-BLOCK_INSET)
	draw_rect(rect, PIECE_COLORS[type])


func _draw_effects() -> void:
	for effect in _effects:
		var rect: Rect2 = effect["rect"]
		var color: Color = effect["color"]
		color.a *= 1.0 - effect["age"] / effect["duration"]
		draw_rect(Rect2(rect.position * cell_size, rect.size * cell_size), color)


func _draw_game_over_tint() -> void:
	var tint := GAME_OVER_TINT
	tint.a *= minf(_game_over_seconds / GAME_OVER_FADE_SECONDS, 1.0)
	draw_rect(Rect2(Vector2.ZERO, board_pixel_size()), tint)


func toggle_ghost() -> void:
	show_ghost = not show_ghost
	queue_redraw()


func _draw_ghost_block(x: int, y: int, type: int) -> void:
	if not _session.board.is_visible_row(y):
		return
	var pos := Vector2(x, y - Board.HIDDEN_ROWS) * cell_size
	var rect := Rect2(pos, Vector2(cell_size, cell_size)).grow(-BLOCK_INSET)
	var color: Color = PIECE_COLORS[type]
	draw_rect(rect, Color(color, GHOST_FILL_ALPHA))
	draw_rect(rect, Color(color, GHOST_OUTLINE_ALPHA), false, 2.0)
