extends RefCounted

var t: Object


func _session() -> GameSession:
	var s := GameSession.new(4, true)
	s.spawn_next()
	return s


func test_pause_freezes_time() -> void:
	var s := _session()
	var y0 := s.active.origin.y
	s.pause()
	s.tick(5000)
	t.check_eq(s.active.origin.y, y0, "no gravity while paused")
	s.resume()
	s.tick(1000)
	t.check_eq(s.active.origin.y, y0 + 1, "gravity resumes")


func test_pause_ignores_commands() -> void:
	var s := _session()
	var piece := s.active
	var origin := s.active.origin
	s.pause()
	s.set_direction(1)
	s.rotate_cw()
	t.check(not s.hold(), "hold refused")
	s.hard_drop()
	t.check(s.active == piece, "piece untouched")
	t.check_eq(s.active.origin, origin, "not moved")
	t.check_eq(s.active.rotation, 0, "not rotated")
	t.check_eq(s.stats.score, 0, "no score")
	t.check_eq(s.held_type, 0, "nothing held")


func test_lock_timer_does_not_advance_while_paused() -> void:
	var s := _session()
	s.active.origin.y = Board.TOTAL_ROWS - 2
	var piece := s.active
	s.tick(400)
	s.pause()
	s.tick(10000)
	s.resume()
	t.check(s.active == piece, "still alive after a long pause")
	s.tick(99)
	t.check(s.active == piece, "100ms of lock delay still left")
	s.tick(1)
	t.check(s.active != piece, "locks on schedule")


func test_held_direction_survives_pause() -> void:
	var s := _session()
	s.pause()
	s.set_direction(-1)  # finger went down while paused: remembered, no move
	var x := s.active.origin.x
	s.resume()
	s.tick(500)
	t.check(s.active.origin.x < x, "movement repeats after resume")


func test_cannot_pause_after_game_over() -> void:
	var s := _session()
	s.game_over = true
	s.pause()
	t.check(not s.paused, "game over is not pausable")


func test_restart_clears_pause() -> void:
	var s := _session()
	s.pause()
	s.restart(4, true)
	t.check(not s.paused, "unpaused")
	t.check(s.active != null, "playing")


func test_pause_action_bound() -> void:
	t.check(InputMap.has_action("pause"), "pause action")
	t.check(not InputMap.action_get_events("pause").is_empty(), "pause bound")
