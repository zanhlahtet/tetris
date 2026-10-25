class_name GameLayout
extends RefCounted
## Pure screen layout. Given the usable (safe-area) rectangle in viewport
## coordinates it computes where every element goes, so the arrangement adapts
## to any aspect ratio and is testable without rendering.
##
## Portrait stack, top to bottom inside a content column (max 720 wide,
## centred): board flanked by a left column (hold + stats) and a right column
## (next + pause), then the touch-control block pinned to the bottom. The board
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

var cell_size: int = 0
var board_rect: Rect2
var controls_rect: Rect2
var preview_cell: int = 0
var hold_caption_pos: Vector2
var hold_rect: Rect2
var next_caption_pos: Vector2
var next_rect: Rect2
var stats_rect: Rect2
var stat_font_size: int = 0
var pause_rect: Rect2
## Touch button rectangles keyed by Input Map action name.
var buttons: Dictionary = {}


static func compute(safe: Rect2) -> GameLayout:
	var l := GameLayout.new()
	var width: float = minf(safe.size.x, MAX_CONTENT_WIDTH)
	var x0: float = safe.position.x + (safe.size.x - width) / 2.0
	var y0: float = safe.position.y
	var height: float = safe.size.y

	var controls_h: float = clampf(height * 0.2, 150.0, 250.0)
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
	l.stats_rect = Rect2(left_x, l.hold_rect.end.y + PANEL_GAP, inner, 3.0 * l.stat_block_height())

	l.next_caption_pos = Vector2(right_x, board_pos.y)
	l.next_rect = Rect2(right_x, board_pos.y + CAPTION_HEIGHT, 4.0 * pc, 15.0 * pc)
	l.pause_rect = Rect2(right_x, l.next_rect.end.y + PANEL_GAP, inner, PAUSE_HEIGHT)

	var cy: float = y0 + height - BOTTOM_MARGIN - controls_h
	l.controls_rect = Rect2(x0, cy, width, controls_h)
	var cluster_w: float = (width - 2.0 * SIDE_MARGIN - GAP) / 2.0
	var half: float = (cluster_w - GAP) / 2.0
	var row_h: float = (controls_h - GAP) / 2.0
	var lx: float = x0 + SIDE_MARGIN
	var rx: float = lx + cluster_w + GAP
	var row2: float = cy + row_h + GAP
	l.buttons = {
		&"move_left": Rect2(lx, cy, half, row_h),
		&"move_right": Rect2(lx + half + GAP, cy, half, row_h),
		&"soft_drop": Rect2(lx, row2, cluster_w, row_h),
		&"rotate_ccw": Rect2(rx, cy, half, row_h),
		&"rotate_cw": Rect2(rx + half + GAP, cy, half, row_h),
		&"hold": Rect2(rx, row2, half, row_h),
		&"hard_drop": Rect2(rx + half + GAP, row2, half, row_h),
		&"pause": l.pause_rect,
	}
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
