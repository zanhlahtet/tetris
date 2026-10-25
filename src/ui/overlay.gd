class_name Overlay
extends CanvasLayer
## Pause and Game Over overlays: a dimmed full-screen layer with a title, a
## summary and buttons. Reads session state each frame and only emits signals;
## the composition root decides what resume/restart do.

signal resume_pressed
signal restart_pressed

const TITLE_FONT_SIZE: int = 64
const INFO_FONT_SIZE: int = 32
const BUTTON_FONT_SIZE: int = 40
const BUTTON_SIZE := Vector2(340, 96)

var _session: GameSession
var _dim: ColorRect
var _title: Label
var _info: Label
var _resume: Button
var _restart: Button


func _ready() -> void:
	layer = 20
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)
	_title = _make_label(TITLE_FONT_SIZE, box)
	_info = _make_label(INFO_FONT_SIZE, box)
	_resume = _make_button("RESUME", box)
	_restart = _make_button("RESTART", box)
	_resume.pressed.connect(resume_pressed.emit)
	_restart.pressed.connect(restart_pressed.emit)
	_dim.visible = false


func bind(session: GameSession) -> void:
	_session = session


func _process(_delta: float) -> void:
	if _session == null:
		return
	_dim.visible = _session.game_over or _session.paused
	if _session.game_over:
		_title.text = "GAME OVER"
		_info.text = "SCORE %d\nLINES %d   LEVEL %d" % [_session.stats.score, _session.stats.lines, _session.stats.level]
		_resume.visible = false
	elif _session.paused:
		_title.text = "PAUSED"
		_info.text = ""
		_resume.visible = true


func _make_label(font_size: int, parent: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _make_button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	parent.add_child(button)
	return button
