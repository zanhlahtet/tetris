extends RefCounted

var t: Object

var _layout: GameLayout
var _controls: TouchControls
var _log: Array = []


func _setup() -> void:
	_layout = GameLayout.compute(Rect2(0, 0, 720, 1280))
	_controls = TouchControls.new()
	_controls.set_layout(_layout)
	_log = []
	_controls.action_changed.connect(func(action: StringName, pressed: bool) -> void: _log.append([action, pressed]))


func _center(action: StringName) -> Vector2:
	return (_layout.buttons[action] as Rect2).get_center()


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	_controls._input(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	_controls._input(e)


func test_each_button_press_and_release() -> void:
	for action: StringName in _layout_actions():
		_setup()
		_touch(0, _center(action), true)
		t.check_eq(_log, [[action, true]], "%s pressed" % action)
		t.check(_controls.is_pressed(action), "%s reported held" % action)
		_touch(0, _center(action), false)
		t.check_eq(_log, [[action, true], [action, false]], "%s released" % action)
		t.check(not _controls.is_pressed(action), "%s no longer held" % action)


func _layout_actions() -> Array:
	return GameLayout.compute(Rect2(0, 0, 720, 1280)).buttons.keys()


func test_touch_outside_buttons_does_nothing() -> void:
	_setup()
	_touch(0, _layout.board_rect.get_center(), true)
	_touch(0, _layout.board_rect.get_center(), false)
	t.check(_log.is_empty(), "board is not a button")


func test_no_dead_zone_between_neighbours() -> void:
	_setup()
	var left: Rect2 = _layout.buttons[&"move_left"]
	var right: Rect2 = _layout.buttons[&"move_right"]
	var gap_point := Vector2((left.end.x + right.position.x) / 2.0, left.get_center().y)
	t.check(_controls.action_at(gap_point) != &"", "gap between buttons still hits one")


func test_simultaneous_touches() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_touch(1, _center(&"rotate_cw"), true)
	_touch(2, _center(&"soft_drop"), true)
	t.check_eq(_log, [[&"move_left", true], [&"rotate_cw", true], [&"soft_drop", true]], "three at once")
	_touch(1, _center(&"rotate_cw"), false)
	t.check(_controls.is_pressed(&"move_left") and _controls.is_pressed(&"soft_drop"), "others still held")
	t.check(not _controls.is_pressed(&"rotate_cw"), "rotate released")


func test_two_fingers_on_one_button() -> void:
	_setup()
	var p := _center(&"move_left")
	_touch(0, p, true)
	_touch(1, p, true)
	t.check_eq(_log, [[&"move_left", true]], "single press event")
	_touch(0, p, false)
	t.check(_controls.is_pressed(&"move_left"), "still held by the second finger")
	_touch(1, p, false)
	t.check_eq(_log, [[&"move_left", true], [&"move_left", false]], "released after the last finger")


func test_sliding_between_movement_buttons() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_drag(0, _center(&"move_left") + Vector2(2, 2))
	t.check_eq(_log.size(), 1, "small drag inside the button changes nothing")
	_drag(0, _center(&"move_right"))
	t.check_eq(_log, [[&"move_left", true], [&"move_left", false], [&"move_right", true]], "switches to right")
	_drag(0, _center(&"soft_drop"))
	t.check(_controls.is_pressed(&"soft_drop") and not _controls.is_pressed(&"move_right"), "then to soft drop")


func test_sliding_off_releases() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_drag(0, _layout.board_rect.get_center())
	t.check(not _controls.is_pressed(&"move_left"), "released when the finger leaves")
	_touch(0, _layout.board_rect.get_center(), false)
	t.check_eq(_log, [[&"move_left", true], [&"move_left", false]], "no extra events")


func test_sliding_onto_tap_buttons_does_not_press_them() -> void:
	_setup()
	_touch(0, _center(&"move_right"), true)
	_drag(0, _center(&"rotate_cw"))
	t.check(not _controls.is_pressed(&"rotate_cw"), "rotate not triggered by a slide")
	t.check(not _controls.is_pressed(&"move_right"), "movement released")


func test_tap_buttons_do_not_slide() -> void:
	_setup()
	_touch(0, _center(&"rotate_cw"), true)
	_drag(0, _center(&"move_left"))
	t.check(not _controls.is_pressed(&"move_left"), "no slide from a tap button")
	t.check(not _controls.is_pressed(&"rotate_cw"), "tap button released on leaving")


func test_drag_from_unknown_touch_ignored() -> void:
	_setup()
	_drag(5, _center(&"move_left"))
	t.check(_log.is_empty(), "drag without a press does nothing")


func test_disabling_releases_everything() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_touch(1, _center(&"soft_drop"), true)
	_controls.enabled = false
	t.check(not _controls.is_pressed(&"move_left") and not _controls.is_pressed(&"soft_drop"), "all released")
	t.check_eq(_log.size(), 4, "release events emitted so no key stays stuck")
	_log.clear()
	_touch(2, _center(&"hard_drop"), true)
	t.check(_log.is_empty(), "ignored while disabled")
	_controls.enabled = true
	_touch(2, _center(&"hard_drop"), true)
	t.check_eq(_log, [[&"hard_drop", true]], "works again when enabled")


func test_late_release_of_unknown_touch_is_harmless() -> void:
	_setup()
	_touch(3, _center(&"hold"), false)
	t.check(_log.is_empty(), "nothing to release")


# --- touch actions drive the same path as the keyboard -------------------

func _action_event(action: StringName, pressed: bool) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	return e


func test_action_events_reach_input_handler_signals() -> void:
	var h := InputHandler.new()
	var dirs: Array[int] = []
	var seen: Array[StringName] = []
	h.direction_changed.connect(func(d: int) -> void: dirs.append(d))
	h.hard_drop_pressed.connect(func() -> void: seen.append(&"hard_drop"))
	h.rotate_cw_pressed.connect(func() -> void: seen.append(&"rotate_cw"))
	h.rotate_ccw_pressed.connect(func() -> void: seen.append(&"rotate_ccw"))
	h.hold_pressed.connect(func() -> void: seen.append(&"hold"))
	h.pause_pressed.connect(func() -> void: seen.append(&"pause"))
	h._unhandled_input(_action_event(&"move_left", true))
	h._unhandled_input(_action_event(&"move_right", true))
	h._unhandled_input(_action_event(&"move_right", false))
	h._unhandled_input(_action_event(&"move_left", false))
	t.check_eq(dirs, [-1, 1, -1, 0] as Array[int], "latest direction wins, falls back on release")
	for a in [&"hard_drop", &"rotate_cw", &"rotate_ccw", &"hold", &"pause"]:
		h._unhandled_input(_action_event(a, true))
		h._unhandled_input(_action_event(a, false))
	t.check_eq(seen, [&"hard_drop", &"rotate_cw", &"rotate_ccw", &"hold", &"pause"] as Array[StringName], "tap actions fire once on press")
	h.free()


func test_release_all_clears_held_inputs() -> void:
	var h := InputHandler.new()
	var dirs: Array[int] = []
	var soft: Array[bool] = []
	h.direction_changed.connect(func(d: int) -> void: dirs.append(d))
	h.soft_drop_changed.connect(func(on: bool) -> void: soft.append(on))
	h._unhandled_input(_action_event(&"move_left", true))
	h.release_all()
	t.check_eq(dirs, [-1, 0] as Array[int], "direction released")
	t.check_eq(soft, [false] as Array[bool], "soft drop released")
	# A stale release after resume must not re-trigger anything odd.
	h._unhandled_input(_action_event(&"move_left", false))
	t.check_eq(dirs, [-1, 0] as Array[int], "no duplicate release")
	# Holding right alone after a full reset works normally.
	h._unhandled_input(_action_event(&"move_right", true))
	t.check_eq(dirs, [-1, 0, 1] as Array[int], "fresh press accepted")
	h.free()


func test_sound_toggle_action() -> void:
	t.check(InputMap.has_action("toggle_sound"), "defined")
	t.check(not InputMap.action_get_events("toggle_sound").is_empty(), "bound")
	var h := InputHandler.new()
	var count := [0]
	h.toggle_sound_pressed.connect(func() -> void: count[0] += 1)
	h._unhandled_input(_action_event(&"toggle_sound", true))
	t.check_eq(count[0], 1, "signal")
	h.free()


func test_dpad_down_and_horizontal_zones() -> void:
	_setup()
	var d: Rect2 = _layout.dpad_rect
	t.check_eq(_controls.action_at(d.position + d.size * Vector2(0.2, 0.45)), &"move_left", "left arm")
	t.check_eq(_controls.action_at(d.position + d.size * Vector2(0.8, 0.45)), &"move_right", "right arm")
	t.check_eq(_controls.action_at(d.position + d.size * Vector2(0.5, 0.85)), &"soft_drop", "down arm")
	t.check_eq(_controls.action_at(d.position + d.size * Vector2(0.5, 0.1)), &"", "up arm is inert")
	t.check_eq(_controls.action_at(d.position + d.size * Vector2(0.5, 0.45)) in [&"move_left", &"move_right"], true, "centre has no dead spot")


func test_face_buttons_are_round_and_distinct() -> void:
	_setup()
	var ccw: Rect2 = _layout.buttons[&"rotate_ccw"]
	var cw: Rect2 = _layout.buttons[&"rotate_cw"]
	t.check(ccw.get_center().x < cw.get_center().x and ccw.get_center().y > cw.get_center().y, "CCW lower-left, CW upper-right")
	# A square's corner is outside the circle: no touch there.
	t.check_eq(_controls.action_at(ccw.position + Vector2(1, 1)), &"", "corner of the bounding square misses")
	t.check_eq(_controls.action_at(ccw.get_center() + Vector2(ccw.size.x * 0.5, 0)), &"rotate_ccw", "edge of the circle hits")
	t.check(ccw.get_center().distance_to(cw.get_center()) > ccw.size.x * 1.2, "circles do not touch")


func test_hard_drop_is_the_largest_pill_and_apart_from_face_buttons() -> void:
	_setup()
	var drop: Rect2 = _layout.buttons[&"hard_drop"]
	var hold: Rect2 = _layout.buttons[&"hold"]
	t.check(drop.get_area() > hold.get_area(), "DROP bigger than HOLD")
	t.check(drop.end.x + GameLayout.CLUSTER_GAP <= (_layout.buttons[&"rotate_ccw"] as Rect2).position.x, "DROP clear of the face buttons")


func test_skin_draws_every_state_without_error() -> void:
	# Smoke test: all states (normal, pressed, disabled) execute on a real canvas item.
	var node := Node2D.new()
	for alpha in [1.0, ControllerSkin.DISABLED_ALPHA]:
		ControllerSkin.draw_body(node, _layout.controls_rect, alpha)
		for pressed in [false, true]:
			ControllerSkin.draw_dpad(node, _layout.dpad_rect, pressed, pressed, pressed, alpha)
			ControllerSkin.draw_round_button(node, _layout.buttons[&"rotate_cw"], ControllerSkin.FACE_CW, "CW", pressed, alpha)
			ControllerSkin.draw_pill(node, _layout.buttons[&"hard_drop"], ControllerSkin.PILL_DROP, "DROP", pressed, alpha)
	node.free()
	t.check(true, "drew")


func test_touch_never_references_game_state() -> void:
	# Structural guard: the controls script must not know about the session or board.
	var source := FileAccess.get_file_as_string("res://src/ui/touch_controls.gd")
	for forbidden in ["GameSession", "Board", "session."]:
		t.check(not source.contains(forbidden), "touch_controls.gd mentions " + forbidden)
	var skin := FileAccess.get_file_as_string("res://src/ui/controller_skin.gd")
	t.check(not skin.contains("Input.") and not skin.contains("GameSession"), "skin is drawing only")
