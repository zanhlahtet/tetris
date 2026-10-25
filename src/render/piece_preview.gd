class_name PiecePreview
extends Node2D
## Draws small pieces in a vertical list: either the upcoming queue or the
## hold slot. Read-only view of session state.

enum Source { NEXT, HOLD }

const PANEL_PADDING: float = 5.0
const HOLD_USED_ALPHA: float = 0.35

@export var source: Source = Source.NEXT

## Pixel size of one preview block; a slot is 4x3 blocks. Set by the layout.
var cell_size: int = 24

var _session: GameSession


func bind(session: GameSession) -> void:
	_session = session
	queue_redraw()


func set_cell_size(value: int) -> void:
	cell_size = value
	queue_redraw()


func _slot_size() -> Vector2:
	return Vector2(4, 3) * cell_size


func _draw() -> void:
	var slots: int = GameSession.PREVIEW_COUNT if source == Source.NEXT else 1
	var panel := Rect2(Vector2.ZERO, Vector2(_slot_size().x, _slot_size().y * slots)).grow(PANEL_PADDING)
	RetroDraw.draw_panel(self, panel)
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
	var extent := Vector2(max_c - min_c + Vector2i.ONE) * cell_size
	var slot_origin := Vector2(0, slot * _slot_size().y)
	var offset := slot_origin + (_slot_size() - extent) / 2.0
	var color: Color = BoardView.PIECE_COLORS[type]
	for c in cells:
		var rect := Rect2((offset + Vector2(c - min_c) * cell_size).floor(), Vector2(cell_size, cell_size))
		RetroDraw.draw_tile(self, rect, color, alpha)
