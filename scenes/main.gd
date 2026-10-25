extends Node2D
## Composition root: creates the session, wires views, input, touch controls
## and overlays to it, and keeps the layout in sync with the screen.

var _session: GameSession = GameSession.new()
var _elapsed_ms: float = 0.0

@onready var _board_view: BoardView = $BoardView
@onready var _hold_view: PiecePreview = $HoldView
@onready var _next_view: PiecePreview = $NextView
@onready var _hud: Hud = $Hud
@onready var _touch: TouchControls = $TouchLayer/TouchControls
@onready var _overlay: Overlay = $Overlay
@onready var _input: InputHandler = $InputHandler


func _ready() -> void:
	_session.spawn_next()
	_board_view.bind(_session)
	_hold_view.bind(_session)
	_next_view.bind(_session)
	_hud.bind(_session)
	_overlay.bind(_session)
	_input.direction_changed.connect(_session.set_direction)
	_input.soft_drop_changed.connect(_session.set_soft_drop)
	_input.hard_drop_pressed.connect(_session.hard_drop)
	_input.rotate_cw_pressed.connect(_session.rotate_cw)
	_input.rotate_ccw_pressed.connect(_session.rotate_ccw)
	_input.restart_pressed.connect(_session.restart)
	_input.hold_pressed.connect(_session.hold)
	_input.toggle_ghost_pressed.connect(_board_view.toggle_ghost)
	_input.pause_pressed.connect(_toggle_pause)
	_overlay.resume_pressed.connect(_session.resume)
	_overlay.restart_pressed.connect(_session.restart)
	# Touch buttons become ordinary Input Map actions, exactly like key presses.
	_touch.action_changed.connect(_inject_action)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _process(delta: float) -> void:
	# The session runs on whole milliseconds; carry the fractional remainder.
	_elapsed_ms += delta * 1000.0
	var whole_ms: int = int(_elapsed_ms)
	_elapsed_ms -= whole_ms
	_session.tick(whole_ms)
	_touch.enabled = not _session.paused and not _session.game_over
	_board_view.queue_redraw()
	_hold_view.queue_redraw()
	_next_view.queue_redraw()


func _notification(what: int) -> void:
	# Never let the game run unattended in the background.
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_session.pause()


func _toggle_pause() -> void:
	if _session.paused:
		_session.resume()
	else:
		_session.pause()


func _inject_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _apply_layout() -> void:
	var layout := GameLayout.compute(_safe_rect())
	_board_view.position = layout.board_rect.position
	_board_view.set_cell_size(layout.cell_size)
	_hold_view.position = layout.hold_rect.position
	_hold_view.set_cell_size(layout.preview_cell)
	_next_view.position = layout.next_rect.position
	_next_view.set_cell_size(layout.preview_cell)
	_hud.apply_layout(layout)
	_touch.set_layout(layout)


## Usable area in viewport coordinates. On phones this excludes notches and
## home indicators; on desktop the whole viewport is used.
func _safe_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, viewport_size)
	return GameLayout.safe_rect_in_viewport(
			Rect2(DisplayServer.get_display_safe_area()),
			Vector2(DisplayServer.window_get_size()), viewport_size)
