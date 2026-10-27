class_name GameLayout
extends RefCounted
## Pure screen layout. Given the usable (safe-area) rectangle in viewport
## coordinates it computes where every element goes, so the arrangement adapts
## to any aspect ratio and is testable without rendering.
##
## Portrait stack, top to bottom inside a content column (max 720 wide,
## centred): a horizontal statistics HUD (SCORE, LINES, LEVEL, BEST) just below
## the top inset, then the board (10 x 24 visible cells, centred on the screen)
## flanked by a left column (hold, last-lock award) and a right column (NEXT,
## centred beside the board), then the controller block pinned to the bottom:
## D-pad on the left, PAUSE between, one large X button on the right. The board
## is the largest square-celled grid that fits; leftover height is split evenly
## between the HUD-board and board-controller gaps.

const MAX_CONTENT_WIDTH: float = 720.0
const BOTTOM_MARGIN: float = 12.0
const GAP: float = 12.0
## How far the D-pad hit zones extend past the drawn cross.
const DPAD_HIT_MARGIN: float = 10.0
## Statistics HUD: margin below the top inset, to the screen sides, inner
## padding, and its number of sections (score, lines, level, best).
const HUD_TOP_MARGIN: float = 8.0
const HUD_SIDE_MARGIN: float = 12.0
const HUD_PADDING: float = 6.0
const STAT_COUNT: int = 4
## Line height of the pixel font as a multiple of its size (the font's own
## height is about 1.33x; see line_height()).
const LINE_HEIGHT: float = 1.35
## Narrowest side column; keeps NEXT and the award text readable on tall phones.
const MIN_COLUMN_WIDTH: float = 128.0
## Padding between a side column's edge and the panel inside it.
const COLUMN_MARGIN: float = 8.0
const CAPTION_HEIGHT: float = 28.0
const PANEL_GAP: float = 24.0
const MAX_PREVIEW_CELL: int = 32
## Preview cell size is at most this fraction of the board cell, so NEXT stays
## visually secondary to the board.
const PREVIEW_CELL_FRACTION: float = 0.8
const PAUSE_HEIGHT: float = 66.0
const PAUSE_MAX_WIDTH: float = 180.0
## PAUSE width as a fraction of the gap between the D-pad and face clusters;
## the rest keeps its hit region clear of the neighbouring X button.
const PAUSE_WIDTH_FRACTION: float = 0.82
## Lines of text reserved for the last-lock award (action, B2B, combo, perfect clear).
const AWARD_LINES: int = 6
## Controller block: inner padding, D-pad edge as a fraction of the content
## width, and the X button diameter as a fraction of the face cluster's width.
const CONTROLS_PADDING: float = 12.0
## Controller block height as a fraction of the usable height, and its limits.
const CONTROLS_HEIGHT_FRACTION: float = 0.215
const CONTROLS_MIN_HEIGHT: float = 200.0
const CONTROLS_MAX_HEIGHT: float = 280.0
const DPAD_WIDTH_FRACTION: float = 0.34
const FACE_DIAMETER_FRACTION: float = 0.68
## Buttons drawn and hit-tested as circles inscribed in their rectangle.
const ROUND_ACTIONS: Array[StringName] = [&"rotate_ccw"]

var cell_size: int = 0
var board_rect: Rect2
var controls_rect: Rect2
var preview_cell: int = 0
## False on phones: the hold slot has no control there, so its panel is dropped.
var show_hold: bool = true
var hold_caption_rect: Rect2
var hold_rect: Rect2
var next_caption_rect: Rect2
var next_rect: Rect2
## The horizontal statistics panel and its four equal sections (full panel
## height each); caption and value font sizes (the value size is a maximum:
## long numbers shrink to fit).
var hud_rect: Rect2
var stat_rects: Array[Rect2] = []
var caption_font_size: int = 0
var stat_font_size: int = 0
var award_rect: Rect2
var award_font_size: int = 0
var pause_rect: Rect2
## Bounding squares of the D-pad cross and of the face-button cluster.
var dpad_rect: Rect2
var face_rect: Rect2
## Touch hit rectangles keyed by Input Map action name (the D-pad entries are
## hit zones, the others the drawn button).
var buttons: Dictionary = {}


static func compute(safe: Rect2, show_hold: bool = true) -> GameLayout:
	var l := GameLayout.new()
	l.show_hold = show_hold
	var width: float = minf(safe.size.x, MAX_CONTENT_WIDTH)
	var x0: float = safe.position.x + (safe.size.x - width) / 2.0
	var y0: float = safe.position.y
	var height: float = safe.size.y

	var controls_h: float = clampf(height * CONTROLS_HEIGHT_FRACTION, CONTROLS_MIN_HEIGHT, CONTROLS_MAX_HEIGHT)
	var cy: float = y0 + height - BOTTOM_MARGIN - controls_h

	# Statistics HUD across the top: four equal sections, caption over value.
	var hud_w: float = width - 2.0 * HUD_SIDE_MARGIN
	l.caption_font_size = clampi(int(hud_w / 45.0), 12, 18)
	l.stat_font_size = clampi(int(hud_w / 21.0), 18, 34)
	var hud_h: float = 2.0 * HUD_PADDING + line_height(l.caption_font_size) + line_height(l.stat_font_size)
	l.hud_rect = Rect2(x0 + HUD_SIDE_MARGIN, y0 + HUD_TOP_MARGIN, hud_w, hud_h)
	var section_w: float = hud_w / STAT_COUNT
	for i in range(STAT_COUNT):
		l.stat_rects.append(Rect2(l.hud_rect.position.x + i * section_w, l.hud_rect.position.y, section_w, hud_h))

	# The board takes the largest square cells that fit between the HUD and the
	# controller; whatever height is left over is split evenly into the two gaps.
	var board_top_min: float = l.hud_rect.end.y + GAP
	var avail_h: float = cy - GAP - board_top_min
	var avail_w: float = width - 2.0 * MIN_COLUMN_WIDTH
	l.cell_size = maxi(8, int(floorf(minf(avail_w / Board.WIDTH, avail_h / Board.VISIBLE_ROWS))))

	var board_size := Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * l.cell_size
	var spare: float = maxf(0.0, avail_h - board_size.y)
	# Whole pixels keep the tile edges crisp. Centred on the screen horizontally.
	var board_pos := Vector2(x0 + (width - board_size.x) / 2.0, board_top_min + spare / 2.0).floor()
	l.board_rect = Rect2(board_pos, board_size)
	var board_cy: float = l.board_rect.get_center().y

	var col_w: float = (width - board_size.x) / 2.0
	var inner: float = col_w - 2.0 * COLUMN_MARGIN
	var left_cx: float = x0 + col_w / 2.0
	var right_cx: float = x0 + width - col_w / 2.0
	var pad: float = PiecePreview.PANEL_PADDING
	var max_preview: int = maxi(10, mini(MAX_PREVIEW_CELL, int(l.cell_size * PREVIEW_CELL_FRACTION)))
	l.preview_cell = clampi(int((inner - 2.0 * pad) / 4.0), 10, max_preview)
	var pc: float = l.preview_cell

	# NEXT: centred in the right column and vertically beside the board, with its
	# caption centred over the panel (the drawn panel is `pad` larger all round).
	l.next_rect = Rect2(Vector2(right_cx - 2.0 * pc, board_cy - 7.5 * pc).floor(), Vector2(4.0 * pc, 15.0 * pc))
	l.next_caption_rect = Rect2(l.next_rect.position.x - pad, l.next_rect.position.y - pad - CAPTION_HEIGHT, 4.0 * pc + 2.0 * pad, CAPTION_HEIGHT)

	# HOLD (desktop only): top of the left column, level with the board's top.
	var left_bottom: float = board_pos.y
	if show_hold:
		l.hold_caption_rect = Rect2(left_cx - 2.0 * pc - pad, board_pos.y, 4.0 * pc + 2.0 * pad, CAPTION_HEIGHT)
		l.hold_rect = Rect2((Vector2(left_cx - 2.0 * pc, board_pos.y + CAPTION_HEIGHT + pad)).floor(), Vector2(4.0 * pc, 3.0 * pc))
		left_bottom = l.hold_rect.end.y + pad + PANEL_GAP

	# Last-lock award text: left column, centred beside the board (below HOLD
	# when that is shown), well clear of the controller.
	l.award_font_size = clampi(int(inner / 7.0), 12, 24)
	var award_h: float = AWARD_LINES * line_height(l.award_font_size)
	var award_y: float = clampf(board_cy - award_h / 2.0, left_bottom, maxf(left_bottom, l.board_rect.end.y - award_h))
	l.award_rect = Rect2(floorf(x0 + COLUMN_MARGIN), floorf(award_y), inner, award_h)

	l.controls_rect = Rect2(x0, cy, width, controls_h)
	var d: float = minf(width * DPAD_WIDTH_FRACTION, controls_h - 2.0 * CONTROLS_PADDING)
	var top: float = cy + (controls_h - d) / 2.0
	l.dpad_rect = Rect2(x0 + CONTROLS_PADDING, top, d, d)
	# Hit zones, not the drawn arms: they reach DPAD_HIT_MARGIN beyond the cross
	# on the outer sides, left/right share the centre line (no dead zone, no
	# overlap), and the up arm is deliberately inert.
	var dx: float = l.dpad_rect.position.x
	var m: float = DPAD_HIT_MARGIN
	var band_top: float = top + 0.2 * d
	var band_end: float = top + 0.62 * d
	l.buttons[&"move_left"] = Rect2(dx - m, band_top - m, 0.5 * d + m, band_end - band_top + m)
	l.buttons[&"move_right"] = Rect2(dx + 0.5 * d, band_top - m, 0.5 * d + m, band_end - band_top + m)
	l.buttons[&"soft_drop"] = Rect2(dx + 0.2 * d, band_end, 0.6 * d, top + d + m - band_end)

	# The single X button is centred in a box the size of the D-pad (the midpoint
	# of where the old X and O sat).
	var fx: float = x0 + width - CONTROLS_PADDING - d
	var c: float = FACE_DIAMETER_FRACTION * d
	l.face_rect = Rect2(fx, top, d, d)
	l.buttons[&"rotate_ccw"] = Rect2(l.face_rect.get_center() - Vector2(c, c) / 2.0, Vector2(c, c))

	# Start-style PAUSE pill in the gap between the clusters, a little low like
	# the Start/Select buttons of a real pad.
	var mid_x: float = l.dpad_rect.end.x
	var mid_w: float = l.face_rect.position.x - mid_x
	var pause_w: float = minf(PAUSE_MAX_WIDTH, mid_w * PAUSE_WIDTH_FRACTION)
	l.pause_rect = Rect2(mid_x + (mid_w - pause_w) / 2.0, cy + controls_h * 0.56, pause_w, PAUSE_HEIGHT)
	l.buttons[&"pause"] = l.pause_rect
	return l


## Whole-pixel height of one line of text at `font_size`, never less than the
## font's own line height, so stacked labels cannot overlap.
static func line_height(font_size: int) -> float:
	return ceilf(font_size * LINE_HEIGHT)


## Converts the platform's safe-area rectangle (window pixels) into viewport
## coordinates, clipped to the viewport. With stretch mode `canvas_items` and
## aspect `expand` the viewport covers the whole window (no letterbox bars), so
## both axes share one scale; each axis is still converted with its own ratio so
## a mismatch could never shift the result.
static func safe_rect_in_viewport(screen_safe: Rect2, window_size: Vector2, viewport_size: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	if window_size.x <= 0.0 or window_size.y <= 0.0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return viewport_rect
	var scale := Vector2(window_size.x / viewport_size.x, window_size.y / viewport_size.y)
	var converted := Rect2(screen_safe.position / scale, screen_safe.size / scale)
	var clipped := viewport_rect.intersection(converted)
	return clipped if clipped.has_area() else viewport_rect
