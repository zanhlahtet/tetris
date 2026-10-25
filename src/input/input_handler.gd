class_name InputHandler
extends Node
## Translates device input (keyboard now, touch later) into abstract game
## commands. Emits signals only; knows nothing about the board or session.

signal move_left
signal move_right
signal soft_drop
signal hard_drop
signal rotate_cw
signal rotate_ccw
signal hold


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_LEFT: move_left.emit()
		KEY_RIGHT: move_right.emit()
		KEY_DOWN: soft_drop.emit()
		KEY_SPACE: hard_drop.emit()
		KEY_UP, KEY_X: rotate_cw.emit()
		KEY_Z: rotate_ccw.emit()
		KEY_C: hold.emit()
