extends RefCounted

var t: Object

const MIN_CELL: int = 30
const MIN_BUTTON_SIZE: float = 56.0


## Representative usable areas in viewport coordinates: base portrait, taller
## phones, tablets, ultra-wide windows, and phones with notch/home-bar insets.
func _safe_rects() -> Array[Rect2]:
	return [
		Rect2(0, 0, 720, 1280),
		Rect2(0, 0, 720, 1560),
		Rect2(0, 0, 720, 1700),
		Rect2(0, 0, 960, 1280),
		Rect2(0, 0, 1280, 1280),
		Rect2(0, 0, 2275, 1280),
		Rect2(0, 100, 720, 1110),
		Rect2(0, 130, 720, 1020),
		Rect2(40, 0, 640, 1280),
		Rect2(0, 60, 720, 1500),
	]


func _named_rects(l: GameLayout) -> Dictionary:
	var rects := {
		"board": l.board_rect, "hold": l.hold_rect, "stats": l.stats_rect,
		"next": l.next_rect, "pause": l.pause_rect, "award": l.award_rect,
	}
	for action: StringName in l.buttons:
		if action != &"pause":
			rects["btn_" + action] = l.buttons[action]
	return rects


func test_everything_inside_safe_area() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		var rects := _named_rects(l)
		rects["controls"] = l.controls_rect
		for name in rects:
			t.check(safe.encloses(rects[name]), "%s inside %s (%s)" % [name, safe, rects[name]])


func test_no_overlaps() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		var rects := _named_rects(l)
		var names := rects.keys()
		for i in range(names.size()):
			for j in range(i + 1, names.size()):
				t.check(not (rects[names[i]] as Rect2).intersects(rects[names[j]]),
						"%s vs %s overlap in %s" % [names[i], names[j], safe])


func test_board_is_the_visual_focus() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		t.check(l.cell_size >= MIN_CELL, "cell size %d in %s" % [l.cell_size, safe])
		t.check_eq(l.board_rect.size, Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * l.cell_size, "board is whole cells")
		var area := l.board_rect.get_area()
		for name in ["hold", "stats", "next", "pause"]:
			t.check(area > 4.0 * (_named_rects(l)[name] as Rect2).get_area(), "board dominates %s in %s" % [name, safe])


func test_base_resolution_cell_size() -> void:
	var l := GameLayout.compute(Rect2(0, 0, 720, 1280))
	t.check_eq(l.cell_size, 49, "49px cells at 720x1280")


func test_board_centered_horizontally() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		t.check(absf(l.board_rect.get_center().x - safe.get_center().x) < 0.5, "centred in %s" % safe)


func test_touch_targets_are_large_enough() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		for action: StringName in l.buttons:
			var size: Vector2 = (l.buttons[action] as Rect2).size
			t.check(size.x >= MIN_BUTTON_SIZE and size.y >= MIN_BUTTON_SIZE, "%s is %s in %s" % [action, size, safe])


func test_all_actions_have_buttons() -> void:
	var l := GameLayout.compute(Rect2(0, 0, 720, 1280))
	for action in [&"move_left", &"move_right", &"soft_drop", &"hard_drop", &"rotate_cw", &"rotate_ccw", &"hold", &"pause"]:
		t.check(l.buttons.has(action), "button for %s" % action)
		t.check(InputMap.has_action(action), "%s is an Input Map action" % action)


func test_controls_sit_below_the_board_and_split_by_hand() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		t.check(l.board_rect.end.y <= l.controls_rect.position.y, "board above controls in %s" % safe)
		t.check((l.buttons[&"move_right"] as Rect2).end.x <= (l.buttons[&"rotate_ccw"] as Rect2).position.x, "movement left of rotation")


func test_safe_area_conversion() -> void:
	# iPhone-like: 1170x2532 window, 141px top inset, 102px bottom inset.
	var window := Vector2(1170, 2532)
	var viewport := Vector2(720, 1558.15)
	var r := GameLayout.safe_rect_in_viewport(Rect2(0, 141, 1170, 2532 - 141 - 102), window, viewport)
	t.check(absf(r.position.y - 141.0 / 1.625) < 0.01, "top inset scaled")
	t.check(absf(r.size.x - 720.0) < 0.01, "full width")
	t.check(absf(r.end.y - (2532.0 - 102.0) / 1.625) < 0.01, "bottom inset scaled")


func test_safe_area_is_clipped_and_falls_back() -> void:
	var vp := Vector2(720, 1280)
	var clipped := GameLayout.safe_rect_in_viewport(Rect2(-50, -50, 2000, 3000), Vector2(720, 1280), vp)
	t.check_eq(clipped, Rect2(Vector2.ZERO, vp), "clipped to viewport")
	t.check_eq(GameLayout.safe_rect_in_viewport(Rect2(0, 0, 100, 100), Vector2.ZERO, vp), Rect2(Vector2.ZERO, vp), "zero window falls back")
	t.check_eq(GameLayout.safe_rect_in_viewport(Rect2(0, 0, 0, 0), Vector2(720, 1280), vp), Rect2(Vector2.ZERO, vp), "empty safe area falls back")
