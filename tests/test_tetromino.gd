extends RefCounted

var t: Object


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out := cells.duplicate()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


func test_seven_types_four_cells_each() -> void:
	t.check_eq(Tetromino.ALL_TYPES.size(), 7, "seven types")
	for type in Tetromino.ALL_TYPES:
		for r in range(4):
			var cells := Tetromino.cells(type, r)
			t.check_eq(cells.size(), 4, "%s r%d has 4 cells" % [Tetromino.type_name(type), r])
			var size := Tetromino.box_size(type)
			for c in cells:
				t.check(c.x >= 0 and c.x < size and c.y >= 0 and c.y < size,
						"%s r%d cell in box" % [Tetromino.type_name(type), r])


func test_spawn_shapes() -> void:
	t.check_eq(_sorted(Tetromino.cells(Tetromino.Type.T, 0)),
			[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i], "T spawn")
	t.check_eq(_sorted(Tetromino.cells(Tetromino.Type.I, 0)),
			[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)] as Array[Vector2i], "I spawn")
	t.check_eq(_sorted(Tetromino.cells(Tetromino.Type.S, 0)),
			[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i], "S spawn")


func test_srs_rotation_states() -> void:
	# T pointing right (R state)
	t.check_eq(_sorted(Tetromino.cells(Tetromino.Type.T, 1)),
			[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)] as Array[Vector2i], "T R")
	# I vertical in column 2 (R) and column 1 (L), per SRS
	t.check_eq(_sorted(Tetromino.cells(Tetromino.Type.I, 1)),
			[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)] as Array[Vector2i], "I R")
	t.check_eq(_sorted(Tetromino.cells(Tetromino.Type.I, 3)),
			[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)] as Array[Vector2i], "I L")
	# J state 2 is spawn rotated 180: flat side up
	t.check_eq(_sorted(Tetromino.cells(Tetromino.Type.J, 2)),
			[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)] as Array[Vector2i], "J 2")


func test_o_never_changes() -> void:
	for r in range(1, 4):
		t.check_eq(_sorted(Tetromino.cells(Tetromino.Type.O, r)), _sorted(Tetromino.cells(Tetromino.Type.O, 0)), "O r%d" % r)


func test_four_rotations_return_to_spawn() -> void:
	for type in Tetromino.ALL_TYPES:
		t.check_eq(_sorted(Tetromino.cells(type, 4)), _sorted(Tetromino.cells(type, 0)), "%s wraps" % Tetromino.type_name(type))


func test_spawn_positions_centred_and_in_buffer() -> void:
	for type in Tetromino.ALL_TYPES:
		var cells := ActivePiece.new(type).cells()
		var min_x := 99
		var max_x := -1
		var max_y := -1
		for c in cells:
			min_x = mini(min_x, c.x)
			max_x = maxi(max_x, c.x)
			max_y = maxi(max_y, c.y)
		var name := Tetromino.type_name(type)
		# Piece width is 2 (O), 4 (I) or 3: centred means equal margin either side
		# for even widths, and left margin == right margin - 1 for 3-wide pieces.
		match type:
			Tetromino.Type.O: t.check_eq([min_x, max_x], [4, 5], "O columns")
			Tetromino.Type.I: t.check_eq([min_x, max_x], [3, 6], "I columns")
			_: t.check_eq([min_x, max_x], [3, 5], "%s columns" % name)
		t.check_eq(max_y, Board.HIDDEN_ROWS, "%s lower row is first visible row" % name)
		t.check(Board.new().can_place(cells), "%s spawns on empty board" % name)
