class_name Hud
extends CanvasLayer
## HUD: the horizontal statistics panel (score, lines, level, best), the
## HOLD/NEXT captions and the last-lock award text. Positions and sizes come
## from GameLayout. Reads session state each frame; never mutates it.


## Smallest size a stat value may shrink to (still legible in the pixel font).
const MIN_VALUE_FONT_SIZE: int = 10

var _session: GameSession
var _save: SaveData
var _hold_caption: Label
var _next_caption: Label
var _stats_panel: Panel
var _dividers: Array[ColorRect] = []
var _captions: Array[Label] = []
var _values: Array[Label] = []
var _award: Label
var _value_font_size: int = 24


func _ready() -> void:
	_hold_caption = _make_label("HOLD", RetroDraw.CAPTION, false)
	_next_caption = _make_label("NEXT", RetroDraw.CAPTION, false)
	_stats_panel = Panel.new()
	_stats_panel.add_theme_stylebox_override("panel", _panel_style())
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats_panel)
	for i in range(GameLayout.STAT_COUNT - 1):
		var divider := ColorRect.new()
		divider.color = RetroDraw.PANEL_BORDER
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(divider)
		_dividers.append(divider)
	for caption in ["SCORE", "LINES", "LEVEL", "BEST"]:
		_captions.append(_make_label(caption, RetroDraw.CAPTION, false))
		_values.append(_make_label("0", RetroDraw.TEXT, true))
	_award = _make_label("", RetroDraw.ACCENT, true)
	_award.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [_hold_caption, _next_caption, _award] + _captions + _values:
		(label as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func bind(session: GameSession, save: SaveData) -> void:
	_session = session
	_save = save
	_refresh()


func apply_layout(layout: GameLayout) -> void:
	var caption_size: int = layout.caption_font_size
	_hold_caption.visible = layout.show_hold
	_place(_hold_caption, layout.hold_caption_rect, caption_size)
	_place(_next_caption, layout.next_caption_rect, caption_size)
	_value_font_size = layout.stat_font_size
	_stats_panel.position = layout.hud_rect.position
	_stats_panel.size = layout.hud_rect.size
	var inner_top: float = layout.hud_rect.position.y + GameLayout.HUD_PADDING
	var divider_h: float = layout.hud_rect.size.y - 2.0 * GameLayout.HUD_PADDING - 4.0
	for i in range(GameLayout.STAT_COUNT):
		var section: Rect2 = layout.stat_rects[i]
		# Labels span the section so their centred text sits on its midline.
		var caption_h: float = GameLayout.line_height(caption_size)
		_place(_captions[i], Rect2(section.position.x, inner_top, section.size.x, caption_h), caption_size)
		_values[i].position = Vector2(section.position.x + GameLayout.HUD_PADDING, inner_top + caption_h)
		_values[i].size = Vector2(section.size.x - 2.0 * GameLayout.HUD_PADDING, GameLayout.line_height(_value_font_size))
	for i in range(_dividers.size()):
		var x: float = layout.stat_rects[i + 1].position.x
		_dividers[i].position = Vector2(x - 1.0, inner_top + 2.0)
		_dividers[i].size = Vector2(2.0, divider_h)
	_place(_award, layout.award_rect, layout.award_font_size)


func _place(label: Label, rect: Rect2, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.position = rect.position
	label.size = rect.size


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _session == null or _save == null or _award == null:
		return
	var texts: Array[String] = [str(_session.stats.score), str(_session.stats.lines),
			str(_session.stats.level), str(maxi(_save.high_score, _session.stats.score))]
	for i in range(texts.size()):
		_values[i].text = texts[i]
		_values[i].add_theme_font_size_override("font_size",
				fit_font_size(RetroFont.bold(), texts[i], _value_font_size, _values[i].size.x))
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


## Largest font size (at most `base`, at least MIN_VALUE_FONT_SIZE) at which
## `text` fits in `width`, so long numbers shrink instead of being cut off.
static func fit_font_size(font: Font, text: String, base: int, width: float) -> int:
	var size: int = base
	while size > MIN_VALUE_FONT_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size
