class_name Tetromino
extends RefCounted
## Static tetromino definitions (SRS-compatible). Pure data, no state.
##
## Each piece lives in a square bounding box (4x4 for I and O, 3x3 otherwise).
## Cell offsets are (x, y) inside the box with y growing down. Rotation states
## are 0 (spawn), 1 (R, clockwise), 2, 3 (L); they are derived from the spawn
## shape by rotating the box clockwise: (x, y) -> (size - 1 - y, x).
## Type values double as the non-zero cell ids stored in the Board.

enum Type { I = 1, O, T, S, Z, J, L }

const ALL_TYPES: Array[int] = [Type.I, Type.O, Type.T, Type.S, Type.Z, Type.J, Type.L]
const ROTATION_COUNT: int = 4

const _SPAWN_CELLS: Dictionary = {
	Type.I: [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	Type.O: [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	Type.T: [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	Type.S: [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	Type.Z: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	Type.J: [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	Type.L: [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}

## Board column of the bounding box's left edge at spawn (centres the piece).
const SPAWN_BOX_X: int = 3
## Board row of the bounding box's top edge at spawn. The piece's lower row
## lands on the first visible row (Board.HIDDEN_ROWS), its upper row above it.
const SPAWN_BOX_Y: int = Board.HIDDEN_ROWS - 1

static var _states: Dictionary = _build_states()


## Side length of the type's square bounding box.
static func box_size(type: int) -> int:
	return 4 if type == Type.I or type == Type.O else 3


## Cell offsets within the bounding box for a type and rotation state (0-3).
static func cells(type: int, rotation: int) -> Array[Vector2i]:
	return _states[type][posmod(rotation, ROTATION_COUNT)]


static func spawn_origin() -> Vector2i:
	return Vector2i(SPAWN_BOX_X, SPAWN_BOX_Y)


static func type_name(type: int) -> String:
	return Type.keys()[type - 1]


static func _build_states() -> Dictionary:
	var states: Dictionary = {}
	for type: int in ALL_TYPES:
		var size: int = box_size(type)
		var per_rotation: Array = []
		var current: Array[Vector2i] = []
		current.assign(_SPAWN_CELLS[type])
		for r in range(ROTATION_COUNT):
			per_rotation.append(current)
			if type == Type.O:
				continue  # O looks identical in every state
			var next: Array[Vector2i] = []
			for c in current:
				next.append(Vector2i(size - 1 - c.y, c.x))
			current = next
		states[type] = per_rotation
	return states
