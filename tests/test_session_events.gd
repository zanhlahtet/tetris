extends RefCounted
## Presentation events emitted by the session (used by sound and effects).

var t: Object

var _log: Array = []


func _session(type: int = Tetromino.Type.O, origin: Vector2i = Vector2i(3, 19)) -> GameSession:
	var s := GameSession.new(1, true)
	s.spawn_next()
	s.active = ActivePiece.new(type)
	s.active.origin = origin
	_log = []
	s.moved.connect(func() -> void: _log.append("moved"))
	s.rotated.connect(func() -> void: _log.append("rotated"))
	s.held.connect(func() -> void: _log.append("held"))
	s.hard_dropped.connect(func(cells: Array[Vector2i], distance: int) -> void: _log.append(["hard_dropped", distance, cells.size()]))
	s.locked.connect(func() -> void: _log.append("locked"))
	s.lines_cleared.connect(func(rows: Array[int]) -> void: _log.append(["lines_cleared", rows]))
	s.game_ended.connect(func() -> void: _log.append("game_ended"))
	return s


func test_move_and_rotate_events() -> void:
	var s := _session(Tetromino.Type.T)
	s.set_direction(1)
	s.set_direction(0)
	s.rotate_cw()
	t.check_eq(_log, ["moved", "rotated"], "one event each")


func test_blocked_actions_emit_nothing() -> void:
	var s := _session(Tetromino.Type.T, Vector2i(-1, 25))
	s.set_direction(-1)  # already at the left wall
	t.check(_log.is_empty(), "blocked move")
	for y in range(Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			if not s.active.cells().has(Vector2i(x, y)):
				s.board.set_cell(x, y, 1)
	s.rotate_cw()
	t.check(_log.is_empty(), "blocked rotation")
	s.pause()
	s.hard_drop()
	t.check(_log.is_empty(), "nothing while paused")


func test_o_rotation_is_silent() -> void:
	var s := _session(Tetromino.Type.O)
	s.rotate_cw()
	t.check(_log.is_empty(), "no visible change, no event")


func test_hold_event() -> void:
	var s := _session()
	s.hold()
	t.check_eq(_log, ["held"], "held once")
	s.hold()
	t.check_eq(_log, ["held"], "refused hold is silent")


func test_hard_drop_event_order() -> void:
	var s := _session()
	s.hard_drop()
	t.check_eq(_log, [["hard_dropped", Board.TOTAL_ROWS - 2 - 19, 4], "locked"], "drop reported before lock")


func test_natural_lock_emits_locked_only() -> void:
	var s := _session()
	s.active.origin.y = Board.TOTAL_ROWS - 2
	s.tick(500)
	t.check_eq(_log, ["locked"], "no hard-drop event")


func test_line_clear_event_carries_the_rows() -> void:
	var s := _session()
	for x in range(Board.WIDTH):
		if x != 4 and x != 5:
			s.board.set_cell(x, Board.TOTAL_ROWS - 2, 1)
			s.board.set_cell(x, Board.TOTAL_ROWS - 1, 1)
	s.board.set_cell(0, 30, 7)
	s.hard_drop()
	t.check_eq(_log, [["hard_dropped", Board.TOTAL_ROWS - 2 - 19, 4], "locked", ["lines_cleared", [Board.TOTAL_ROWS - 2, Board.TOTAL_ROWS - 1] as Array[int]]], "rows reported")


func test_game_ended_emitted_once() -> void:
	var s := _session(Tetromino.Type.O, Vector2i(3, 5))
	s.board.set_cell(4, 12, 1)
	s.hard_drop()  # lock-out
	t.check_eq(_log.count("game_ended"), 1, "lock-out")
	s.tick(1000)
	s.hard_drop()
	t.check_eq(_log.count("game_ended"), 1, "not repeated")


func test_block_out_emits_game_ended() -> void:
	var s := _session()
	for x in range(Board.WIDTH):
		s.board.set_cell(x, 19, 1)
		s.board.set_cell(x, 20, 1)
	s.spawn_next()
	t.check_eq(_log, ["game_ended"], "spawn blocked")


func test_restart_emits_no_stale_events() -> void:
	var s := _session()
	s.restart(1, true)
	t.check(_log.is_empty(), "restart is silent")
