class_name PiecePreview
extends Node2D
## Draws small pieces in a vertical list: either the upcoming queue or the
## hold slot. Read-only view of session state.

enum Source { NEXT, HOLD }

const CELL: int = 24
const SLOT_SIZE := Vector2(96, 72)
const HOLD_USED_ALPHA: float = 0.35

@export var source: Source = Source.NEXT

var _session: GameSession


func bind(session: GameSession) -> void:
	_session = session
	queue_redraw()


func _draw() -> void:
	if _session == null:
		return
	if source == Source.HOLD:
		if _session.held_type != 0:
			var alpha: float = HOLD_USED_ALPHA if _session.hold_used else 1.0
			_draw_piece(_session.held_type, 0, alpha)
		return
	for i in range(_session.queue.size()):
		_draw_piece(_session.queue[i], i, 1.0)


func _draw_piece(type: int, slot: int, alpha: float) -> void:
	var cells := Tetromino.cells(type, 0)
	var min_c := Vector2i(99, 99)
	var max_c := Vector2i(-1, -1)
	for c in cells:
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var extent := Vector2(max_c - min_c + Vector2i.ONE) * CELL
	var slot_origin := Vector2(0, slot * SLOT_SIZE.y)
	var offset := slot_origin + (SLOT_SIZE - extent) / 2.0
	var color := Color(BoardView.PIECE_COLORS[type], alpha)
	for c in cells:
		var rect := Rect2(offset + Vector2(c - min_c) * CELL, Vector2(CELL, CELL)).grow(-1.0)
		draw_rect(rect, color)
