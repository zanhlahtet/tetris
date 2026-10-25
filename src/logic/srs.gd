class_name Srs
extends RefCounted
## Super Rotation System wall-kick data.
##
## Rotation states: 0 = spawn, 1 = R (clockwise from spawn), 2, 3 = L.
##
## COORDINATE CONVENTION: the tables below are transcribed exactly as published
## (Tetris Guideline / SRS wiki), where +x is right and +y is UP. Godot's board
## has +y DOWN, so kick_offsets() negates y when returning them. Callers always
## receive board-space (y-down) offsets to add to the piece origin.
##
## Each entry is the ordered list of 5 tests; the first is always (0, 0)
## (plain rotation) and the first test that does not collide is used.
## The O piece has no kicks and the I piece has its own table.

const _JLSTZ: Dictionary = {
	Vector2i(0, 1): [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	Vector2i(1, 0): [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	Vector2i(1, 2): [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	Vector2i(2, 1): [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	Vector2i(2, 3): [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	Vector2i(3, 2): [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	Vector2i(3, 0): [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	Vector2i(0, 3): [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
}

const _I: Dictionary = {
	Vector2i(0, 1): [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, -1), Vector2i(1, 2)],
	Vector2i(1, 0): [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, 1), Vector2i(-1, -2)],
	Vector2i(1, 2): [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 2), Vector2i(2, -1)],
	Vector2i(2, 1): [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, -2), Vector2i(-2, 1)],
	Vector2i(2, 3): [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, 1), Vector2i(-1, -2)],
	Vector2i(3, 2): [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, -1), Vector2i(1, 2)],
	Vector2i(3, 0): [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, -2), Vector2i(-2, 1)],
	Vector2i(0, 3): [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 2), Vector2i(2, -1)],
}


## Ordered kick tests (board-space, y down) for rotating `type` from state
## `from` to the adjacent state `to`. The O piece has none: it returns just
## the plain (0, 0) rotation.
static func kick_offsets(type: int, from: int, to: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if type == Tetromino.Type.O:
		out.append(Vector2i.ZERO)
		return out
	var table: Dictionary = _I if type == Tetromino.Type.I else _JLSTZ
	for offset: Vector2i in table[Vector2i(from, to)]:
		out.append(Vector2i(offset.x, -offset.y))
	return out
