class_name BoardView
extends Node2D
## Draws a Board with procedural rectangles. Read-only view of game state.

const CELL_SIZE: int = 48
const BACKGROUND_COLOR := Color(0.08, 0.08, 0.11)
const GRID_COLOR := Color(1, 1, 1, 0.07)

var _board: Board


func bind(board: Board) -> void:
	_board = board
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
