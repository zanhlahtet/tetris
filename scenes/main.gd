extends Node2D
## Composition root: creates the session, wires views, input, touch controls,
## audio and overlays to it, owns local persistence, and keeps the layout in
## sync with the screen.

## Longest frame time fed to the simulation; a hitch must not cause a burst of
## catch-up movement.
const MAX_FRAME_SECONDS: float = 0.1

var _session: GameSession = GameSession.new()
var _save: SaveData = SaveData.new()
var _elapsed_ms: float = 0.0
var _idle_frames: int = 0

@onready var _board_view: BoardView = $BoardView
@onready var _hold_view: PiecePreview = $HoldView
@onready var _next_view: PiecePreview = $NextView
@onready var _hud: Hud = $Hud
@onready var _touch: TouchControls = $TouchLayer/TouchControls
@onready var _overlay: Overlay = $Overlay
@onready var _sfx: Sfx = $Sfx
@onready var _input: InputHandler = $InputHandler


func _ready() -> void:
	_save.load_from_disk()
	_sfx.enabled = _save.sound_enabled
	_board_view.show_ghost = _save.ghost_enabled
	_sfx.bind(_session)
	_session.game_ended.connect(_commit_score)
	_session.spawn_next()
	_board_view.bind(_session)
	_hold_view.bind(_session)
	_next_view.bind(_session)
	_hud.bind(_session, _save)
	_overlay.bind(_session, _save)
	_input.direction_changed.connect(_session.set_direction)
	_input.soft_drop_changed.connect(_session.set_soft_drop)
	_input.hard_drop_pressed.connect(_session.hard_drop)
	_input.rotate_cw_pressed.connect(_session.rotate_cw)
	_input.rotate_ccw_pressed.connect(_session.rotate_ccw)
	_input.restart_pressed.connect(_session.restart)
	_input.hold_pressed.connect(_session.hold)
	_input.toggle_ghost_pressed.connect(_toggle_ghost)
	_input.toggle_sound_pressed.connect(_toggle_sound)
	_input.pause_pressed.connect(_toggle_pause)
	_overlay.resume_pressed.connect(_session.resume)
	_overlay.restart_pressed.connect(_session.restart)
	_overlay.sound_toggled.connect(_toggle_sound)
	_overlay.ghost_toggled.connect(_toggle_ghost)
	# Touch buttons become ordinary Input Map actions, exactly like key presses.
	_touch.action_changed.connect(_inject_action)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _process(delta: float) -> void:
	# The session runs on whole milliseconds; carry the fractional remainder.
	_elapsed_ms += minf(delta, MAX_FRAME_SECONDS) * 1000.0
	var whole_ms: int = int(_elapsed_ms)
	_elapsed_ms -= whole_ms
	_session.tick(whole_ms)
	_touch.enabled = not _session.paused and not _session.game_over
	# Nothing moves while paused or over: draw one last frame, then stop redrawing.
	_idle_frames = _idle_frames + 1 if (_session.paused or _session.game_over) else 0
	if _idle_frames <= 1:
		_board_view.queue_redraw()
		_hold_view.queue_redraw()
		_next_view.queue_redraw()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	match what:
		# Backgrounded or unfocused: pause, drop held inputs whose release events
		# may never arrive, and persist. The game stays paused on return.
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_session.pause()
			_input.release_all()
			_touch.release_all()
			_persist()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_persist()
		# Android back button: pause instead of quitting.
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_toggle_pause()


func _toggle_pause() -> void:
	if _session.paused:
		_session.resume()
	else:
		_session.pause()


func _toggle_sound() -> void:
	_save.sound_enabled = not _save.sound_enabled
	_sfx.enabled = _save.sound_enabled
	_save.save()


func _toggle_ghost() -> void:
	_save.ghost_enabled = not _save.ghost_enabled
	_board_view.show_ghost = _save.ghost_enabled
	_board_view.queue_redraw()
	_save.save()


## Records the score if it is a new best (also used mid-game when the app is
## backgrounded, so progress is not lost if the OS kills it).
func _commit_score() -> void:
	if _save.submit_score(_session.stats.score):
		_save.save()


func _persist() -> void:
	_commit_score()
	_save.save()


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
