class_name TSpin
extends RefCounted
## T-Spin detection using the Tetris Guideline three-corner rule.
##
## A lock is a T-Spin when the piece is a T, its last successful action was a
## rotation (any move or fall since clears that), and at least three of the four
## corners around its centre are occupied (locked cells, walls and floor count).
## It is a full T-Spin if both corners on the side the T points towards ("front")
## are occupied, or if the rotation used the fifth SRS kick test (the (+-1, +-2)
## kick); otherwise it is a Mini.

enum Kind { NONE, MINI, FULL }

## Index of the fifth kick test; promotes a Mini to a full T-Spin.
const PROMOTING_KICK_INDEX: int = 4

## Corner offsets inside the T's 3x3 box.
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]

## Front corners per rotation state (the two on the side the nub points to).
const FRONT_CORNERS: Dictionary = {
	0: [Vector2i(0, 0), Vector2i(2, 0)],  # nub up
	1: [Vector2i(2, 0), Vector2i(2, 2)],  # nub right
	2: [Vector2i(0, 2), Vector2i(2, 2)],  # nub down
	3: [Vector2i(0, 0), Vector2i(0, 2)],  # nub left
}


static func detect(board: Board, piece: ActivePiece) -> Kind:
	if piece.type != Tetromino.Type.T or not piece.spun:
		return Kind.NONE
	var occupied: int = 0
	for corner in CORNERS:
		if _is_occupied(board, piece.origin + corner):
			occupied += 1
	if occupied < 3:
		return Kind.NONE
	var front: int = 0
	for corner: Vector2i in FRONT_CORNERS[piece.rotation]:
		if _is_occupied(board, piece.origin + corner):
			front += 1
	if front == 2 or piece.kick_index == PROMOTING_KICK_INDEX:
		return Kind.FULL
	return Kind.MINI


static func _is_occupied(board: Board, cell: Vector2i) -> bool:
	return not board.is_empty(cell.x, cell.y)
