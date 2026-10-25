extends RefCounted

var t: Object


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


## Hard-dropping an O from the spawn row to rows 38-39 moves it 19 cells.
const O_DROP_POINTS: int = 19 * 2


func test_single_line_clear() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))  # columns 4-5
	_fill_row(s, 39, [4, 5])
	s.board.set_cell(0, 38, 7)  # row above the clear, should fall
	s.hard_drop()
	# O covers rows 38-39; row 39 completes. Remaining: marker + O's top half.
	t.check_eq(s.stats.lines, 1, "one line")
	t.check_eq(s.stats.score, 100 + O_DROP_POINTS, "100 + hard drop")
	t.check_eq(s.board.get_cell(0, 39), 7, "marker fell")
	t.check_eq(s.board.get_cell(4, 39), Tetromino.Type.O, "O top half fell")
	t.check_eq(s.board.get_cell(5, 39), Tetromino.Type.O, "O top half fell")
	t.check_eq(s.board.get_cell(1, 39), Board.EMPTY, "rest of row empty")
	t.check(s.board.full_rows().is_empty(), "no full rows left")


func test_double_line_clear() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	_fill_row(s, 38, [4, 5])
	_fill_row(s, 39, [4, 5])
	s.hard_drop()
	t.check_eq(s.stats.lines, 2, "two lines")
	t.check_eq(s.stats.score, 300 + O_DROP_POINTS, "300 + hard drop")
	for x in range(Board.WIDTH):
		t.check_eq(s.board.get_cell(x, 39), Board.EMPTY, "board empty (col %d)" % x)


func test_triple_and_four_line_clears() -> void:
	for rows in [3, 4]:
		# Vertical I (state R) occupies column origin.x + 2: place it in column 0.
		var s := _session(Tetromino.Type.I, Vector2i(-2, 10), 1)
		for y in range(40 - rows, 40):
			_fill_row(s, y, [0])
		# 3 rows: the I's top block remains and falls onto the floor.
		s.hard_drop()
		var drop_cells := 40 - 4 - 10  # origin.y 10 -> 36
		t.check_eq(s.stats.lines, rows, "%d lines" % rows)
		t.check_eq(s.stats.score, (500 if rows == 3 else 800) + drop_cells * 2, "%d-line score" % rows)
		var leftover := 0 if rows == 4 else 1
		var count := 0
		for y in range(Board.TOTAL_ROWS):
			for x in range(Board.WIDTH):
				if s.board.get_cell(x, y) != Board.EMPTY:
					count += 1
		t.check_eq(count, leftover, "%d-line leftover blocks" % rows)


func test_clear_scored_at_current_level_and_gravity_follows() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	s.stats.lines = 9
	s.stats.level = 1
	_fill_row(s, 39, [4, 5])
	s.hard_drop()
	t.check_eq(s.stats.level, 2, "level up at 10 lines")
	t.check_eq(s.gravity_interval_ms(), 793, "gravity speeds up")
	# Next clear is paid at level 2.
	s.board.clear()
	_fill_row(s, 39, [4, 5])
	s.active = ActivePiece.new(Tetromino.Type.O)
	var before := s.stats.score
	s.hard_drop()
	t.check_eq(s.stats.score - before, 100 * 2 + O_DROP_POINTS, "level-2 multiplier")


func test_gravity_uses_level() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	s.stats.level = 2
	var y0 := s.active.origin.y
	s.tick(792)
	t.check_eq(s.active.origin.y, y0, "not yet at 793")
	s.tick(1)
	t.check_eq(s.active.origin.y, y0 + 1, "falls at 793")


func test_soft_drop_scores_per_cell() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	s.set_soft_drop(true)
	s.tick(500)  # 50ms per row at level 1 -> 10 rows
	t.check_eq(s.stats.score, 10, "10 cells = 10 points")
	s.set_soft_drop(false)
	s.tick(1000)
	t.check_eq(s.stats.score, 10, "gravity fall scores nothing")


func test_hard_drop_scores_distance() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 19))
	s.hard_drop()
	t.check_eq(s.stats.score, O_DROP_POINTS, "2 per cell")


func test_lock_out_above_visible_rows() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 5))
	s.board.set_cell(4, 12, 1)  # support in the hidden rows
	s.hard_drop()
	# O rests on rows 10-11: entirely hidden.
	t.check(s.game_over, "lock-out ends the game")
	t.check(s.active == null, "no next piece")
	t.check_eq(s.board.get_cell(4, 11), Tetromino.Type.O, "piece still written to board")


func test_locking_partly_visible_is_not_lock_out() -> void:
	# O in columns 0-1 resting on rows 19-20: one row hidden, one visible.
	var s := _session(Tetromino.Type.O, Vector2i(-1, 5))
	s.board.set_cell(0, 21, 1)
	s.board.set_cell(1, 21, 1)
	s.hard_drop()
	t.check_eq(s.board.get_cell(0, 19), Tetromino.Type.O, "locked in the hidden row")
	t.check_eq(s.board.get_cell(0, 20), Tetromino.Type.O, "and the visible row")
	t.check(not s.game_over, "not lock-out")
	t.check(s.active != null, "next piece spawned")


func test_block_out_when_spawn_blocked() -> void:
	var s := GameSession.new(2, true)
	for x in range(Board.WIDTH):
		s.board.set_cell(x, 20, 1)
		s.board.set_cell(x, 19, 1)
	t.check(not s.spawn_next(), "spawn fails")
	t.check(s.game_over, "game over")


func test_game_over_freezes_session() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 5))
	s.board.set_cell(4, 12, 1)
	s.hard_drop()
	var score := s.stats.score
	s.tick(5000)
	s.hard_drop()
	s.rotate_cw()
	s.set_direction(1)
	t.check_eq(s.stats.score, score, "nothing changes")
	t.check(s.active == null, "still no piece")


func test_restart_resets_everything() -> void:
	var s := GameSession.new(5, true)
	s.spawn_next()
	s.das_ms = 99
	for i in range(40):
		s.hard_drop()
	t.check(s.game_over, "precondition: game over")
	s.stats.score = 1234
	s.stats.lines = 25
	s.stats.level = 3
	s.restart(5, true)
	var fresh := GameSession.new(5, true)
	fresh.spawn_next()
	t.check(not s.game_over, "not over")
	t.check_eq(s.stats.score, 0, "score")
	t.check_eq(s.stats.lines, 0, "lines")
	t.check_eq(s.stats.level, 1, "level")
	t.check_eq(s.lock_resets, 0, "lock resets")
	t.check_eq(s.gravity_interval_ms(), 1000, "gravity")
	t.check(s.active != null, "piece spawned")
	t.check_eq(s.active.type, fresh.active.type, "same seed, same first piece")
	t.check_eq(s.queue, fresh.queue, "same queue")
	t.check_eq(s.active.origin, Tetromino.spawn_origin(), "at spawn")
	t.check_eq(s.das_ms, 99, "tuning kept")
	for y in range(Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			if s.board.get_cell(x, y) != Board.EMPTY:
				t.check(false, "board not empty at (%d,%d)" % [x, y])
				return
	t.check(true)


func test_game_playable_after_restart() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 5))
	s.board.set_cell(4, 12, 1)
	s.hard_drop()
	t.check(s.game_over, "over")
	s.restart(9, true)
	var y0 := s.active.origin.y
	s.tick(1000)
	t.check_eq(s.active.origin.y, y0 + 1, "gravity runs again")
	s.hard_drop()
	t.check(s.stats.score > 0, "scoring works again")


func test_restart_clears_timers() -> void:
	var s := GameSession.new(4, true)
	s.spawn_next()
	s.tick(900)  # almost a gravity step
	s.restart(4, true)
	var y0 := s.active.origin.y
	s.tick(200)
	t.check_eq(s.active.origin.y, y0, "gravity accumulator was reset")


func test_restart_input_action_exists() -> void:
	t.check(InputMap.has_action("restart"), "restart defined")
	t.check(not InputMap.action_get_events("restart").is_empty(), "restart bound")
