extends RefCounted

var t: Object

## Last board row (the floor row).
const FLOOR: int = Board.TOTAL_ROWS - 1


func test_dimensions() -> void:
	t.check_eq(Board.WIDTH, 10, "width")
	t.check_eq(Board.VISIBLE_ROWS, 24, "visible rows")
	t.check_eq(Board.HIDDEN_ROWS, 20, "hidden rows")
	t.check_eq(Board.TOTAL_ROWS, 44, "total rows")
	t.check_eq(FLOOR, 43, "floor row")


func test_new_board_is_empty() -> void:
	var b := Board.new()
	for y in range(Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			if b.get_cell(x, y) != Board.EMPTY:
				t.check(false, "cell (%d,%d) not empty" % [x, y])
				return
	t.check(true)


func test_bounds() -> void:
	var b := Board.new()
	t.check(b.is_inside(0, 0), "top-left inside")
	t.check(b.is_inside(9, FLOOR), "bottom-right inside")
	t.check(not b.is_inside(-1, 0), "left outside")
	t.check(not b.is_inside(10, 0), "right outside")
	t.check(not b.is_inside(0, -1), "above buffer outside")
	t.check(not b.is_inside(0, FLOOR + 1), "below floor outside")
	t.check(not b.is_empty(-1, 5), "outside is not empty")


func test_visible_rows() -> void:
	var b := Board.new()
	t.check(not b.is_visible_row(19), "row 19 hidden")
	t.check(b.is_visible_row(20), "row 20 first visible")
	t.check(b.is_visible_row(FLOOR), "row 43 last visible")
	t.check(not b.is_visible_row(FLOOR + 1), "row 44 outside")
	var visible := 0
	for y in range(Board.TOTAL_ROWS):
		if b.is_visible_row(y):
			visible += 1
	t.check_eq(visible, 24, "exactly 24 visible rows")


func test_set_get_clear() -> void:
	var b := Board.new()
	b.set_cell(3, 25, 4)
	t.check_eq(b.get_cell(3, 25), 4, "set/get")
	t.check(not b.is_empty(3, 25), "occupied")
	b.clear()
	t.check(b.is_empty(3, 25), "cleared")


func test_can_place_collisions() -> void:
	var b := Board.new()
	t.check(b.can_place([Vector2i(0, FLOOR), Vector2i(9, FLOOR)] as Array[Vector2i]), "corners free")
	t.check(not b.can_place([Vector2i(-1, 30)] as Array[Vector2i]), "left wall")
	t.check(not b.can_place([Vector2i(10, 30)] as Array[Vector2i]), "right wall")
	t.check(not b.can_place([Vector2i(5, FLOOR + 1)] as Array[Vector2i]), "floor")
	t.check(not b.can_place([Vector2i(5, -1)] as Array[Vector2i]), "ceiling")
	b.set_cell(4, 30, 3)
	t.check(not b.can_place([Vector2i(3, 30), Vector2i(4, 30)] as Array[Vector2i]), "locked cell")
	t.check(b.can_place([Vector2i(3, 30), Vector2i(5, 30)] as Array[Vector2i]), "neighbours free")


func _fill_row(b: Board, y: int, value: int = 1, except: Array[int] = []) -> void:
	for x in range(Board.WIDTH):
		if not except.has(x):
			b.set_cell(x, y, value)


func test_full_rows_detection() -> void:
	var b := Board.new()
	t.check(b.full_rows().is_empty(), "empty board")
	_fill_row(b, FLOOR, 1, [3] as Array[int])
	t.check(b.full_rows().is_empty(), "row missing one cell is not full")
	b.set_cell(3, FLOOR, 1)
	_fill_row(b, 5)  # hidden rows count too
	t.check_eq(b.full_rows(), [5, FLOOR] as Array[int], "full rows ascending")


func test_clear_single_row_compacts() -> void:
	var b := Board.new()
	_fill_row(b, FLOOR)
	b.set_cell(0, FLOOR - 1, 5)
	b.set_cell(9, FLOOR - 2, 6)
	b.clear_rows([FLOOR] as Array[int])
	t.check_eq(b.get_cell(0, FLOOR), 5, "row above fell to the floor")
	t.check_eq(b.get_cell(9, FLOOR - 1), 6, "row two above fell one")
	t.check_eq(b.get_cell(1, FLOOR), Board.EMPTY, "rest of fallen row empty")
	t.check(b.full_rows().is_empty(), "no full rows remain")
	t.check_eq(b.get_cell(9, FLOOR - 2), Board.EMPTY, "vacated row empty")


func test_clear_non_adjacent_rows_preserves_order() -> void:
	var b := Board.new()
	_fill_row(b, FLOOR)
	_fill_row(b, FLOOR - 2)
	b.set_cell(1, FLOOR - 1, 2)
	b.set_cell(2, FLOOR - 3, 3)
	b.set_cell(3, FLOOR - 4, 4)
	b.clear_rows([FLOOR - 2, FLOOR] as Array[int])
	t.check_eq(b.get_cell(1, FLOOR), 2, "row above floor moved down 1")
	t.check_eq(b.get_cell(2, FLOOR - 1), 3, "moved down 2")
	t.check_eq(b.get_cell(3, FLOOR - 2), 4, "moved down 2")
	t.check_eq(b.get_cell(1, FLOOR - 1), Board.EMPTY, "old position vacated")


func test_clear_four_rows_and_shift_hidden_rows() -> void:
	var b := Board.new()
	for y in range(FLOOR - 3, FLOOR + 1):
		_fill_row(b, y)
	b.set_cell(7, 19, 3)  # hidden-buffer block above the stack
	b.clear_rows([FLOOR - 3, FLOOR - 2, FLOOR - 1, FLOOR] as Array[int])
	t.check_eq(b.get_cell(7, 23), 3, "hidden block fell four rows")
	t.check_eq(b.get_cell(7, 19), Board.EMPTY, "origin vacated")
	for y in range(Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			if (x != 7 or y != 23) and b.get_cell(x, y) != Board.EMPTY:
				t.check(false, "stray cell at (%d,%d)" % [x, y])
				return
	t.check(true)


func test_clear_rows_across_the_taller_visible_area() -> void:
	# Rows 20..43 are visible; clear one at the top of the visible area and
	# one at the bottom and check everything between shifts correctly.
	var b := Board.new()
	_fill_row(b, Board.HIDDEN_ROWS)
	_fill_row(b, FLOOR)
	b.set_cell(2, Board.HIDDEN_ROWS + 1, 8)
	b.set_cell(3, FLOOR - 1, 9)
	b.clear_rows([Board.HIDDEN_ROWS, FLOOR] as Array[int])
	t.check_eq(b.get_cell(2, Board.HIDDEN_ROWS + 2), 8, "block between shifted down 1")
	t.check_eq(b.get_cell(3, FLOOR), 9, "block above the floor row shifted down 1")
	t.check(b.full_rows().is_empty(), "nothing left full")


func test_clear_nothing_is_noop() -> void:
	var b := Board.new()
	b.set_cell(2, FLOOR, 4)
	b.clear_rows([] as Array[int])
	t.check_eq(b.get_cell(2, FLOOR), 4, "unchanged")
