extends RefCounted

var t: Object


## Session with a fixed active piece on an empty board.
func _session(type: int = Tetromino.Type.O) -> GameSession:
	var s := GameSession.new(1, true)
	s.spawn_next()
	s.active = ActivePiece.new(type)
	return s


## O piece resting on the floor (rows 38-39).
func _grounded_o() -> GameSession:
	var s := _session()
	s.active.origin.y = Board.TOTAL_ROWS - 2
	return s


func _min_x(s: GameSession) -> int:
	var m := 99
	for c in s.active.cells():
		m = mini(m, c.x)
	return m


func test_gravity_interval() -> void:
	var s := _session()
	var y0 := s.active.origin.y
	s.tick(999)
	t.check_eq(s.active.origin.y, y0, "no fall before interval")
	s.tick(1)
	t.check_eq(s.active.origin.y, y0 + 1, "falls one row at interval")


func test_gravity_is_frame_rate_independent() -> void:
	var results: Array[int] = []
	for step in [1, 7, 16, 17, 33, 1000]:
		var s := _session()
		var elapsed := 0
		while elapsed < 5000:
			s.tick(step)
			elapsed += step
		results.append(s.active.origin.y)
	for r in results:
		t.check_eq(r, results[0], "same row after 5s at any step size")
	t.check_eq(results[0], Tetromino.spawn_origin().y + 5, "five rows in five seconds")


func test_large_tick_falls_multiple_rows() -> void:
	var s := _session()
	s.tick(3000)
	t.check_eq(s.active.origin.y, Tetromino.spawn_origin().y + 3, "three rows")


func test_soft_drop_is_faster() -> void:
	var s := _session()
	var y0 := s.active.origin.y
	s.set_soft_drop(true)
	s.tick(500)
	t.check_eq(s.active.origin.y, y0 + GameSession.SOFT_DROP_FACTOR / 2, "20 rows/s")
	s.set_soft_drop(false)
	var before := s.active.origin.y
	s.tick(999)
	t.check_eq(s.active.origin.y, before, "back to normal gravity")


func test_walls_stop_horizontal_movement() -> void:
	var s := _session()
	for i in range(20):
		s.set_direction(0)
		s.set_direction(-1)
	t.check_eq(_min_x(s), 0, "stopped at left wall")
	for i in range(20):
		s.set_direction(0)
		s.set_direction(1)
	t.check_eq(_min_x(s) + 1, Board.WIDTH - 1, "stopped at right wall")


func test_locked_cells_block_horizontal_movement() -> void:
	var s := _session()
	s.board.set_cell(2, 19, 1)
	s.board.set_cell(2, 20, 1)
	for i in range(5):
		s.set_direction(0)
		s.set_direction(-1)
	t.check_eq(_min_x(s), 3, "blocked by locked cells")


func test_piece_stops_on_stack() -> void:
	var s := _session()
	var piece := s.active
	s.board.set_cell(4, 30, 1)
	var guard := 0
	while s.active == piece and guard < 100:
		s.tick(100)
		guard += 1
	t.check_eq(s.board.get_cell(4, 29), Tetromino.Type.O, "O locked on top of stack")
	t.check_eq(s.board.get_cell(4, 30), 1, "stack untouched")


func test_hard_drop_locks_at_lowest_position() -> void:
	var s := _session()
	var next_type: int = s.queue[0]
	s.hard_drop()
	for x in [4, 5]:
		t.check_eq(s.board.get_cell(x, 38), Tetromino.Type.O, "bottom row locked")
		t.check_eq(s.board.get_cell(x, 39), Tetromino.Type.O, "floor row locked")
	t.check_eq(s.active.type, next_type, "next piece spawned")
	t.check_eq(s.active.origin, Tetromino.spawn_origin(), "at spawn")


func test_hard_drop_lands_on_stack() -> void:
	var s := _session()
	s.board.set_cell(4, 30, 1)
	s.hard_drop()
	t.check_eq(s.board.get_cell(4, 29), Tetromino.Type.O, "above stack")
	t.check_eq(s.board.get_cell(5, 28), Tetromino.Type.O, "two rows tall")
	t.check_eq(s.board.get_cell(5, 29), Tetromino.Type.O, "both columns")


func test_lock_delay_500ms() -> void:
	var s := _grounded_o()
	var piece := s.active
	s.tick(499)
	t.check(s.active == piece, "still active at 499ms")
	s.tick(1)
	t.check(s.active != piece, "locked at 500ms")
	t.check_eq(s.board.get_cell(4, 39), Tetromino.Type.O, "cells written to board")


func test_lock_timer_starts_on_landing() -> void:
	var s := _session()
	s.active.origin.y = Board.TOTAL_ROWS - 3  # one row above resting
	var piece := s.active
	s.tick(1000)  # falls and lands
	t.check(s.is_grounded(), "grounded")
	s.tick(499)
	t.check(s.active == piece, "timer counts from landing")
	s.tick(1)
	t.check(s.active != piece, "locks 500ms after landing")


func test_move_resets_lock_timer() -> void:
	var s := _grounded_o()
	var piece := s.active
	s.tick(400)
	s.set_direction(-1)
	t.check_eq(s.lock_resets, 1, "reset counted")
	s.tick(400)
	t.check(s.active == piece, "timer was reset by the move")
	s.tick(100)
	t.check(s.active != piece, "locks 500ms after the move")


func _nudge(s: GameSession, direction: int) -> void:
	s.set_direction(direction)
	s.set_direction(0)


func test_reset_cap_is_15() -> void:
	var s := _grounded_o()
	var piece := s.active
	for i in range(GameSession.MAX_LOCK_RESETS):
		s.tick(400)
		_nudge(s, -1 if i % 2 == 0 else 1)
	t.check_eq(s.lock_resets, 15, "15 resets used")
	t.check(s.active == piece, "still alive")
	s.tick(300)
	_nudge(s, 1)
	t.check_eq(s.lock_resets, 15, "16th move does not count")
	s.tick(199)
	t.check(s.active == piece, "no reset at cap: 499ms")
	s.tick(1)
	t.check(s.active != piece, "locks despite moving")


func test_airborne_moves_do_not_use_resets() -> void:
	var s := _session()
	s.set_direction(-1)
	s.set_direction(1)
	t.check_eq(s.lock_resets, 0, "no resets while airborne")


func test_das_and_arr() -> void:
	var s := _session()
	s.das_ms = 100
	s.arr_ms = 50
	s.set_direction(1)
	t.check_eq(_min_x(s), 5, "immediate first move")
	s.tick(99)
	t.check_eq(_min_x(s), 5, "waiting for DAS")
	s.tick(1)
	t.check_eq(_min_x(s), 6, "first repeat at DAS")
	s.tick(49)
	t.check_eq(_min_x(s), 6, "waiting for ARR")
	s.tick(1)
	t.check_eq(_min_x(s), 7, "repeat each ARR")
	s.tick(50)
	t.check_eq(_min_x(s), 8, "next repeat")


func test_das_is_frame_rate_independent() -> void:
	var results: Array[int] = []
	for step in [1, 5, 10, 33]:
		var s := _session()
		s.das_ms = 100
		s.arr_ms = 50
		s.set_direction(-1)
		for i in range(300 / step):
			s.tick(step)
		results.append(_min_x(s))
	t.check_eq(results[0], results[1], "1ms vs 5ms")
	t.check_eq(results[0], results[2], "1ms vs 10ms")


func test_arr_zero_slides_to_wall() -> void:
	var s := _session()
	s.das_ms = 100
	s.arr_ms = 0
	s.set_direction(-1)
	s.tick(100)
	t.check_eq(_min_x(s), 0, "at wall")


func test_release_stops_repeat() -> void:
	var s := _session()
	s.das_ms = 100
	s.arr_ms = 50
	s.set_direction(1)
	s.tick(100)
	s.set_direction(0)
	var x := _min_x(s)
	s.tick(500)
	t.check_eq(_min_x(s), x, "no movement after release")


func test_sequential_spawning_follows_queue() -> void:
	var s := GameSession.new(11, true)
	s.spawn_next()
	for i in range(8):
		var expected: int = s.queue[0]
		s.hard_drop()
		if s.game_over:
			break
		t.check_eq(s.active.type, expected, "piece %d from queue" % i)
		t.check_eq(s.queue.size(), GameSession.PREVIEW_COUNT, "queue full")


func test_stacking_to_the_top_ends_game() -> void:
	var s := GameSession.new(3, true)
	s.spawn_next()
	for i in range(60):
		s.hard_drop()
	t.check(s.game_over, "game over when spawn blocked")
	t.check(s.active == null, "no active piece")
	s.tick(1000)
	s.hard_drop()
	t.check(s.active == null, "commands ignored after game over")


func test_input_actions_exist() -> void:
	for action in ["move_left", "move_right", "soft_drop", "hard_drop"]:
		t.check(InputMap.has_action(action), action + " defined")
		t.check(not InputMap.action_get_events(action).is_empty(), action + " has a binding")
