extends RefCounted

var t: Object


func test_dimensions() -> void:
	t.check_eq(Board.WIDTH, 10, "width")
	t.check_eq(Board.VISIBLE_ROWS, 20, "visible rows")
	t.check_eq(Board.HIDDEN_ROWS, 20, "hidden rows")
	t.check_eq(Board.TOTAL_ROWS, 40, "total rows")


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
	t.check(b.is_inside(9, 39), "bottom-right inside")
	t.check(not b.is_inside(-1, 0), "left outside")
	t.check(not b.is_inside(10, 0), "right outside")
	t.check(not b.is_inside(0, -1), "above buffer outside")
	t.check(not b.is_inside(0, 40), "below floor outside")
	t.check(not b.is_empty(-1, 5), "outside is not empty")


func test_visible_rows() -> void:
	var b := Board.new()
	t.check(not b.is_visible_row(19), "row 19 hidden")
	t.check(b.is_visible_row(20), "row 20 first visible")
	t.check(b.is_visible_row(39), "row 39 last visible")
	t.check(not b.is_visible_row(40), "row 40 outside")


func test_set_get_clear() -> void:
	var b := Board.new()
	b.set_cell(3, 25, 4)
	t.check_eq(b.get_cell(3, 25), 4, "set/get")
	t.check(not b.is_empty(3, 25), "occupied")
	b.clear()
	t.check(b.is_empty(3, 25), "cleared")
