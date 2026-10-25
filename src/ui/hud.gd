class_name Hud
extends CanvasLayer
## Basic HUD: score, lines and level above the board, plus a game-over banner.
## Reads session state each frame; never mutates it. Built from code so the
## scene stays minimal.

const FONT_SIZE: int = 36
const BANNER_FONT_SIZE: int = 56
const MARGIN: float = 40.0
const BASE_WIDTH: float = 720.0
const BOARD_CENTER := Vector2(360, 640)  # matches BoardView placement in main.gd

var _session: GameSession
var _score: Label
var _lines: Label
var _level: Label
var _banner: Label


func _ready() -> void:
	_score = _make_label(FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT)
	_lines = _make_label(FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT)
	_level = _make_label(FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
	_score.position = Vector2(MARGIN, 30)
	_lines.position = Vector2(MARGIN, 85)
	_level.position = Vector2(BASE_WIDTH - MARGIN - 300, 30)
	_level.size = Vector2(300, 50)
	_banner = _make_label(BANNER_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.text = "GAME OVER\nPress R to restart"
	_banner.size = Vector2(BASE_WIDTH, 200)
	_banner.position = Vector2(0, BOARD_CENTER.y - 100)
	_banner.visible = false


func bind(session: GameSession) -> void:
	_session = session
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _session == null or _score == null:
		return
	_score.text = "SCORE %d" % _session.stats.score
	_lines.text = "LINES %d" % _session.stats.lines
	_level.text = "LEVEL %d" % _session.stats.level
	_banner.visible = _session.game_over


func _make_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = alignment
	add_child(label)
	return label
