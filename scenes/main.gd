extends Node2D
## Composition root: creates the session and wires the view and input to it.

const BOARD_ORIGIN := Vector2(120, 160)  # centers a 480px board in 720px width

var _session: GameSession = GameSession.new()

@onready var _board_view: BoardView = $BoardView
@onready var _input: InputHandler = $InputHandler


func _ready() -> void:
	_board_view.position = BOARD_ORIGIN
	_session.spawn_next()
	_board_view.bind(_session)
