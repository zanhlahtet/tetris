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
	&"move_left": "LEFT",
	&"move_right": "RIGHT",
	&"soft_drop": "SOFT",
	&"rotate_ccw": "CCW",
	&"rotate_cw": "CW",
	&"hold": "HOLD",
	&"hard_drop": "DROP",
	&"pause": "PAUSE",
}
const FILL := Color(1, 1, 1, 0.10)
const FILL_PRESSED := Color(1, 1, 1, 0.30)
const OUTLINE := Color(1, 1, 1, 0.28)
const TEXT_COLOR := Color(1, 1, 1, 0.85)

var enabled: bool = true:
	set(value):
		if value == enabled:
			return
		enabled = value
		if not enabled:
			release_all()
		queue_redraw()

var _rects: Dictionary = {}
var _hit_slop: float = 0.0
var _touches: Dictionary = {}  # touch index -> action
var _counts: Dictionary = {}  # action -> number of fingers holding it


func set_layout(layout: GameLayout) -> void:
	_rects = layout.buttons.duplicate()
	_hit_slop = GameLayout.GAP / 2.0
	queue_redraw()


## Action under a point (button rects are grown by half the gap so there are
## no dead zones between neighbours), or &"" if none.
func action_at(point: Vector2) -> StringName:
	for action: StringName in _rects:
		if (_rects[action] as Rect2).grow(_hit_slop).has_point(point):
			return action
	return &""


func is_pressed(action: StringName) -> bool:
	return _counts.get(action, 0) > 0


func release_all() -> void:
	for index in _touches.keys():
		_release_touch(index)


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			var action := action_at(touch.position)
			if action != &"":
				_press(touch.index, action)
		else:
			_release_touch(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _touches.has(drag.index):
		_on_drag(drag)


## A finger sliding between movement buttons switches action; leaving the
## button releases it. Sliding onto tap buttons (rotate, hold, drop) does nothing.
func _on_drag(drag: InputEventScreenDrag) -> void:
	var current: StringName = _touches[drag.index]
	var target := action_at(drag.position)
	if target == current:
		return
	var can_slide: bool = SLIDE_ACTIONS.has(current)
	_release_touch(drag.index)
	if can_slide and SLIDE_ACTIONS.has(target):
		_press(drag.index, target)


func _press(index: int, action: StringName) -> void:
	if _touches.has(index):
		_release_touch(index)
	_touches[index] = action
	_counts[action] = _counts.get(action, 0) + 1
	if _counts[action] == 1:
		action_changed.emit(action, true)
		queue_redraw()


func _release_touch(index: int) -> void:
	if not _touches.has(index):
		return
	var action: StringName = _touches[index]
	_touches.erase(index)
	_counts[action] -= 1
	if _counts[action] == 0:
		action_changed.emit(action, false)
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for action: StringName in _rects:
		var rect: Rect2 = _rects[action]
		draw_rect(rect, FILL_PRESSED if is_pressed(action) else FILL)
		draw_rect(rect, OUTLINE, false, 2.0)
		var font_size: int = clampi(int(rect.size.y * 0.3), 14, 40)
		var baseline := Vector2(rect.position.x, rect.position.y + rect.size.y / 2.0 + font_size * 0.35)
		draw_string(font, baseline, LABELS[action], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, TEXT_COLOR)
