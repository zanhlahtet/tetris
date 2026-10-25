class_name Board
extends RefCounted
## Pure board state. No node or rendering dependencies.
##
## Coordinates are integer (x, y) with x growing right and y growing DOWN.
## Row 0 is the top of the hidden buffer; rows HIDDEN_ROWS..TOTAL_ROWS-1 are
## the visible board. Cell value 0 is empty; any other value is a piece id.

const WIDTH: int = 10
const VISIBLE_ROWS: int = 20
const HIDDEN_ROWS: int = 20
const TOTAL_ROWS: int = VISIBLE_ROWS + HIDDEN_ROWS
const EMPTY: int = 0

var _cells: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_cells.resize(WIDTH * TOTAL_ROWS)
	clear()


func clear() -> void:
	_cells.fill(EMPTY)


func is_inside(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < TOTAL_ROWS


func is_visible_row(y: int) -> bool:
	return y >= HIDDEN_ROWS and y < TOTAL_ROWS


func get_cell(x: int, y: int) -> int:
	assert(is_inside(x, y), "get_cell out of bounds: (%d, %d)" % [x, y])
	return _cells[y * WIDTH + x]


func set_cell(x: int, y: int, value: int) -> void:
	assert(is_inside(x, y), "set_cell out of bounds: (%d, %d)" % [x, y])
	_cells[y * WIDTH + x] = value


## True if the cell is inside the board and unoccupied.
func is_empty(x: int, y: int) -> bool:
	return is_inside(x, y) and _cells[y * WIDTH + x] == EMPTY


## True if every cell is inside the board and unoccupied.
func can_place(cells: Array[Vector2i]) -> bool:
	for c in cells:
		if not is_empty(c.x, c.y):
			return false
	return true


## Indices of completely filled rows (ascending, i.e. top to bottom).
func full_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in range(TOTAL_ROWS):
		var full: bool = true
		for x in range(WIDTH):
			if _cells[y * WIDTH + x] == EMPTY:
				full = false
				break
		if full:
			rows.append(y)
	return rows


## Removes the given rows; rows above them fall down, order preserved, and
## empty rows enter at the top.
func clear_rows(rows: Array[int]) -> void:
	var write_y: int = TOTAL_ROWS - 1
	for read_y in range(TOTAL_ROWS - 1, -1, -1):
		if rows.has(read_y):
			continue
		if write_y != read_y:
			for x in range(WIDTH):
				_cells[write_y * WIDTH + x] = _cells[read_y * WIDTH + x]
		write_y -= 1
	for y in range(write_y + 1):
		for x in range(WIDTH):
			_cells[y * WIDTH + x] = EMPTY
