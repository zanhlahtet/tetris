class_name GameLayout
extends RefCounted
## Pure screen layout. Given the usable (safe-area) rectangle in viewport
## coordinates it computes where every element goes, so the arrangement adapts
## to any aspect ratio and is testable without rendering.
##
## Portrait stack, top to bottom inside a content column (max 720 wide,
## centred): board flanked by a left column (hold + stats) and a right column
## (next + pause), then the controller block pinned to the bottom: D-pad on the
## left, HOLD/DROP pills in the middle, diagonal face buttons on the right. The board
## is the largest square-celled grid that fits; leftover space is split around it.

const MAX_CONTENT_WIDTH: float = 720.0
const TOP_MARGIN: float = 12.0
const BOTTOM_MARGIN: float = 12.0
const GAP: float = 12.0
const SIDE_MARGIN: float = 8.0
const MIN_COLUMN_WIDTH: float = 112.0
const CAPTION_HEIGHT: float = 30.0
const PANEL_GAP: float = 24.0
const MAX_PREVIEW_CELL: int = 32
const PAUSE_HEIGHT: float = 64.0
## Score, lines, level, best.
const STAT_COUNT: int = 4
## Lines of text reserved for the last-lock award (action, B2B, combo, perfect clear).
const AWARD_LINES: int = 6
## Controller block: inner padding, D-pad edge as a fraction of the content
## width, and face-button diameter as a fraction of the D-pad edge.
const CONTROLS_PADDING: float = 20.0
## Space between the middle pills and the side clusters, wide enough that the
## prominent DROP button is not hit by a stray thumb meant for a face button.
const CLUSTER_GAP: float = 28.0
const DPAD_WIDTH_FRACTION: float = 0.31
const FACE_DIAMETER_FRACTION: float = 0.48
## Buttons drawn and hit-tested as circles inscribed in their rectangle.
const ROUND_ACTIONS: Array[StringName] = [&"rotate_ccw", &"rotate_cw"]

var cell_size: int = 0
var board_rect: Rect2
var controls_rect: Rect2
var preview_cell: int = 0
var hold_caption_pos: Vector2
var hold_rect: Rect2
var next_caption_pos: Vector2
var next_rect: Rect2
var stats_rect: Rect2
var award_rect: Rect2
var award_font_size: int = 0
var stat_font_size: int = 0
var pause_rect: Rect2
## Bounding squares of the D-pad cross and of the face-button cluster.
var dpad_rect: Rect2
var face_rect: Rect2
## Touch button rectangles keyed by Input Map action name.
var buttons: Dictionary = {}


static func compute(safe: Rect2) -> GameLayout:
	var l := GameLayout.new()
	var width: float = minf(safe.size.x, MAX_CONTENT_WIDTH)
	var x0: float = safe.position.x + (safe.size.x - width) / 2.0
	var y0: float = safe.position.y
	var height: float = safe.size.y

	var controls_h: float = clampf(height * 0.2, 200.0, 290.0)
	var avail_h: float = height - TOP_MARGIN - GAP - controls_h - BOTTOM_MARGIN
	var avail_w: float = width - 2.0 * MIN_COLUMN_WIDTH
	l.cell_size = maxi(8, int(floorf(minf(avail_w / Board.WIDTH, avail_h / Board.VISIBLE_ROWS))))

	var board_size := Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * l.cell_size
	var board_pos := Vector2(
			x0 + (width - board_size.x) / 2.0,
			y0 + TOP_MARGIN + (avail_h - board_size.y) / 2.0)
	l.board_rect = Rect2(board_pos, board_size)

	var col_w: float = (width - board_size.x) / 2.0
	var inner: float = col_w - 2.0 * SIDE_MARGIN
	var left_x: float = x0 + SIDE_MARGIN
	var right_x: float = x0 + width - col_w + SIDE_MARGIN
	l.preview_cell = clampi(int(inner / 4.0), 10, MAX_PREVIEW_CELL)
	var pc: float = l.preview_cell

	l.hold_caption_pos = Vector2(left_x, board_pos.y)
	l.hold_rect = Rect2(left_x, board_pos.y + CAPTION_HEIGHT, 4.0 * pc, 3.0 * pc)
	l.stat_font_size = clampi(int(inner / 5.0), 14, 34)
	l.stats_rect = Rect2(left_x, l.hold_rect.end.y + PANEL_GAP, inner, STAT_COUNT * l.stat_block_height())

	l.award_font_size = maxi(12, l.stat_font_size - 4)
	l.award_rect = Rect2(left_x, l.stats_rect.end.y + PANEL_GAP / 2.0, inner, AWARD_LINES * l.award_font_size * 1.3)

	l.next_caption_pos = Vector2(right_x, board_pos.y)
	l.next_rect = Rect2(right_x, board_pos.y + CAPTION_HEIGHT, 4.0 * pc, 15.0 * pc)
	l.pause_rect = Rect2(right_x, l.next_rect.end.y + PANEL_GAP, inner, PAUSE_HEIGHT)

	var cy: float = y0 + height - BOTTOM_MARGIN - controls_h
	l.controls_rect = Rect2(x0, cy, width, controls_h)
	var d: float = minf(width * DPAD_WIDTH_FRACTION, controls_h - 2.0 * CONTROLS_PADDING)
	var top: float = cy + (controls_h - d) / 2.0
	l.dpad_rect = Rect2(x0 + CONTROLS_PADDING, top, d, d)
	# Hit zones, not the drawn arms: left/right share the centre line so there is
	# no dead zone between them, and the up arm is deliberately inert.
	var dx: float = l.dpad_rect.position.x
	var band_top: float = top + 0.22 * d
	var band_end: float = top + 0.62 * d
	l.buttons[&"move_left"] = Rect2(dx, band_top, 0.5 * d, band_end - band_top)
	l.buttons[&"move_right"] = Rect2(dx + 0.5 * d, band_top, 0.5 * d, band_end - band_top)
	l.buttons[&"soft_drop"] = Rect2(dx + 0.25 * d, band_end, 0.5 * d, top + d - band_end)

	# Face buttons sit on a diagonal inside a box the size of the D-pad; their
	# bounding squares touch at most, so the circles never overlap.
	var fx: float = x0 + width - CONTROLS_PADDING - d
	var c: float = FACE_DIAMETER_FRACTION * d
	l.face_rect = Rect2(fx, top, d, d)
	l.buttons[&"rotate_ccw"] = Rect2(fx, top + d - c, c, c)
	l.buttons[&"rotate_cw"] = Rect2(fx + d - c, top, c, c)

	# HOLD (smaller) above DROP (larger) in the column between the two clusters.
	var mid_x: float = l.dpad_rect.end.x + CLUSTER_GAP
	var mid_w: float = l.face_rect.position.x - CLUSTER_GAP - mid_x
	var hold_h: float = clampf(controls_h * 0.22, 56.0, 64.0)
	var drop_h: float = clampf(controls_h * 0.36, 72.0, 110.0)
	var mid_top: float = cy + (controls_h - hold_h - GAP - drop_h) / 2.0
	var hold_w: float = mid_w * 0.75
	l.buttons[&"hold"] = Rect2(mid_x + (mid_w - hold_w) / 2.0, mid_top, hold_w, hold_h)
	l.buttons[&"hard_drop"] = Rect2(mid_x, mid_top + hold_h + GAP, mid_w, drop_h)
	l.buttons[&"pause"] = l.pause_rect
	return l


## Height of one stat entry (caption line + value line) in the left column.
func stat_block_height() -> float:
	return stat_font_size * 3.4


## Converts the platform's safe-area rectangle (window pixels) into viewport
## coordinates, clipped to the viewport. With the stretch mode used here the
## viewport covers the whole window, so one uniform scale applies.
static func safe_rect_in_viewport(screen_safe: Rect2, window_size: Vector2, viewport_size: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return viewport_rect
	var scale: float = window_size.x / viewport_size.x
	var converted := Rect2(screen_safe.position / scale, screen_safe.size / scale)
	var clipped := viewport_rect.intersection(converted)
	return clipped if clipped.has_area() else viewport_rect
