extends RefCounted
## T-Spin detection (three-corner rule) on hand-built boards.

var t: Object

const NONE := TSpin.Kind.NONE
const MINI := TSpin.Kind.MINI
const FULL := TSpin.Kind.FULL
const ORIGIN := Vector2i(3, 30)  # box origin; centre is at (4, 31)

const BACK_CORNERS: Dictionary = {
	0: [Vector2i(0, 2), Vector2i(2, 2)],
	1: [Vector2i(0, 0), Vector2i(0, 2)],
	2: [Vector2i(0, 0), Vector2i(2, 0)],
	3: [Vector2i(2, 0), Vector2i(2, 2)],
}


func _piece(rotation: int, spun: bool = true, kick_index: int = 0, type: int = Tetromino.Type.T) -> ActivePiece:
	var p := ActivePiece.new(type)
	p.rotation = rotation
	p.origin = ORIGIN
	p.spun = spun
	p.kick_index = kick_index
	return p


func _board_with(corners: Array) -> Board:
	var b := Board.new()
	for c: Vector2i in corners:
		b.set_cell(ORIGIN.x + c.x, ORIGIN.y + c.y, 1)
	return b


func test_not_a_t_spin_without_rotation_as_last_move() -> void:
	var all := TSpin.CORNERS
	t.check_eq(TSpin.detect(_board_with(all), _piece(0, false)), NONE, "last move was not a rotation")


func test_only_t_pieces_can_t_spin() -> void:
	for type in Tetromino.ALL_TYPES:
		if type == Tetromino.Type.T:
			continue
		t.check_eq(TSpin.detect(_board_with(TSpin.CORNERS), _piece(0, true, 0, type)), NONE, Tetromino.type_name(type))


func test_fewer_than_three_corners_is_nothing() -> void:
	for r in range(4):
		t.check_eq(TSpin.detect(_board_with([]), _piece(r)), NONE, "no corners r%d" % r)
		t.check_eq(TSpin.detect(_board_with([TSpin.CORNERS[0]]), _piece(r)), NONE, "one corner r%d" % r)
		t.check_eq(TSpin.detect(_board_with([TSpin.CORNERS[0], TSpin.CORNERS[3]]), _piece(r)), NONE, "two corners r%d" % r)


func test_both_front_corners_and_one_back_is_full_in_every_orientation() -> void:
	for r in range(4):
		for back: Vector2i in BACK_CORNERS[r]:
			var corners: Array = TSpin.FRONT_CORNERS[r] + [back]
			t.check_eq(TSpin.detect(_board_with(corners), _piece(r)), FULL, "r%d back %s" % [r, back])


func test_one_front_and_both_back_is_mini_in_every_orientation() -> void:
	for r in range(4):
		for front: Vector2i in TSpin.FRONT_CORNERS[r]:
			var corners: Array = BACK_CORNERS[r] + [front]
			t.check_eq(TSpin.detect(_board_with(corners), _piece(r)), MINI, "r%d front %s" % [r, front])


func test_four_corners_is_full() -> void:
	for r in range(4):
		t.check_eq(TSpin.detect(_board_with(TSpin.CORNERS), _piece(r)), FULL, "r%d" % r)


func test_fifth_kick_promotes_mini_to_full() -> void:
	for r in range(4):
		var corners: Array = BACK_CORNERS[r] + [TSpin.FRONT_CORNERS[r][0]]
		t.check_eq(TSpin.detect(_board_with(corners), _piece(r, true, 3)), MINI, "fourth kick stays mini r%d" % r)
		t.check_eq(TSpin.detect(_board_with(corners), _piece(r, true, 4)), FULL, "fifth kick promotes r%d" % r)


func test_fifth_kick_does_not_create_a_t_spin_from_two_corners() -> void:
	t.check_eq(TSpin.detect(_board_with([TSpin.CORNERS[0], TSpin.CORNERS[1]]), _piece(2, true, 4)), NONE, "needs three corners")


func test_walls_and_floor_count_as_occupied() -> void:
	# Nub pointing right (R) against the left wall: both left corners are walls
	# (back corners); one right (front) corner locked -> Mini.
	var b := Board.new()
	var p := _piece(1)
	p.origin = Vector2i(-1, 30)
	b.set_cell(p.origin.x + 2, p.origin.y + 0, 1)
	t.check_eq(TSpin.detect(b, p), MINI, "wall back corners + one front")
	b.set_cell(p.origin.x + 2, p.origin.y + 2, 1)
	t.check_eq(TSpin.detect(b, p), FULL, "both front corners")
	# Nub pointing up (0) on the floor: bottom corners are below the board.
	var floor_board := Board.new()
	var q := _piece(0)
	q.origin = Vector2i(3, Board.TOTAL_ROWS - 2)  # centre on the floor row; bottom corners below it
	floor_board.set_cell(q.origin.x, q.origin.y, 1)
	t.check_eq(TSpin.detect(floor_board, q), MINI, "floor back corners + one front")


func test_detection_does_not_modify_state() -> void:
	var b := _board_with(TSpin.CORNERS)
	var p := _piece(2)
	TSpin.detect(b, p)
	t.check(p.spun and p.rotation == 2 and p.origin == ORIGIN, "piece unchanged")
	t.check_eq(b.get_cell(ORIGIN.x, ORIGIN.y), 1, "board unchanged")
