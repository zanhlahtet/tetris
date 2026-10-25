extends RefCounted

var t: Object


func test_queue_is_filled() -> void:
	var s := GameSession.new(5, true)
	t.check_eq(s.queue.size(), GameSession.PREVIEW_COUNT, "initial queue")
	t.check(s.active == null, "no active piece before spawn")


func test_spawn_consumes_queue_in_order() -> void:
	var s := GameSession.new(5, true)
	var expected_first: int = s.queue[0]
	var expected_second: int = s.queue[1]
	t.check(s.spawn_next(), "spawn succeeds")
	t.check_eq(s.active.type, expected_first, "active is old queue head")
	t.check_eq(s.queue[0], expected_second, "queue advanced")
	t.check_eq(s.queue.size(), GameSession.PREVIEW_COUNT, "queue refilled")


func test_seeded_sessions_match() -> void:
	var a := GameSession.new(99, true)
	var b := GameSession.new(99, true)
	for i in range(30):
		a.spawn_next()
		b.spawn_next()
		t.check_eq(a.active.type, b.active.type, "piece %d" % i)
		t.check_eq(a.queue, b.queue, "queue %d" % i)


func test_active_piece_is_separate_from_locked_cells() -> void:
	var s := GameSession.new(5, true)
	s.spawn_next()
	for y in range(Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			if s.board.get_cell(x, y) != Board.EMPTY:
				t.check(false, "board modified by spawn")
				return
	t.check(true)


func test_blocked_spawn_fails() -> void:
	var s := GameSession.new(5, true)
	for x in range(Board.WIDTH):
		s.board.set_cell(x, Board.HIDDEN_ROWS, 1)
	t.check(not s.spawn_next(), "spawn blocked")
	t.check(s.active == null, "no active piece")
