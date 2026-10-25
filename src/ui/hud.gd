class_name Hud
extends CanvasLayer
## HUD: HOLD/NEXT captions, the statistics panel (score, lines, level, best)
## and the last-lock award text. Positions and sizes come from GameLayout.
## Reads session state each frame; never mutates it.


var _session: GameSession
var _save: SaveData
var _hold_caption: Label
var _next_caption: Label
var _stats_panel: Panel
var _captions: Array[Label] = []
var _values: Array[Label] = []
var _award: Label


func _ready() -> void:
	_hold_caption = _make_label("HOLD", RetroDraw.CAPTION, false)
	_next_caption = _make_label("NEXT", RetroDraw.CAPTION, false)
	_stats_panel = Panel.new()
	_stats_panel.add_theme_stylebox_override("panel", _panel_style())
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats_panel)
	for caption in ["SCORE", "LINES", "LEVEL", "BEST"]:
		_captions.append(_make_label(caption, RetroDraw.CAPTION, false))
		_values.append(_make_label("0", RetroDraw.TEXT, true))
	_award = _make_label("", RetroDraw.ACCENT, true)
	_award.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func bind(session: GameSession, save: SaveData) -> void:
	_session = session
	_save = save
	_refresh()


func apply_layout(layout: GameLayout) -> void:
	_hold_caption.visible = layout.show_hold
	_hold_caption.position = layout.hold_caption_pos
	_next_caption.position = layout.next_caption_pos
	var caption_size: int = maxi(14, layout.stat_font_size - 1)
	_hold_caption.add_theme_font_size_override("font_size", caption_size)
	_next_caption.add_theme_font_size_override("font_size", caption_size)
	var block: float = layout.stat_block_height()
	var rect: Rect2 = layout.stats_rect
	_stats_panel.position = rect.position
	_stats_panel.size = rect.size
	var text_width: float = rect.size.x - 2.0 * GameLayout.STATS_PADDING
	for i in range(GameLayout.STAT_COUNT):
		var top: float = rect.position.y + GameLayout.STATS_PADDING + i * block
		_captions[i].add_theme_font_size_override("font_size", caption_size)
		_captions[i].position = Vector2(rect.position.x + GameLayout.STATS_PADDING, top)
		_values[i].add_theme_font_size_override("font_size", layout.stat_font_size + 8)
		_values[i].position = Vector2(rect.position.x + GameLayout.STATS_PADDING, top + caption_size * 1.35)
		_values[i].custom_minimum_size.x = text_width
		_values[i].size.x = text_width
		_values[i].clip_text = true
	_award.add_theme_font_size_override("font_size", layout.award_font_size)
	_award.position = layout.award_rect.position
	_award.size = layout.award_rect.size


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _session == null or _save == null or _award == null:
		return
	_values[0].text = str(_session.stats.score)
	_values[1].text = str(_session.stats.lines)
	_values[2].text = str(_session.stats.level)
	_values[3].text = str(maxi(_save.high_score, _session.stats.score))
	_award.text = _session.last_lock.describe() if _session.last_lock != null else ""


func _make_label(text: String, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", RetroFont.bold())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Same look as RetroDraw.draw_panel, as a StyleBox for Control nodes.
static func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = RetroDraw.PANEL_FILL
	box.set_border_width_all(3)
	box.border_color = RetroDraw.PANEL_BORDER
	box.anti_aliasing = false
	return box
