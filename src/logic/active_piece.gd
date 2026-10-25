class_name ActivePiece
extends RefCounted
## The falling piece: a type, rotation state and board position of its
## bounding box. Kept separate from the Board's locked cells.

var type: int
var rotation: int = 0
var origin: Vector2i


func _init(piece_type: int) -> void:
	type = piece_type
	origin = Tetromino.spawn_origin()


## Absolute board coordinates of the four blocks.
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in Tetromino.cells(type, rotation):
		out.append(origin + c)
	return out
