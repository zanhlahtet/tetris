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
	_touch(2, _center(&"rotate_cw"), true)
	t.check(_log.is_empty(), "ignored while disabled")
	_controls.enabled = true
	_touch(2, _center(&"rotate_cw"), true)
	t.check_eq(_log, [[&"rotate_cw", true]], "works again when enabled")


func test_late_release_of_unknown_touch_is_harmless() -> void:
	_setup()
	_touch(3, _center(&"rotate_ccw"), false)
	t.check(_log.is_empty(), "nothing to release")


# --- larger controls ------------------------------------------------------

# Sizes at 720x1280 before this change: D-pad 202.8, face circles 101.4, PAUSE 170x56.
func test_controls_are_enlarged() -> void:
	_setup()
	t.check(_layout.dpad_rect.size.x >= 202.8 * 1.15 and _layout.dpad_rect.size.x <= 202.8 * 1.25, "D-pad 15-25%% larger: %s" % _layout.dpad_rect.size.x)
	var c: float = (_layout.buttons[&"rotate_cw"] as Rect2).size.x
	t.check(c >= 101.4 * 1.15 and c <= 101.4 * 1.25, "X/O about 20%% larger: %s" % c)
	t.check(_layout.pause_rect.size.y > 56.0 and _layout.pause_rect.size.x >= 160.0, "PAUSE larger: %s" % _layout.pause_rect.size)
	t.check(_layout.board_rect.size.x >= 480.0, "playfield not squeezed")


func test_hit_regions_do_not_overlap() -> void:
	for safe in [Rect2(0, 0, 720, 1280), Rect2(0, 0, 720, 1560), Rect2(0, 59, 720, 1160), Rect2(0, 0, 960, 1280), Rect2(40, 0, 640, 1280)]:
		var l := GameLayout.compute(safe)
		var controls := TouchControls.new()
		controls.set_layout(l)
		var step := 3.0
		var y: float = l.controls_rect.position.y
		while y < l.controls_rect.end.y:
			var x: float = l.controls_rect.position.x
			while x < l.controls_rect.end.x:
				var hits := controls.actions_at(Vector2(x, y))
				t.check(hits.size() <= 1, "%s overlap at (%d,%d) in %s" % [hits, x, y, safe])
				x += step
			y += step
		controls.free()


func test_hit_regions_stay_within_the_controller_body() -> void:
	_setup()
	var body: Rect2 = _layout.controls_rect.grow(GameLayout.GAP)
	for action: StringName in _layout.buttons:
		var r: Rect2 = _layout.buttons[action]
		var reach: Rect2 = r.grow(r.size.x * 0.1) if GameLayout.ROUND_ACTIONS.has(action) else r.grow(GameLayout.GAP / 2.0)
		t.check(body.encloses(reach), "%s hit region inside the controller area" % action)


func test_hit_regions_cover_more_than_the_drawn_buttons() -> void:
	_setup()
	var cw: Rect2 = _layout.buttons[&"rotate_cw"]
	var just_outside: Vector2 = cw.get_center() + Vector2(cw.size.x / 2.0 + 4.0, 0)
	t.check_eq(_controls.action_at(just_outside), &"rotate_cw", "touch slightly outside the circle still hits")
	var p: Rect2 = _layout.pause_rect
	t.check_eq(_controls.action_at(p.position - Vector2(4, 4)), &"pause", "touch just outside PAUSE still hits")


# --- tracking -------------------------------------------------------------

func test_finger_can_leave_and_return_to_the_dpad() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_drag(0, _layout.board_rect.get_center())
	t.check(not _controls.is_pressed(&"move_left"), "released while away")
	_drag(0, _layout.board_rect.get_center() + Vector2(0, 5))
	t.check_eq(_log.size(), 2, "no extra events while away")
	_drag(0, _center(&"move_right"))
	t.check(_controls.is_pressed(&"move_right"), "resumes on re-entry, even on another arm")
	t.check_eq(_log, [[&"move_left", true], [&"move_left", false], [&"move_right", true]], "event order")
	_touch(0, _center(&"move_right"), false)
	t.check(not _controls.is_pressed(&"move_right"), "lift releases")


func test_real_release_while_away_is_harmless_and_forgets_the_finger() -> void:
	_setup()
	_touch(0, _center(&"soft_drop"), true)
	_drag(0, _layout.board_rect.get_center())
	_touch(0, _layout.board_rect.get_center(), false)
	t.check_eq(_log, [[&"soft_drop", true], [&"soft_drop", false]], "exactly one release")
	_drag(0, _center(&"soft_drop"))
	t.check_eq(_log.size(), 2, "a lifted finger is no longer tracked")


func test_lift_releases_immediately() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_touch(0, _center(&"move_left"), false)
	t.check(not _controls.is_pressed(&"move_left"), "no longer held")
	t.check(not _controls.is_lit(&"move_left"), "D-pad has no lingering feedback")


func test_cancelled_touch_releases() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = _center(&"move_left")
	e.pressed = true
	e.canceled = true
	_controls._input(e)
	t.check(not _controls.is_pressed(&"move_left"), "cancel releases the action")


func test_hysteresis_prevents_flicker_at_a_boundary() -> void:
	_setup()
	var left: Rect2 = _layout.buttons[&"move_left"]
	var right: Rect2 = _layout.buttons[&"move_right"]
	var y: float = left.get_center().y
	var boundary: float = right.position.x
	_touch(0, Vector2(boundary - 20.0, y), true)
	for dx in [1.0, -2.0, 3.0, -1.0, 4.0, 2.0]:
		_drag(0, Vector2(boundary + dx, y))
	t.check_eq(_log, [[&"move_left", true]], "wobble around the centre line changes nothing")
	_drag(0, Vector2(boundary + TouchControls.HYSTERESIS + 6.0, y))
	t.check(_controls.is_pressed(&"move_right") and not _controls.is_pressed(&"move_left"), "a deliberate move switches")
	_drag(0, Vector2(boundary - 3.0, y))
	t.check(_controls.is_pressed(&"move_right"), "and does not flip straight back")


func test_hold_tolerates_a_slightly_wandering_finger() -> void:
	_setup()
	var left: Rect2 = _layout.buttons[&"move_left"]
	_touch(0, left.get_center(), true)
	_drag(0, Vector2(left.position.x - TouchControls.HYSTERESIS + 2.0, left.get_center().y))
	t.check(_controls.is_pressed(&"move_left"), "just outside the edge keeps holding")
	_drag(0, Vector2(left.position.x - TouchControls.HYSTERESIS - 4.0, left.get_center().y))
	t.check(not _controls.is_pressed(&"move_left"), "deliberately away releases")


func test_one_shot_buttons_do_not_retrigger_on_reentry() -> void:
	_setup()
	for action in [&"rotate_cw", &"rotate_ccw", &"pause"]:
		_setup()
		_touch(0, _center(action), true)
		_drag(0, _layout.board_rect.get_center())
		_drag(0, _center(action))
		_drag(0, _center(action) + Vector2(1, 1))
		_touch(0, _center(action), false)
		t.check_eq(_log, [[action, true], [action, false]], "%s fires once" % action)


func test_quick_tap_fires_exactly_one_rotation() -> void:
	_setup()
	var h := InputHandler.new()
	var rotations: Array[StringName] = []
	h.rotate_cw_pressed.connect(func() -> void: rotations.append(&"cw"))
	h.rotate_ccw_pressed.connect(func() -> void: rotations.append(&"ccw"))
	_controls.action_changed.connect(func(a: StringName, pressed: bool) -> void: h._unhandled_input(_action_event(a, pressed)))
	_touch(0, _center(&"rotate_cw"), true)
	_touch(0, _center(&"rotate_cw"), false)
	_touch(1, _center(&"rotate_ccw"), true)
	_touch(1, _center(&"rotate_ccw"), false)
	t.check_eq(rotations, [&"cw", &"ccw"] as Array[StringName], "one rotation per tap")
	h.free()


func test_new_touch_on_a_tracked_index_replaces_the_old_one() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_touch(0, _center(&"move_right"), true)  # the first release was lost
	t.check(_controls.is_pressed(&"move_right") and not _controls.is_pressed(&"move_left"), "no stuck LEFT")
	_touch(0, _layout.board_rect.get_center(), true)
	t.check(not _controls.is_pressed(&"move_right"), "a stray touch on the same index also clears the old one")


func test_multitouch_with_one_finger_sliding() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_touch(1, _center(&"rotate_cw"), true)
	_drag(0, _center(&"soft_drop"))
	t.check(_controls.is_pressed(&"soft_drop") and _controls.is_pressed(&"rotate_cw"), "slide does not disturb the other finger")
	_drag(0, _layout.board_rect.get_center())
	_touch(1, _center(&"rotate_cw"), false)
	t.check(not _controls.is_pressed(&"soft_drop") and not _controls.is_pressed(&"rotate_cw"), "both released")
	t.check_eq(_log.filter(func(e: Array) -> bool: return e[0] == &"rotate_cw"), [[&"rotate_cw", true], [&"rotate_cw", false]], "rotate pressed once")


func test_two_fingers_share_an_arm_and_one_wanders() -> void:
	_setup()
	var p := _center(&"move_left")
	_touch(0, p, true)
	_touch(1, p, true)
	_drag(0, _layout.board_rect.get_center())
	t.check(_controls.is_pressed(&"move_left"), "the other finger still holds LEFT")
	_drag(1, _layout.board_rect.get_center())
	t.check(not _controls.is_pressed(&"move_left"), "released when both leave")
	t.check_eq(_log, [[&"move_left", true], [&"move_left", false]], "one press, one release")


func test_release_all_drops_every_finger_for_pause_and_background() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_touch(1, _center(&"soft_drop"), true)
	_touch(2, _center(&"rotate_cw"), true)
	_controls.release_all()
	for a in [&"move_left", &"soft_drop", &"rotate_cw"]:
		t.check(not _controls.is_pressed(a), "%s released" % a)
	var releases := _log.filter(func(e: Array) -> bool: return not e[1])
	t.check_eq(releases.size(), 3, "a release event for each so no key sticks")
	_drag(0, _center(&"move_left"))
	t.check(not _controls.is_pressed(&"move_left"), "after a reset an old finger must start over")
	_touch(0, _center(&"move_left"), true)
	t.check(_controls.is_pressed(&"move_left"), "and can start over")


func test_relayout_releases_held_inputs() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_controls.set_layout(GameLayout.compute(Rect2(0, 0, 960, 1280)))
	t.check(not _controls.is_pressed(&"move_left"), "resize does not leave LEFT stuck")
	t.check_eq(_log, [[&"move_left", true], [&"move_left", false]], "release was reported")


func test_pause_tap_disables_and_clears_everything() -> void:
	_setup()
	_touch(0, _center(&"move_left"), true)
	_touch(1, _center(&"pause"), true)
	_controls.enabled = false  # main.gd does this when the session pauses
	t.check(not _controls.is_pressed(&"move_left") and not _controls.is_pressed(&"pause"), "all released")
	_controls.enabled = true
	_drag(0, _center(&"move_right"))
	t.check(not _controls.is_pressed(&"move_right"), "stale fingers do not resume after unpausing")


# --- visual feedback ------------------------------------------------------

func test_quick_tap_stays_lit_for_the_minimum_time() -> void:
	_setup()
	var now := [1000]
	_controls.clock = func() -> int: return now[0]
	t.root.add_child(_controls)
	_touch(0, _center(&"rotate_cw"), true)
	now[0] = 1020
	_touch(0, _center(&"rotate_cw"), false)
	t.check(not _controls.is_pressed(&"rotate_cw"), "logically released at once")
	t.check(_controls.is_lit(&"rotate_cw"), "still drawn pressed")
	now[0] = 1000 + TouchControls.MIN_FEEDBACK_MS - 1
	_controls._process(0.0)
	t.check(_controls.is_lit(&"rotate_cw"), "lit until the minimum time passes")
	now[0] = 1000 + TouchControls.MIN_FEEDBACK_MS
	_controls._process(0.0)
	t.check(not _controls.is_lit(&"rotate_cw"), "then goes back to normal")
	t.check(not _controls.is_processing(), "no per-frame work when idle")
	t.check(TouchControls.MIN_FEEDBACK_MS >= 80 and TouchControls.MIN_FEEDBACK_MS <= 100, "80-100 ms")
	_touch(1, _center(&"rotate_cw"), true)
	now[0] = 2000
	_touch(1, _center(&"rotate_cw"), false)
	t.check(not _controls.is_lit(&"rotate_cw"), "a long press adds no extra lingering")
	t.root.remove_child(_controls)


func test_dpad_feedback_follows_the_finger() -> void:
	_setup()
	t.root.add_child(_controls)
	_touch(0, _center(&"move_left"), true)
	t.check(_controls.is_lit(&"move_left") and not _controls.is_lit(&"move_right"), "only the held arm is lit")
	_drag(0, _center(&"move_right"))
	t.check(_controls.is_lit(&"move_right") and not _controls.is_lit(&"move_left"), "lit state moves with the finger")
	_touch(0, _center(&"move_right"), false)
	t.check(not _controls.is_lit(&"move_right"), "cleared at once on release")
	t.root.remove_child(_controls)


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


func test_removed_hold_and_drop_buttons_are_gone() -> void:
	_setup()
	t.check(not _layout.buttons.has(&"hold") and not _layout.buttons.has(&"hard_drop"), "no hold/drop hit regions")
	t.check(not TouchControls.LABELS.has(&"hold") and not TouchControls.LABELS.has(&"hard_drop"), "no hold/drop labels")
	# Where DROP and HOLD used to be (between the clusters) nothing but PAUSE responds.
	var mid := Vector2((_layout.dpad_rect.end.x + _layout.face_rect.position.x) / 2.0, _layout.controls_rect.position.y + 20.0)
	_touch(0, mid, true)
	_touch(0, mid, false)
	t.check(_log.is_empty(), "empty gap does nothing")
	t.check(InputMap.has_action("hold") and InputMap.has_action("hard_drop"), "hold and hard_drop actions still exist for the keyboard")


func test_rotation_labels_and_actions() -> void:
	_setup()
	t.check_eq(TouchControls.LABELS[&"rotate_ccw"], "X", "X is counter-clockwise")
	t.check_eq(TouchControls.LABELS[&"rotate_cw"], "O", "O is clockwise")
	t.check((_layout.buttons[&"rotate_ccw"] as Rect2).position.y > (_layout.buttons[&"rotate_cw"] as Rect2).position.y, "X stays lower-left, O upper-right")
	_touch(0, _center(&"rotate_ccw"), true)
	_touch(1, _center(&"rotate_cw"), true)
	t.check_eq(_log, [[&"rotate_ccw", true], [&"rotate_cw", true]], "each fires its own action")


func test_controller_is_symmetrical() -> void:
	_setup()
	var body: Rect2 = _layout.controls_rect
	t.check(absf((_layout.dpad_rect.position.x - body.position.x) - (body.end.x - _layout.face_rect.end.x)) < 0.5, "equal side padding")
	t.check_eq(_layout.dpad_rect.size, _layout.face_rect.size, "same cluster size")
	var pause: Rect2 = _layout.buttons[&"pause"]
	t.check(absf(pause.get_center().x - body.get_center().x) < 0.5, "PAUSE centred between clusters")


# The skin must run inside a real _draw callback, so the probe is a node in the
# tree and the test waits for the engine to draw it.
class SkinProbe extends Node2D:
	var layout: GameLayout
	var draws: int = 0

	func _draw() -> void:
		for alpha in [1.0, ControllerSkin.DISABLED_ALPHA]:
			ControllerSkin.draw_body(self, layout.controls_rect, alpha)
			for pressed in [false, true]:
				ControllerSkin.draw_dpad(self, layout.dpad_rect, pressed, pressed, pressed, alpha)
				ControllerSkin.draw_round_button(self, layout.buttons[&"rotate_cw"], ControllerSkin.FACE_CW, "O", pressed, alpha)
				ControllerSkin.draw_pill(self, layout.pause_rect, ControllerSkin.PILL_PAUSE, "PAUSE", pressed, alpha)
		draws += 1


func test_skin_draws_inside_a_real_draw_callback() -> void:
	_setup()
	var probe := SkinProbe.new()
	probe.layout = _layout
	t.root.add_child(probe)
	await t.process_frame
	await t.process_frame
	t.check(probe.draws > 0, "_draw ran, so the skin executed in a valid drawing context")
	probe.queue_free()


func test_touch_never_references_game_state() -> void:
	# Structural guard: the controls script must not know about the session or board.
	var source := FileAccess.get_file_as_string("res://src/ui/touch_controls.gd")
	for forbidden in ["GameSession", "Board", "session."]:
		t.check(not source.contains(forbidden), "touch_controls.gd mentions " + forbidden)
	var skin := FileAccess.get_file_as_string("res://src/ui/controller_skin.gd")
	t.check(not skin.contains("Input.") and not skin.contains("GameSession"), "skin is drawing only")
