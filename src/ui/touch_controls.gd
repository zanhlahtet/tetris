class_name TouchControls
extends Node2D
## On-screen touch buttons. Hit-tests raw touch events itself (Godot's GUI only
## routes one pointer, so Button nodes can't do multi-touch) and reports
## Input Map action presses/releases through `action_changed`. It never touches
## game state: the composition root turns these into InputEventActions, so touch
## goes through exactly the same path as the keyboard.
##
## Desktop emulation: `input_devices/pointing/emulate_touch_from_mouse` turns the
## mouse into touch events.

signal action_changed(action: StringName, pressed: bool)

## Actions a finger may slide between while held (movement cluster).
const SLIDE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"soft_drop"]
const LABELS: Dictionary = {
	&"rotate_ccw": "X",
	&"pause": "PAUSE",
}
## Round buttons accept touches this much outside the drawn circle.
const ROUND_HIT_SCALE: float = 1.15
## A held action is kept until the finger is this many pixels beyond its hit
## region, so a finger wobbling on a boundary does not flicker between actions.
const HYSTERESIS: float = 10.0
## A tapped button stays drawn as pressed at least this long, so even the
## quickest tap is visible. Purely visual; the action itself is never delayed.
const MIN_FEEDBACK_MS: int = 90

var enabled: bool = true:
	set(value):
		if value == enabled:
			return
		enabled = value
		if not enabled:
			release_all()
		queue_redraw()

## Time source in milliseconds; replaceable so tests need not wait.
var clock: Callable = Time.get_ticks_msec

var _rects: Dictionary = {}
var _dpad_rect: Rect2
var _body_rect: Rect2
var _hit_slop: float = 0.0
## Every tracked finger (touch index) -> the action it currently holds, or &""
## once it has left that action's region. A finger stays tracked until it is
## really lifted, cancelled, or the controls are reset.
var _touches: Dictionary = {}
var _origin: Dictionary = {}  # touch index -> the action the finger started on
var _counts: Dictionary = {}  # action -> number of fingers holding it
var _pressed_at: Dictionary = {}  # action -> clock() when it was pressed
var _feedback_until: Dictionary = {}  # tap action -> clock() until it stays drawn pressed


func _ready() -> void:
	set_process(false)


## New geometry invalidates every held position, so start from a clean slate
## (a resize or rotation mid-press must not leave an action stuck).
func set_layout(layout: GameLayout) -> void:
	release_all()
	_rects = layout.buttons.duplicate()
	_dpad_rect = layout.dpad_rect
	_body_rect = layout.controls_rect
	_hit_slop = GameLayout.GAP / 2.0
	queue_redraw()


## Action under a point, or &"" if none.
func action_at(point: Vector2) -> StringName:
	var hits := actions_at(point)
	return hits[0] if not hits.is_empty() else &""


## Every action whose hit region contains the point (more than one would mean
## overlapping regions; the layout is tested to have none).
func actions_at(point: Vector2) -> Array[StringName]:
	var hits: Array[StringName] = []
	for action: StringName in _rects:
		if _contains(action, point, 0.0):
			hits.append(action)
	return hits


## D-pad zones come from the layout already padded and mutually exclusive;
## PAUSE is grown by half the gap; round buttons use a circle. `extra` widens
## any shape (used for hysteresis).
func _contains(action: StringName, point: Vector2, extra: float) -> bool:
	if not _rects.has(action):
		return false
	var rect: Rect2 = _rects[action]
	if GameLayout.ROUND_ACTIONS.has(action):
		var radius: float = minf(rect.size.x, rect.size.y) / 2.0 * ROUND_HIT_SCALE + extra
		return point.distance_to(rect.get_center()) <= radius
	var slop: float = 0.0 if SLIDE_ACTIONS.has(action) else _hit_slop
	return rect.grow(slop + extra).has_point(point)


## True while a finger holds the action (what the game sees).
func is_pressed(action: StringName) -> bool:
	return _counts.get(action, 0) > 0


## True while the action should be drawn pressed: held, or a tap button still
## inside its minimum feedback time.
func is_lit(action: StringName) -> bool:
	return is_pressed(action) or _feedback_until.has(action)


## Drops every finger and releases every held action. Used for pause, losing
## focus, disabling and layout changes.
func release_all() -> void:
	for index in _touches.keys():
		_release_action(index)
	_touches.clear()
	_origin.clear()


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and not touch.canceled:
			_begin(touch.index, touch.position)
		else:
			_end(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _touches.has(drag.index):
		_on_drag(drag.index, drag.position)


func _process(_delta: float) -> void:
	var now: int = clock.call()
	for action: StringName in _feedback_until.keys():
		if now >= _feedback_until[action]:
			_feedback_until.erase(action)
			queue_redraw()
	if _feedback_until.is_empty():
		set_process(false)


## A finger touching down on a button starts being tracked. One that lands
## elsewhere is ignored, so a stray touch never grabs a control later.
func _begin(index: int, position: Vector2) -> void:
	_end(index)  # a lost release must not leave the old state behind
	var action := action_at(position)
	if action == &"":
		return
	_origin[index] = action
	_touches[index] = &""
	_press(index, action)


func _end(index: int) -> void:
	_release_action(index)
	_touches.erase(index)
	_origin.erase(index)


## Movement fingers (those that began on LEFT/RIGHT/SOFT) switch between those
## actions as they slide and can leave and come back without lifting. A held
## action is only given up once the finger is HYSTERESIS beyond its region.
## Tap buttons (rotate, pause) fire once on touch-down and are never re-pressed
## by sliding.
func _on_drag(index: int, position: Vector2) -> void:
	var held: StringName = _touches[index]
	if held != &"" and _contains(held, position, HYSTERESIS):
		return
	_release_action(index)
	if not SLIDE_ACTIONS.has(_origin[index]):
		return
	var target := action_at(position)
	if SLIDE_ACTIONS.has(target):
		_press(index, target)


func _press(index: int, action: StringName) -> void:
	_touches[index] = action
	_counts[action] = _counts.get(action, 0) + 1
	if _counts[action] == 1:
		_pressed_at[action] = clock.call()
		_feedback_until.erase(action)
		action_changed.emit(action, true)
		queue_redraw()


## Releases the action a finger holds but keeps the finger itself tracked.
func _release_action(index: int) -> void:
	var action: StringName = _touches.get(index, &"")
	if action == &"":
		return
	_touches[index] = &""
	_counts[action] -= 1
	if _counts[action] == 0:
		_hold_feedback(action)
		action_changed.emit(action, false)
		queue_redraw()


## Keeps a quickly tapped one-shot button drawn as pressed for MIN_FEEDBACK_MS.
## The D-pad is not given this: it must show release immediately.
func _hold_feedback(action: StringName) -> void:
	if SLIDE_ACTIONS.has(action):
		return
	var now: int = clock.call()
	var until: int = _pressed_at.get(action, now) + MIN_FEEDBACK_MS
	if until > now:
		_feedback_until[action] = until
		set_process(true)


func _draw() -> void:
	var alpha: float = 1.0 if enabled else ControllerSkin.DISABLED_ALPHA
	ControllerSkin.draw_body(self, _body_rect, alpha)
	ControllerSkin.draw_dpad(self, _dpad_rect, is_lit(&"move_left"), is_lit(&"move_right"), is_lit(&"soft_drop"), alpha)
	var colors: Dictionary = {
		&"rotate_ccw": ControllerSkin.FACE_CCW, &"pause": ControllerSkin.PILL_PAUSE,
	}
	for action: StringName in colors:
		if not _rects.has(action):
			continue
		var rect: Rect2 = _rects[action]
		if GameLayout.ROUND_ACTIONS.has(action):
			ControllerSkin.draw_round_button(self, rect, colors[action], LABELS[action], is_lit(action), alpha)
		else:
			ControllerSkin.draw_pill(self, rect, colors[action], LABELS[action], is_lit(action), alpha)
