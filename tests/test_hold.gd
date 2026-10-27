extends RefCounted

var t: Object


func _started(seed_value: int = 21) -> GameSession:
	var s := GameSession.new(seed_value, true)
	s.spawn_next()
	return s


## Blocks every spawn position (rows 19-20) with locked cells.
func _block_spawn_area(s: GameSession) -> void:
	for x in range(Board.WIDTH):
		s.board.set_cell(x, 19, 1)
		s.board.set_cell(x, 20, 1)


func test_preview_shows_five_in_bag_order() -> void:
	var s := GameSession.new(8, true)
	t.check_eq(GameSession.PREVIEW_COUNT, 5, "five previews")
	t.check_eq(s.queue.size(), 5, "queue holds five")
	var reference := BagRandomizer.new(8, false)
	var expected: Array[int] = []
	for i in range(5):
		expected.append(reference.next())
	t.check_eq(s.queue, expected, "queue is the bag's first five")


func test_queue_order_across_spawns() -> void:
	var s := GameSession.new(8, true)
	var reference := BagRandomizer.new(8, false)
	for i in range(20):
		s.spawn_next()
		t.check_eq(s.active.type, reference.next(), "piece %d" % i)
		t.check_eq(s.queue.size(), 5, "queue stays full")


func test_hold_into_empty_slot_consumes_queue() -> void:
	var s := _started()
	var first := s.active.type
	var q := s.queue.duplicate()
	t.check_eq(s.held_type, 0, "slot starts empty")
	t.check(s.hold(), "hold succeeds")
	t.check_eq(s.held_type, first, "piece is held")
	t.check_eq(s.active.type, q[0], "next queued piece is active")
	t.check_eq(s.queue.slice(0, 4), q.slice(1, 5), "queue advanced by one")
	t.check_eq(s.queue.size(), 5, "queue refilled")


func test_hold_only_once_per_piece() -> void:
	var s := _started()
	s.hold()
	var active := s.active
	var held := s.held_type
	var q := s.queue.duplicate()
	t.check(not s.hold(), "second hold refused")
	t.check(s.active == active, "active unchanged")
	t.check_eq(s.held_type, held, "hold unchanged")
	t.check_eq(s.queue, q, "queue unchanged")


func test_hold_available_again_after_lock() -> void:
	var s := _started()
	s.hold()
	s.hard_drop()
	t.check(not s.hold_used, "flag cleared by lock")
	t.check(s.hold(), "hold works for the next piece")


func test_swap_does_not_consume_queue() -> void:
	var s := _started()
	var a := s.active.type
	s.hold()  # a held
	s.hard_drop()  # active piece locks; a new one spawns
	var c := s.active.type
	var q := s.queue.duplicate()
	t.check(s.hold(), "swap")
	t.check_eq(s.active.type, a, "held piece comes back")
	t.check_eq(s.held_type, c, "previous active is now held")
	t.check_eq(s.queue, q, "queue untouched by swap")


func test_swap_back_and_forth_only_after_locks() -> void:
	var s := _started()
	var a := s.active.type
	s.hold()
	s.hard_drop()
	s.hold()  # active is a, held is the piece spawned after b
	t.check_eq(s.active.type, a, "a returns")
	t.check(not s.hold(), "no immediate second swap")


func test_held_piece_respawns_in_canonical_orientation_and_position() -> void:
	for path in ["empty", "swap"]:
		var s := _started()
		if path == "swap":
			s.hold()
			s.hard_drop()
		# Disturb the active piece: rotate, shift, and let it fall.
		s.rotate_cw()
		s.set_direction(-1)
		s.set_direction(0)
		s.tick(2500)
		s.hold()
		t.check_eq(s.active.rotation, 0, path + ": rotation reset")
		t.check_eq(s.active.origin, Tetromino.spawn_origin(), path + ": position reset")


func test_hold_resets_piece_timers() -> void:
	var s := _started()
	s.tick(900)  # almost a gravity step
	s.hold()
	var y0 := s.active.origin.y
	s.tick(200)
	t.check_eq(s.active.origin.y, y0, "gravity accumulator reset")
	t.check_eq(s.lock_resets, 0, "lock resets cleared")


func test_hold_into_empty_slot_blocked_spawn_is_top_out() -> void:
	var s := _started()
	s.active.origin.y = 5  # park the active piece above the blockers
	_block_spawn_area(s)
	t.check(s.hold(), "hold itself is allowed")
	t.check(s.game_over, "game over")
	t.check(s.active == null, "no active piece")


func test_swap_blocked_spawn_is_top_out() -> void:
	var s := _started()
	s.hold()
	s.hard_drop()
	s.active.origin.y = 5
	_block_spawn_area(s)
	var held := s.held_type
	t.check(s.hold(), "swap attempted")
	t.check(s.game_over, "game over when the swapped piece cannot spawn")
	t.check(s.active == null, "no active piece")
	t.check(held != 0, "a piece was held")


func test_hold_ignored_after_game_over() -> void:
	var s := _started()
	s.game_over = true
	t.check(not s.hold(), "refused")


func test_restart_clears_hold() -> void:
	var s := _started()
	s.hold()
	s.restart(21, true)
	t.check_eq(s.held_type, 0, "slot empty")
	t.check(not s.hold_used, "hold available")


func test_hold_action_bound() -> void:
	for action in ["hold", "toggle_ghost"]:
		t.check(InputMap.has_action(action), action + " defined")
		t.check(not InputMap.action_get_events(action).is_empty(), action + " bound")


# --- ghost ------------------------------------------------------------

func _with(type: int, origin: Vector2i, rotation: int = 0) -> GameSession:
	var s := _started()
	s.active = ActivePiece.new(type)
	s.active.origin = origin
	s.active.rotation = rotation
	return s


func test_ghost_lands_on_floor() -> void:
	var s := _with(Tetromino.Type.O, Vector2i(3, 19))
	var ghost := s.ghost_cells()
	var ys: Array[int] = []
	for c in ghost:
		ys.append(c.y)
	ys.sort()
	var floor_y: int = Board.TOTAL_ROWS - 1
	t.check_eq(ys, [floor_y - 1, floor_y - 1, floor_y, floor_y] as Array[int], "O ghost on floor rows")


func test_ghost_lands_on_stack() -> void:
	var s := _with(Tetromino.Type.O, Vector2i(3, 19))
	s.board.set_cell(5, 30, 1)
	var ghost := s.ghost_cells()
	t.check(ghost.has(Vector2i(4, 28)) and ghost.has(Vector2i(5, 29)), "rests above the stack")


func test_ghost_matches_hard_drop_for_every_piece_and_rotation() -> void:
	for type in Tetromino.ALL_TYPES:
		for rotation in range(4):
			var s := _with(type, Vector2i(3, 19), rotation)
			s.board.set_cell(2, 33, 1)
			s.board.set_cell(6, 36, 1)
			if not s.board.can_place(s.active.cells()):
				continue
			var ghost := s.ghost_cells()
			s.hard_drop()
			for c in ghost:
				if s.board.get_cell(c.x, c.y) != type:
					t.check(false, "%s r%d ghost cell (%d,%d) not where it locked" % [Tetromino.type_name(type), rotation, c.x, c.y])
					return
	t.check(true)


func test_ghost_equals_active_when_grounded() -> void:
	var s := _with(Tetromino.Type.O, Vector2i(3, Board.TOTAL_ROWS - 2))
	t.check_eq(s.ghost_cells(), s.active.cells(), "already at the bottom")


func test_ghost_is_visual_only() -> void:
	var s := _with(Tetromino.Type.T, Vector2i(3, 19))
	var origin := s.active.origin
	var rotation := s.active.rotation
	s.ghost_cells()
	t.check_eq(s.active.origin, origin, "active not moved")
	t.check_eq(s.active.rotation, rotation, "rotation unchanged")
	for y in range(Board.TOTAL_ROWS):
		for x in range(Board.WIDTH):
			if s.board.get_cell(x, y) != Board.EMPTY:
				t.check(false, "board modified by ghost query")
				return
	# The ghost overlaps nothing that matters: the active piece moves through it.
	s.tick(1000)
	t.check_eq(s.active.origin.y, origin.y + 1, "gravity unaffected")
	t.check(true)


func test_ghost_empty_without_active_piece() -> void:
	var s := GameSession.new(1, true)
	t.check(s.ghost_cells().is_empty(), "no active piece")
