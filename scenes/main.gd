extends Node2D
## Composition root: creates the session and wires the view and input to it.

const BOARD_ORIGIN := Vector2(120, 160)  # centers a 480px board in 720px width
const HOLD_ORIGIN := Vector2(12, 200)  # left of the board
const NEXT_ORIGIN := Vector2(612, 200)  # right of the board

var _session: GameSession = GameSession.new()
var _elapsed_ms: float = 0.0

@onready var _board_view: BoardView = $BoardView
@onready var _hold_view: PiecePreview = $HoldView
@onready var _next_view: PiecePreview = $NextView
@onready var _hud: Hud = $Hud
@onready var _input: InputHandler = $InputHandler


func _ready() -> void:
	_board_view.position = BOARD_ORIGIN
	_session.spawn_next()
	_board_view.bind(_session)
	_hold_view.position = HOLD_ORIGIN
	_next_view.position = NEXT_ORIGIN
	_hold_view.bind(_session)
	_next_view.bind(_session)
	_hud.bind(_session)
	_input.direction_changed.connect(_session.set_direction)
	_input.soft_drop_changed.connect(_session.set_soft_drop)
	_input.hard_drop_pressed.connect(_session.hard_drop)
	_input.rotate_cw_pressed.connect(_session.rotate_cw)
	_input.rotate_ccw_pressed.connect(_session.rotate_ccw)
	_input.restart_pressed.connect(_session.restart)
	_input.hold_pressed.connect(_session.hold)
	_input.toggle_ghost_pressed.connect(_board_view.toggle_ghost)


func _process(delta: float) -> void:
	# The session runs on whole milliseconds; carry the fractional remainder.
	_elapsed_ms += delta * 1000.0
	var whole_ms: int = int(_elapsed_ms)
	_elapsed_ms -= whole_ms
	_session.tick(whole_ms)
	_board_view.queue_redraw()
	_hold_view.queue_redraw()
	_next_view.queue_redraw()
