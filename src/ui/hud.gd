class_name Hud
extends CanvasLayer
## Basic HUD: HOLD/NEXT captions and the score, lines and level readouts.
## Positions and sizes come from GameLayout. Reads session state each frame;
## never mutates it.

const CAPTION_FONT_SIZE: int = 20

var _session: GameSession
var _hold_caption: Label
var _next_caption: Label
var _score: Label
var _lines: Label
var _level: Label


func _ready() -> void:
	_hold_caption = _make_label("HOLD")
	_next_caption = _make_label("NEXT")
	_score = _make_label("")
	_lines = _make_label("")
	_level = _make_label("")
	_hold_caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_next_caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)


func bind(session: GameSession) -> void:
	_session = session
	_refresh()


func apply_layout(layout: GameLayout) -> void:
	_hold_caption.position = layout.hold_caption_pos
	_next_caption.position = layout.next_caption_pos
	var block: float = layout.stat_block_height()
	var labels: Array[Label] = [_score, _lines, _level]
	for i in range(labels.size()):
		labels[i].add_theme_font_size_override("font_size", layout.stat_font_size)
		labels[i].position = layout.stats_rect.position + Vector2(0, i * block)


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _session == null or _score == null:
		return
	_score.text = "SCORE\n%d" % _session.stats.score
	_lines.text = "LINES\n%d" % _session.stats.lines
	_level.text = "LEVEL\n%d" % _session.stats.level


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	add_child(label)
	return label
