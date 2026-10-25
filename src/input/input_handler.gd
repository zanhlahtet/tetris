class_name InputHandler
extends Node
## Translates Input Map actions (from keyboard or the on-screen touch buttons) (move_left, move_right, soft_drop, hard_drop,
## rotate_cw, rotate_ccw, restart, hold, toggle_ghost, toggle_sound, pause, defined in project.godot) into abstract game commands. Emits signals only;
## knows nothing about the board or session.

signal direction_changed(direction: int)  ## -1, 0 or 1; latest press wins
signal soft_drop_changed(enabled: bool)
signal hard_drop_pressed
signal rotate_cw_pressed
signal rotate_ccw_pressed
signal restart_pressed
signal hold_pressed
signal toggle_ghost_pressed
signal pause_pressed
signal toggle_sound_pressed

var _left_held: bool = false
var _right_held: bool = false
var _direction: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action("move_left"):
		_left_held = event.is_pressed()
		_update_direction(-1 if _left_held else 0)
	elif event.is_action("move_right"):
		_right_held = event.is_pressed()
		_update_direction(1 if _right_held else 0)
	elif event.is_action("soft_drop"):
		soft_drop_changed.emit(event.is_pressed())
	elif event.is_action_pressed("hard_drop"):
		hard_drop_pressed.emit()
	elif event.is_action_pressed("rotate_cw"):
		rotate_cw_pressed.emit()
	elif event.is_action_pressed("rotate_ccw"):
		rotate_ccw_pressed.emit()
	elif event.is_action_pressed("restart"):
		restart_pressed.emit()
	elif event.is_action_pressed("hold"):
		hold_pressed.emit()
	elif event.is_action_pressed("toggle_ghost"):
		toggle_ghost_pressed.emit()
	elif event.is_action_pressed("pause"):
		pause_pressed.emit()
	elif event.is_action_pressed("toggle_sound"):
		toggle_sound_pressed.emit()


## Forgets every held input (used when the app loses focus, since the matching
## release events may never arrive).
func release_all() -> void:
	_left_held = false
	_right_held = false
	_update_direction(0)
	soft_drop_changed.emit(false)


## pressed_direction is the direction just pressed, or 0 on a release; on
## release we fall back to whichever direction is still held.
func _update_direction(pressed_direction: int) -> void:
	var new_direction: int = pressed_direction
	if new_direction == 0:
		new_direction = -1 if _left_held else (1 if _right_held else 0)
	if new_direction != _direction:
		_direction = new_direction
		direction_changed.emit(_direction)
