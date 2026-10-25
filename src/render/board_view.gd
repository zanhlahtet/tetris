class_name BoardView
extends Node2D
## Draws a GameSession's board and active piece with procedural rectangles.
## Read-only view of game state; hidden rows are not drawn.

const CELL_SIZE: int = 48
const BACKGROUND_COLOR := Color(0.08, 0.08, 0.11)
const GRID_COLOR := Color(1, 1, 1, 0.07)
const BLOCK_INSET: float = 1.0

const PIECE_COLORS: Dictionary = {
	Tetromino.Type.I: Color(0.2, 0.85, 0.95),
	Tetromino.Type.O: Color(0.95, 0.85, 0.2),
	Tetromino.Type.T: Color(0.7, 0.35, 0.85),
	Tetromino.Type.S: Color(0.3, 0.8, 0.35),
	Tetromino.Type.Z: Color(0.9, 0.3, 0.3),
	Tetromino.Type.J: Color(0.3, 0.4, 0.9),
	Tetromino.Type.L: Color(0.95, 0.6, 0.2),
}

var _session: GameSession


func bind(session: GameSession) -> void:
	_session = session
	queue_redraw()


func board_pixel_size() -> Vector2:
	return Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * CELL_SIZE


func _draw() -> void:
	var size := board_pixel_size()
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	for x in range(Board.WIDTH + 1):
		draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, size.y), GRID_COLOR)
	for y in range(Board.VISIBLE_ROWS + 1):
		draw_line(Vector2(0, y * CELL_SIZE), Vector2(size.x, y * CELL_SIZE), GRID_COLOR)
	if _session == null:
		return
	for y in range(Board.HIDDEN_ROWS, Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			var id: int = _session.board.get_cell(x, y)
			if id != Board.EMPTY:
				_draw_block(x, y, id)
	if _session.active != null:
		for c in _session.active.cells():
			_draw_block(c.x, c.y, _session.active.type)


func _draw_block(x: int, y: int, type: int) -> void:
	if not _session.board.is_visible_row(y):
		return
	var pos := Vector2(x, y - Board.HIDDEN_ROWS) * CELL_SIZE
	var rect := Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)).grow(-BLOCK_INSET)
	draw_rect(rect, PIECE_COLORS[type])
