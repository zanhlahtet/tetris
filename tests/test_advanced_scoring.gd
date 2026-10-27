extends RefCounted
## Session-level scoring: T-Spins, perfect clears, double-scoring guards and
## the interaction with rotation, movement, gravity, hold and lock delay.

var t: Object

## Last board row (the floor row).
const FLOOR: int = Board.TOTAL_ROWS - 1


func _session(type: int, origin: Vector2i, rotation: int = 0) -> GameSession:
	var s := GameSession.new(1, true)
	s.spawn_next()
	s.active = ActivePiece.new(type)
	s.active.rotation = rotation
	s.active.origin = origin
	return s


func _fill_row(s: GameSession, y: int, except: Array[int]) -> void:
	for x in range(Board.WIDTH):
		if not except.has(x):
			s.board.set_cell(x, y, 1)


## Classic T-Spin Double slot, FLOOR-relative. T (nub down) fills
## (3..5, FLOOR-2) and (4, FLOOR-1): row FLOOR-2 is full except 3-5, row FLOOR-1
## is full except 4, an overhang at (3, FLOOR-3) provides the third corner, and
## the FLOOR row (minus column 0, so it never clears) is the floor. The T starts
## pointing left and rotates counter-clockwise (L -> 2) into the slot.
func _tsd_setup() -> GameSession:
	var s := _session(Tetromino.Type.T, Vector2i(3, FLOOR - 3), 3)
	_fill_row(s, FLOOR - 2, [3, 4, 5])
	_fill_row(s, FLOOR - 1, [4])
	_fill_row(s, FLOOR, [0])
	s.board.set_cell(3, FLOOR - 3, 1)
	return s


## Mini setup, no lines: T pointing right rotates counter-clockwise to point up
## with corners (3,30), (3,32) and (5,32) filled -> one front, both back.
func _mini_setup() -> GameSession:
	var s := _session(Tetromino.Type.T, Vector2i(3, 30), 1)
	s.board.set_cell(3, 30, 1)
	s.board.set_cell(3, 32, 1)
	s.board.set_cell(5, 32, 1)
	return s


func test_t_spin_double_by_hard_drop() -> void:
	var s := _tsd_setup()
	t.check(s.rotate_ccw(), "slot rotation")
	t.check(s.active.spun, "rotation recorded")
	s.hard_drop()  # already resting: no fall, so the spin counts
	t.check_eq(s.stats.lines, 2, "two lines")
	t.check_eq(s.stats.score, 1200, "T-Spin Double, no drop points")
	t.check_eq(s.last_lock.spin, TSpin.Kind.FULL, "full T-Spin")
	t.check_eq(s.last_lock.describe(), "T-SPIN DOUBLE", "label")


func test_t_spin_double_by_lock_delay() -> void:
	var s := _tsd_setup()
	t.check(s.rotate_ccw(), "slot rotation")
	t.check_eq(s.lock_resets, 1, "grounded rotation used a reset")
	s.tick(499)
	t.check_eq(s.stats.score, 0, "not locked yet")
	s.tick(1)
	t.check_eq(s.stats.score, 1200, "scored when the lock delay expired")
	t.check_eq(s.stats.lines, 2, "two lines")


func test_t_spin_is_scored_exactly_once() -> void:
	var s := _tsd_setup()
	s.rotate_ccw()
	s.hard_drop()
	var score := s.stats.score
	var lock := s.last_lock
	s.tick(5000)  # the next piece falls and (maybe) locks, but nothing re-scores
	t.check_eq(s.stats.score, score, "no further points")
	t.check(s.last_lock == lock, "no second lock event")
	t.check_eq(s.stats.lines, 2, "lines counted once")


func test_t_spin_mini_without_lines() -> void:
	var s := _mini_setup()
	t.check(s.rotate_ccw(), "rotates")
	t.check_eq(s.active.rotation, 0, "pointing up")
	s.hard_drop()
	t.check_eq(s.last_lock.spin, TSpin.Kind.MINI, "mini")
	t.check_eq(s.stats.score, 100, "T-Spin Mini, no lines")
	t.check_eq(s.last_lock.describe(), "T-SPIN MINI", "label")


func test_moving_after_rotation_cancels_the_spin() -> void:
	var s := _mini_setup()
	s.rotate_ccw()
	s.set_direction(1)
	s.set_direction(0)
	t.check(not s.active.spun, "horizontal move clears the flag")
	s.set_direction(-1)
	s.set_direction(0)  # back in the same place
	s.hard_drop()
	t.check_eq(s.last_lock.spin, TSpin.Kind.NONE, "no spin")
	t.check_eq(s.stats.score, 0, "nothing scored")


func test_falling_after_rotation_cancels_the_spin() -> void:
	var s := _session(Tetromino.Type.T, Vector2i(3, 20), 0)
	s.rotate_cw()
	t.check(s.active.spun, "rotated")
	s.tick(1000)  # gravity step
	t.check(not s.active.spun, "gravity step clears the flag")


func test_hard_drop_with_distance_is_not_a_t_spin() -> void:
	# Three corners filled on the left and top-right so the T can still fall.
	var s := _session(Tetromino.Type.T, Vector2i(3, 30), 0)
	for cell in [Vector2i(3, 30), Vector2i(3, 32), Vector2i(5, 30)]:
		s.board.set_cell(cell.x, cell.y, 1)
	t.check(s.rotate_cw(), "rotates to point right")
	t.check_eq(TSpin.detect(s.board, s.active), TSpin.Kind.MINI, "would be a mini where it stands")
	s.hard_drop()
	t.check_eq(s.last_lock.spin, TSpin.Kind.NONE, "falling after the rotation voids it")
	t.check_eq(s.last_lock.points, 0, "lock itself scored nothing")
	t.check(s.stats.score > 0 and s.stats.score % 2 == 0, "only hard-drop points")


func test_soft_drop_after_rotation_cancels_the_spin() -> void:
	var s := _session(Tetromino.Type.T, Vector2i(3, 20), 0)
	s.rotate_cw()
	s.set_soft_drop(true)
	s.tick(50)
	t.check(not s.active.spun, "soft drop clears the flag")


func test_hold_resets_spin_state() -> void:
	var s := _mini_setup()
	s.rotate_ccw()
	t.check(s.active.spun, "spun")
	s.hold()
	t.check(not s.active.spun, "fresh piece after hold")
	# Swap back: the T returns un-spun and in canonical orientation.
	s.hard_drop()
	s.hold()
	t.check(not s.active.spun, "swapped-in piece is fresh")
	t.check_eq(s.active.kick_index, 0, "kick index reset")


func test_kick_index_is_recorded() -> void:
	var plain := _session(Tetromino.Type.T, Vector2i(3, 25), 0)
	plain.rotate_cw()
	t.check_eq(plain.active.kick_index, 0, "plain rotation")
	# T pointing right at the left wall rotating ccw needs the second test.
	var wall := _session(Tetromino.Type.T, Vector2i(-1, 25), 1)
	wall.rotate_ccw()
	t.check_eq(wall.active.kick_index, 1, "wall kick")
	# Force the fifth test by blocking the candidates of tests 1-3.
	var s := _session(Tetromino.Type.T, Vector2i(3, 25), 0)
	var probe := ActivePiece.new(Tetromino.Type.T)
	var offsets := Srs.kick_offsets(Tetromino.Type.T, 0, 1)
	var current := probe.cells_at(Vector2i(3, 25), 0)
	var fifth := probe.cells_at(Vector2i(3, 25) + offsets[4], 1)
	for k in range(3):
		for cell: Vector2i in probe.cells_at(Vector2i(3, 25) + offsets[k], 1):
			if not current.has(cell) and not fifth.has(cell):
				s.board.set_cell(cell.x, cell.y, 1)
				break
	# Test 4 shares its top block with test 1, so it is blocked as well.
	t.check(s.rotate_cw(), "rotation succeeds")
	t.check_eq(s.active.kick_index, 4, "fifth test used")


func test_no_t_spin_for_other_pieces() -> void:
	var s := _session(Tetromino.Type.S, Vector2i(3, FLOOR - 3), 0)
	_fill_row(s, FLOOR, [0])
	for cell in [Vector2i(3, FLOOR - 3), Vector2i(5, FLOOR - 3), Vector2i(3, FLOOR - 1), Vector2i(5, FLOOR - 1)]:
		s.board.set_cell(cell.x, cell.y, 1)
	s.rotate_cw()
	s.hard_drop()
	t.check_eq(s.last_lock.spin, TSpin.Kind.NONE, "S is never a T-Spin")


func test_perfect_clear_double() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	for y in [FLOOR - 1, FLOOR]:
		_fill_row(s, y, [4, 5])
	s.hard_drop()
	t.check(s.board.is_clear(), "board empty")
	t.check(s.last_lock.perfect_clear, "perfect clear flagged")
	t.check_eq(s.stats.score, 300 + 1200 + (FLOOR - 1 - 19) * 2, "double + PC bonus + hard drop")
	t.check_eq(s.last_lock.describe(), "DOUBLE\nPERFECT CLEAR", "label")


func test_clear_with_blocks_left_is_not_perfect() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	for y in [FLOOR - 1, FLOOR]:
		_fill_row(s, y, [4, 5])
	s.board.set_cell(0, 30, 3)
	s.hard_drop()
	t.check(not s.last_lock.perfect_clear, "stray block")
	t.check_eq(s.stats.score, 300 + (FLOOR - 1 - 19) * 2, "no bonus")


func test_perfect_clear_counts_hidden_rows() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	for y in [FLOOR - 1, FLOOR]:
		_fill_row(s, y, [4, 5])
	s.board.set_cell(0, 3, 3)  # block in the hidden buffer
	s.hard_drop()
	t.check(not s.last_lock.perfect_clear, "hidden block prevents a perfect clear")


func test_back_to_back_and_combo_through_the_session() -> void:
	# Two consecutive I-piece Tetrises: 800, then 1200 (B2B) + 50 (combo 1) plus drops.
	var s := _session(Tetromino.Type.I, Vector2i(-2, 10), 1)
	for y in range(FLOOR - 3, FLOOR + 1):
		_fill_row(s, y, [0])
	s.board.set_cell(9, 20, 7)
	s.hard_drop()
	var first := s.stats.score
	t.check_eq(first, 800 + (FLOOR - 3 - 10) * 2, "first Tetris")
	s.active = ActivePiece.new(Tetromino.Type.I)
	s.active.rotation = 1
	s.active.origin = Vector2i(-2, 10)
	for y in range(FLOOR - 3, FLOOR + 1):
		_fill_row(s, y, [0])
	s.hard_drop()
	t.check_eq(s.stats.score - first, 1200 + 50 + (FLOOR - 3 - 10) * 2 - 0, "second Tetris: B2B + combo")
	t.check(s.last_lock.back_to_back_applied, "flag")
	t.check_eq(s.last_lock.combo, 1, "combo 1")


func test_lock_without_clear_resets_combo_in_session() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	_fill_row(s, FLOOR, [4, 5])
	s.board.set_cell(0, 30, 3)
	s.hard_drop()  # clear
	t.check_eq(s.stats.combo, 0, "combo started")
	s.active = ActivePiece.new(Tetromino.Type.O)
	s.hard_drop()  # lands on the stack, no clear
	t.check_eq(s.stats.combo, -1, "reset by a lock without a clear")


func test_restart_clears_chains_and_last_lock() -> void:
	var s := _tsd_setup()
	s.rotate_ccw()
	s.hard_drop()
	t.check(s.stats.back_to_back, "chain running")
	s.restart(1, true)
	t.check(s.last_lock == null, "no last lock")
	t.check(not s.stats.back_to_back, "B2B cleared")
	t.check_eq(s.stats.combo, -1, "combo cleared")


func test_lock_out_scores_nothing() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 5))
	s.board.set_cell(4, 12, 1)
	s.hard_drop()
	t.check(s.game_over, "lock-out")
	t.check(s.last_lock == null, "no scoring event for a lock-out")
