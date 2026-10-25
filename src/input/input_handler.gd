class_name InputHandler
extends Node
## Translates Input Map actions (move_left, move_right, soft_drop, hard_drop,
## defined in project.godot) into abstract game commands. Emits signals only;
## knows nothing about the board or session.

signal direction_changed(direction: int)  ## -1, 0 or 1; latest press wins
signal soft_drop_changed(enabled: bool)
signal hard_drop_pressed

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


## pressed_direction is the direction just pressed, or 0 on a release; on
## release we fall back to whichever direction is still held.
func _update_direction(pressed_direction: int) -> void:
	var new_direction: int = pressed_direction
	if new_direction == 0:
		new_direction = -1 if _left_held else (1 if _right_held else 0)
	if new_direction != _direction:
		_direction = new_direction
		direction_changed.emit(_direction)
