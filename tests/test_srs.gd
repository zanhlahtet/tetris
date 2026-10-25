extends RefCounted
## SRS rotation tests. Kick offsets in Srs are board-space (y down); comments
## that quote the published tables use y-up, as the wiki does.

var t: Object

const KICK_TYPES: Array[int] = [Tetromino.Type.I, Tetromino.Type.T, Tetromino.Type.S,
		Tetromino.Type.Z, Tetromino.Type.J, Tetromino.Type.L]


func _session(type: int, rotation: int, origin: Vector2i) -> GameSession:
	var s := GameSession.new(1, true)
	s.spawn_next()
	s.active = ActivePiece.new(type)
	s.active.rotation = rotation
	s.active.origin = origin
	return s


## Fills the whole board with locked cells except the piece's own cells.  Optionally leaves one column empty.
func _fill_around_piece(s: GameSession, hole_column: int = -1) -> void:
	var own := s.active.cells()
	for y in range(Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			if x != hole_column and not own.has(Vector2i(x, y)):
				s.board.set_cell(x, y, 1)


# --- table data ---------------------------------------------------------

func test_every_adjacent_transition_has_five_tests_starting_at_zero() -> void:
	for type in KICK_TYPES:
		for from in range(4):
			for step in [1, -1]:
				var to := posmod(from + step, 4)
				var offsets := Srs.kick_offsets(type, from, to)
				var label := "%s %d>%d" % [Tetromino.type_name(type), from, to]
				t.check_eq(offsets.size(), 5, label + " has 5 tests")
				t.check_eq(offsets[0], Vector2i.ZERO, label + " first is plain rotation")


func test_reverse_transition_negates_offsets() -> void:
	# Property of the published SRS tables, for both JLSTZ and I.
	for type in KICK_TYPES:
		for from in range(4):
			var to := (from + 1) % 4
			var forward := Srs.kick_offsets(type, from, to)
			var back := Srs.kick_offsets(type, to, from)
			for i in range(5):
				t.check_eq(back[i], -forward[i], "%s %d<->%d test %d" % [Tetromino.type_name(type), from, to, i + 1])


func test_published_values_and_y_flip() -> void:
	# Wiki, JLSTZ 0>R (y up): (0,0) (-1,0) (-1,+1) (0,-2) (-1,-2)
	t.check_eq(Srs.kick_offsets(Tetromino.Type.T, 0, 1),
			[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)] as Array[Vector2i], "T 0>R in y-down")
	# Wiki, I 0>R (y up): (0,0) (-2,0) (+1,0) (-2,-1) (+1,+2)
	t.check_eq(Srs.kick_offsets(Tetromino.Type.I, 0, 1),
			[Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)] as Array[Vector2i], "I 0>R in y-down")
	# Wiki, JLSTZ L>0 (y up): (0,0) (-1,0) (-1,-1) (0,+2) (-1,+2)
	t.check_eq(Srs.kick_offsets(Tetromino.Type.L, 3, 0),
			[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)] as Array[Vector2i], "L L>0 in y-down")


func test_jlstz_share_one_table_and_i_differs() -> void:
	for type in [Tetromino.Type.S, Tetromino.Type.Z, Tetromino.Type.J, Tetromino.Type.L]:
		t.check_eq(Srs.kick_offsets(type, 0, 1), Srs.kick_offsets(Tetromino.Type.T, 0, 1), "same as T")
	t.check(Srs.kick_offsets(Tetromino.Type.I, 0, 1) != Srs.kick_offsets(Tetromino.Type.T, 0, 1), "I differs")


func test_o_has_no_kicks() -> void:
	t.check_eq(Srs.kick_offsets(Tetromino.Type.O, 0, 1), [Vector2i.ZERO] as Array[Vector2i], "O only plain")


# --- rotation in open space ---------------------------------------------

func test_all_transitions_in_open_space_use_plain_rotation() -> void:
	for type in KICK_TYPES:
		for from in range(4):
			for step in [1, -1]:
				var s := _session(type, from, Vector2i(3, 25))
				var ok := s.rotate_cw() if step == 1 else s.rotate_ccw()
				var label := "%s %d step %d" % [Tetromino.type_name(type), from, step]
				t.check(ok, label + " succeeds")
				t.check_eq(s.active.rotation, posmod(from + step, 4), label + " state")
				t.check_eq(s.active.origin, Vector2i(3, 25), label + " not moved")


func test_four_rotations_return_to_start() -> void:
	for type in KICK_TYPES:
		var s := _session(type, 0, Vector2i(3, 25))
		for i in range(4):
			s.rotate_cw()
		t.check_eq(s.active.rotation, 0, Tetromino.type_name(type) + " cw x4")
		for i in range(4):
			s.rotate_ccw()
		t.check_eq(s.active.rotation, 0, Tetromino.type_name(type) + " ccw x4")
		t.check_eq(s.active.origin, Vector2i(3, 25), Tetromino.type_name(type) + " back at origin")


func test_o_rotation_never_moves() -> void:
	var s := _session(Tetromino.Type.O, 0, Vector2i(3, 25))
	var before := s.active.cells()
	t.check(s.rotate_cw(), "succeeds")
	t.check_eq(s.active.origin, Vector2i(3, 25), "no kick")
	t.check_eq(s.active.cells(), before, "same blocks")
	var walled := _session(Tetromino.Type.O, 0, Vector2i(-1, 25))  # O occupies column 0-1
	walled.rotate_ccw()
	t.check_eq(walled.active.origin, Vector2i(-1, 25), "no kick at wall")


# --- wall, floor and stack kicks ----------------------------------------

func test_left_wall_kick() -> void:
	# T pointing right (R), leftmost block in column 0. Rotating to spawn needs
	# column -1, so kick test 2 (+1, 0) applies.
	var s := _session(Tetromino.Type.T, 1, Vector2i(-1, 25))
	t.check(s.rotate_ccw(), "kicks")
	t.check_eq(s.active.rotation, 0, "state 0")
	t.check_eq(s.active.origin, Vector2i(0, 25), "pushed right one column")


func test_right_wall_kick() -> void:
	# T pointing left (L) against the right wall rotates cw to spawn: kick (-1, 0).
	var s := _session(Tetromino.Type.T, 3, Vector2i(8, 25))
	t.check(s.rotate_cw(), "kicks")
	t.check_eq(s.active.origin, Vector2i(7, 25), "pushed left one column")


func test_i_wall_kick_left() -> void:
	# Vertical I (L) occupies box column 1; origin.x -1 puts it in column 0.
	# Rotating cw to flat needs columns -1..2; L>0 test 2 (+1, 0) fixes it.
	var s := _session(Tetromino.Type.I, 3, Vector2i(-1, 25))
	t.check(s.rotate_cw(), "kicks")
	t.check_eq(s.active.origin, Vector2i(0, 25), "L>0 test 2 moves +1")


func test_i_wall_kick_right() -> void:
	# Vertical I (R) in column 9 rotating ccw to flat: plain needs columns 7..10,
	# test 2 (+2, 0) needs 9..12, test 3 (-1, 0) gives columns 6..9.
	var s := _session(Tetromino.Type.I, 1, Vector2i(7, 25))
	t.check(s.rotate_ccw(), "kicks")
	t.check_eq(s.active.origin, Vector2i(6, 25), "R>0 test 3 moves -1")


func test_floor_kick() -> void:
	# Flat T on the floor (rows 38-39) rotated cw: the plain result needs row 40,
	# test 3 (-1, +1 up) = (-1, -1) lifts it to rows 37-39.
	var s := _session(Tetromino.Type.T, 0, Vector2i(3, 38))
	t.check(s.rotate_cw(), "floor kick")
	t.check_eq(s.active.origin, Vector2i(2, 37), "left one, up one")
	t.check(s.board.can_place(s.active.cells()), "legal")


func test_i_floor_kick() -> void:
	# Flat I on the floor (row 39) rotated cw: plain, tests 2-4 all need rows
	# below the floor; test 5 (+1 right, 2 up) stands it in column 6, rows 36-39.
	var s := _session(Tetromino.Type.I, 0, Vector2i(3, 38))
	t.check(s.rotate_cw(), "floor kick")
	t.check_eq(s.active.origin, Vector2i(4, 36), "test 5")
	t.check(s.board.can_place(s.active.cells()), "legal")


func test_stack_kick_order_and_fifth_test() -> void:
	# For T 0>R in open space, block the candidates of all earlier tests and
	# confirm the next one is chosen. Test 4 (0, +2 down) always shares its
	# upper block with test 1, so it cannot be isolated; the rest can.
	var origin := Vector2i(3, 25)
	var offsets := Srs.kick_offsets(Tetromino.Type.T, 0, 1)
	var probe := ActivePiece.new(Tetromino.Type.T)
	var candidates: Array = []
	for off in offsets:
		candidates.append(probe.cells_at(origin + off, 1))
	var current := probe.cells_at(origin, 0)
	var checked: Array[int] = []
	for target in range(5):
		var s := _session(Tetromino.Type.T, 0, origin)
		var feasible := true
		for k in range(target):
			var blocker := Vector2i(-99, -99)
			for cell: Vector2i in candidates[k]:
				if not current.has(cell) and not candidates[target].has(cell):
					blocker = cell
					break
			if blocker.x == -99:
				feasible = false
				break
			s.board.set_cell(blocker.x, blocker.y, 1)
		if not feasible:
			continue
		checked.append(target)
		t.check(s.rotate_cw(), "test %d reachable" % (target + 1))
		t.check_eq(s.active.origin, origin + offsets[target], "test %d chosen" % (target + 1))
	t.check_eq(checked, [0, 1, 2, 4] as Array[int], "tests 1, 2, 3 and 5 exercised")


func test_t_spin_triple_style_stack_kick() -> void:
	# Classic overhang: T pointing up in a well, rotating to R needs the
	# (-1, +2 down) test-5 kick, dropping the piece two rows.
	var s := _session(Tetromino.Type.T, 0, Vector2i(3, 25))
	# Block tests 1-4 using candidate cells (see previous test), leave test 5.
	var probe := ActivePiece.new(Tetromino.Type.T)
	var offsets := Srs.kick_offsets(Tetromino.Type.T, 0, 1)
	t.check_eq(offsets[4], Vector2i(-1, 2), "fifth test is left one, down two")
	var current := probe.cells_at(Vector2i(3, 25), 0)
	var fifth := probe.cells_at(Vector2i(3, 25) + offsets[4], 1)
	for k in range(4):
		for cell: Vector2i in probe.cells_at(Vector2i(3, 25) + offsets[k], 1):
			if not current.has(cell) and not fifth.has(cell):
				s.board.set_cell(cell.x, cell.y, 1)
				break
	t.check(s.rotate_cw(), "stack kick succeeds")
	t.check_eq(s.active.origin, Vector2i(2, 27), "down two, left one")


# --- failure ------------------------------------------------------------

func test_blocked_rotation_changes_nothing() -> void:
	for type in KICK_TYPES:
		for step in [1, -1]:
			var s := _session(type, 0, Vector2i(3, 25))
			_fill_around_piece(s)
			var cells_before := s.active.cells()
			var ok := s.rotate_cw() if step == 1 else s.rotate_ccw()
			var label := "%s step %d" % [Tetromino.type_name(type), step]
			t.check(not ok, label + " fails")
			t.check_eq(s.active.rotation, 0, label + " rotation unchanged")
			t.check_eq(s.active.origin, Vector2i(3, 25), label + " origin unchanged")
			t.check_eq(s.active.cells(), cells_before, label + " cells unchanged")


func test_rotation_never_overlaps_or_leaves_board() -> void:
	# Sweep every position/state/direction for every kicking piece in a half-
	# filled board and assert any successful rotation is legal.
	for type in KICK_TYPES:
		for rotation in range(4):
			for x in range(-2, 9):
				for y in [18, 30, 36, 37, 38]:
					for step in [1, -1]:
						var s := _session(type, rotation, Vector2i(x, y))
						if not s.board.can_place(s.active.cells()):
							continue
						for cx in range(Board.WIDTH):
							if cx % 3 != 0:
								s.board.set_cell(cx, 39, 1)
						if not s.board.can_place(s.active.cells()):
							continue
						var ok := s.rotate_cw() if step == 1 else s.rotate_ccw()
						if ok and not s.board.can_place(s.active.cells()):
							t.check(false, "illegal result %s r%d (%d,%d)" % [Tetromino.type_name(type), rotation, x, y])
							return
	t.check(true)


# --- lock delay integration ---------------------------------------------

func test_rotation_resets_lock_timer() -> void:
	var s := _session(Tetromino.Type.T, 0, Vector2i(3, 38))
	var piece := s.active
	s.tick(400)
	t.check(s.rotate_cw(), "rotates")
	t.check_eq(s.lock_resets, 1, "reset counted")
	s.tick(400)
	t.check(s.active == piece, "timer was reset")
	s.tick(100)
	t.check(s.active != piece, "locks 500ms after the rotation")


## Drops the piece onto its resting row without touching any timers.
func _sink(s: GameSession) -> void:
	while not s.is_grounded():
		s.active.origin.y += 1


func test_rotation_reset_cap() -> void:
	var s := _session(Tetromino.Type.T, 0, Vector2i(3, 38))
	var piece := s.active
	var guard := 0
	while s.lock_resets < GameSession.MAX_LOCK_RESETS and guard < 100:
		guard += 1
		s.tick(10)
		t.check(s.rotate_cw(), "rotation %d" % guard)
		_sink(s)  # some kicks lift the piece off the floor; put it back
	t.check_eq(s.lock_resets, 15, "15 used")
	t.check(s.active == piece, "still alive")
	# At the cap further rotations must not extend the timer. A rotation that
	# leaves the ground restarts the timer for free, so retry until one stays
	# grounded, then verify the lock lands 500ms after the last reset.
	var at_cap := false
	guard = 0
	while not at_cap and guard < 20:
		guard += 1
		s.tick(300)
		t.check(s.rotate_cw(), "rotation at cap %d" % guard)
		at_cap = s.is_grounded()
		_sink(s)
	t.check_eq(s.lock_resets, 15, "not counted at cap")
	s.tick(199)
	t.check(s.active == piece, "alive at 499ms")
	s.tick(1)
	t.check(s.active != piece, "locks despite rotating")


func test_airborne_rotation_costs_no_reset() -> void:
	var s := _session(Tetromino.Type.T, 0, Vector2i(3, 25))
	s.rotate_cw()
	t.check_eq(s.lock_resets, 0, "no reset while airborne")


func test_failed_rotation_does_not_reset_timer() -> void:
	var s := _session(Tetromino.Type.T, 0, Vector2i(3, 38))
	_fill_around_piece(s, 0)  # hole so locking can't clear 40 rows
	var piece := s.active
	s.tick(400)
	t.check(not s.rotate_cw(), "blocked")
	t.check_eq(s.lock_resets, 0, "no reset")
	s.tick(100)
	t.check(s.active != piece, "locks on schedule")


func test_o_rotation_does_not_reset_timer() -> void:
	var s := _session(Tetromino.Type.O, 0, Vector2i(3, 38))
	var piece := s.active
	s.tick(400)
	s.rotate_cw()
	t.check_eq(s.lock_resets, 0, "no reset")
	s.tick(100)
	t.check(s.active != piece, "locks on schedule")


# --- regressions ----------------------------------------------------------

func test_commands_ignored_after_game_over() -> void:
	var s := _session(Tetromino.Type.T, 0, Vector2i(3, 25))
	s.game_over = true
	t.check(not s.rotate_cw(), "no rotation after game over")


func test_horizontal_movement_uses_rotated_shape() -> void:
	# Vertical I (R) occupies one column; it can reach the right wall.
	var s := _session(Tetromino.Type.I, 1, Vector2i(3, 25))
	for i in range(10):
		s.set_direction(0)
		s.set_direction(1)
	t.check_eq(s.active.origin.x, 7, "column 9 reached, not beyond")


func test_hard_drop_after_rotation_locks_rotated_cells() -> void:
	var s := _session(Tetromino.Type.I, 1, Vector2i(3, 10))
	s.hard_drop()
	for y in range(36, 40):
		t.check_eq(s.board.get_cell(5, y), Tetromino.Type.I, "column 5 row %d" % y)


func test_input_actions_exist() -> void:
	for action in ["rotate_cw", "rotate_ccw"]:
		t.check(InputMap.has_action(action), action + " defined")
		t.check(not InputMap.action_get_events(action).is_empty(), action + " has a binding")
