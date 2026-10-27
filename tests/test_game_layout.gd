extends RefCounted

var t: Object

## Smallest cell the layout may fall back to on the shortest representative
## usable area (1020 px tall); the rest stay well above it.
const MIN_CELL: int = 26
const MIN_BUTTON_SIZE: float = 56.0


## Representative usable areas in viewport coordinates: base portrait, taller
## phones, tablets, ultra-wide windows, and phones with notch/home-bar insets.
func _safe_rects() -> Array[Rect2]:
	return [
		Rect2(0, 0, 720, 1280),
		Rect2(0, 0, 720, 1560),
		Rect2(0, 0, 720, 1700),
		Rect2(0, 0, 960, 1280),
		Rect2(0, 0, 1280, 1280),
		Rect2(0, 0, 2275, 1280),
		Rect2(0, 100, 720, 1110),
		Rect2(0, 130, 720, 1020),
		Rect2(40, 0, 640, 1280),
		Rect2(0, 60, 720, 1500),
	]


func _named_rects(l: GameLayout) -> Dictionary:
	var rects := {
		"board": l.board_rect, "hud": l.hud_rect,
		"next": l.next_rect, "pause": l.pause_rect, "award": l.award_rect,
		"next_caption": l.next_caption_rect,
	}
	if l.show_hold:
		rects["hold"] = l.hold_rect
		rects["hold_caption"] = l.hold_caption_rect
	for action: StringName in l.buttons:
		if action != &"pause":
			rects["btn_" + action] = l.buttons[action]
	return rects


func test_everything_inside_safe_area() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		var rects := _named_rects(l)
		rects["controls"] = l.controls_rect
		for name in rects:
			t.check(safe.encloses(rects[name]), "%s inside %s (%s)" % [name, safe, rects[name]])


func test_no_overlaps() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		var rects := _named_rects(l)
		var names := rects.keys()
		for i in range(names.size()):
			for j in range(i + 1, names.size()):
				t.check(not (rects[names[i]] as Rect2).grow(-0.01).intersects(rects[names[j]]),
						"%s vs %s overlap in %s" % [names[i], names[j], safe])


func test_board_is_the_visual_focus() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		t.check(l.cell_size >= MIN_CELL, "cell size %d in %s" % [l.cell_size, safe])
		t.check_eq(l.board_rect.size, Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * l.cell_size, "board is whole cells")
		var area := l.board_rect.get_area()
		for name in ["hold", "hud", "next", "pause"]:
			# 3x (was 4x for the 20-row board): the 24-row board is narrower on short screens.
			t.check(area > 3.0 * (_named_rects(l)[name] as Rect2).get_area(), "board dominates %s in %s" % [name, safe])


func test_base_resolution_cell_size() -> void:
	var l := GameLayout.compute(Rect2(0, 0, 720, 1280))
	t.check_eq(l.cell_size, 36, "36px cells at 720x1280 below the HUD")
	t.check_eq(l.board_rect.size, Vector2(360, 864), "10 x 24 cells")


func test_board_is_24_rows_tall() -> void:
	t.check_eq(Board.VISIBLE_ROWS, 24, "24 visible rows")
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		t.check_eq(int(l.board_rect.size.y) / l.cell_size, 24, "24 rows drawn in %s" % safe)
		t.check_eq(int(l.board_rect.size.x) / l.cell_size, 10, "10 columns drawn in %s" % safe)


func test_hud_sits_just_below_the_top_inset_and_spans_the_width() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		var content_w: float = minf(safe.size.x, GameLayout.MAX_CONTENT_WIDTH)
		t.check_eq(l.hud_rect.position.y, safe.position.y + GameLayout.HUD_TOP_MARGIN, "HUD top margin in %s" % safe)
		t.check(safe.encloses(l.hud_rect), "HUD inside the safe area %s" % safe)
		t.check(l.hud_rect.size.x >= content_w * 0.9, "HUD uses nearly the full width in %s: %s" % [safe, l.hud_rect.size.x])
		t.check(absf(l.hud_rect.get_center().x - safe.get_center().x) < 1.0, "HUD centred in %s" % safe)
		t.check(l.hud_rect.size.y <= 90.0, "HUD stays compact in %s: %s" % [safe, l.hud_rect.size.y])


func test_hud_has_four_equal_sections() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		t.check_eq(l.stat_rects.size(), 4, "four sections")
		var x: float = l.hud_rect.position.x
		for section in l.stat_rects:
			t.check(absf(section.size.x - l.hud_rect.size.x / 4.0) < 0.01, "equal width in %s" % safe)
			t.check(absf(section.position.x - x) < 0.01, "sections tile the HUD in %s" % safe)
			t.check_eq(section.size.y, l.hud_rect.size.y, "full height")
			x += section.size.x
		t.check(l.caption_font_size < l.stat_font_size, "captions smaller than values")


func test_consistent_gaps_between_hud_board_and_controller() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		var above: float = l.board_rect.position.y - l.hud_rect.end.y
		var below: float = l.controls_rect.position.y - l.board_rect.end.y
		t.check(above >= GameLayout.GAP and below >= GameLayout.GAP, "minimum gaps in %s (%s, %s)" % [safe, above, below])
		t.check(absf(above - below) <= 2.0, "spare height split evenly in %s (%s vs %s)" % [safe, above, below])


func test_next_is_centred_beside_the_board() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		var next_panel: Rect2 = l.next_rect.grow(PiecePreview.PANEL_PADDING)
		t.check(absf(l.next_rect.get_center().y - l.board_rect.get_center().y) <= 1.0, "NEXT vertically centred on the board in %s" % safe)
		# Right column: from the board's right edge to the content column's edge.
		var content_right: float = safe.get_center().x + minf(safe.size.x, GameLayout.MAX_CONTENT_WIDTH) / 2.0
		var column_center_x: float = (l.board_rect.end.x + content_right) / 2.0
		t.check(absf(l.next_rect.get_center().x - column_center_x) <= 1.0, "NEXT centred in its column in %s" % safe)
		t.check(next_panel.position.x >= l.board_rect.end.x and next_panel.end.x <= safe.end.x, "NEXT panel stays beside the board in %s" % safe)
		t.check(l.next_rect.size.y == GameSession.PREVIEW_COUNT * 3.0 * l.preview_cell, "all %d previews fit" % GameSession.PREVIEW_COUNT)
		t.check(l.preview_cell <= int(l.cell_size * GameLayout.PREVIEW_CELL_FRACTION) or l.preview_cell == 10, "NEXT stays secondary to the board in %s" % safe)
		# The caption sits above the panel and is centred over it.
		t.check(l.next_caption_rect.end.y <= next_panel.position.y + 0.01, "caption above NEXT in %s" % safe)
		t.check(absf(l.next_caption_rect.get_center().x - next_panel.get_center().x) <= 1.0, "caption centred over NEXT in %s" % safe)
		t.check(l.next_caption_rect.position.y >= l.hud_rect.end.y, "caption clear of the HUD in %s" % safe)


func test_award_text_is_beside_the_board_not_over_it() -> void:
	for safe in _safe_rects():
		for hold in [true, false]:
			var l := GameLayout.compute(safe, hold)
			t.check(l.award_rect.end.x <= l.board_rect.position.x, "award left of the board in %s" % safe)
			t.check(l.award_rect.position.y >= l.board_rect.position.y - 0.01 and l.award_rect.end.y <= l.board_rect.end.y + 0.01, "award within the board's height in %s hold=%s" % [safe, hold])
			if hold:
				t.check(l.award_rect.position.y >= l.hold_rect.end.y, "award below HOLD in %s" % safe)


func test_board_and_controller_separate_on_short_and_tall_iphones() -> void:
	# Viewport-space safe areas for short, standard and tall iPhone shapes.
	var phones: Array[Rect2] = [Rect2(0, 0, 720, 1280), Rect2(0, 48, 720, 1430), Rect2(0, 54, 720, 1578), Rect2(0, 62, 720, 1650)]
	for safe in phones:
		var l := GameLayout.compute(safe, false)
		t.check(safe.encloses(l.board_rect), "board inside the safe area %s" % safe)
		t.check(l.board_rect.end.y + GameLayout.GAP <= l.controls_rect.position.y + 0.01, "gap between board and controller in %s" % safe)
		t.check(safe.encloses(l.controls_rect), "controller inside the safe area %s" % safe)
		t.check(l.cell_size >= MIN_CELL, "cells stay playable in %s: %d" % [safe, l.cell_size])
		t.check_eq(l.board_rect.size, Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * l.cell_size, "uniform cells, no cropping in %s" % safe)


func test_side_columns_stay_above_the_controller() -> void:
	for safe in _safe_rects():
		for hold in [true, false]:
			var l := GameLayout.compute(safe, hold)
			t.check(l.award_rect.end.y <= l.controls_rect.position.y, "award text clears the controller in %s hold=%s" % [safe, hold])
			t.check(l.next_rect.end.y <= l.controls_rect.position.y, "next preview clears the controller in %s" % safe)


func test_short_screens_shrink_cells_uniformly() -> void:
	var tall := GameLayout.compute(Rect2(0, 0, 720, 1280))
	var short := GameLayout.compute(Rect2(0, 0, 720, 1100))
	t.check(short.cell_size < tall.cell_size, "shorter screen gets smaller cells")
	t.check_eq(short.board_rect.size.x / 10.0, short.board_rect.size.y / 24.0, "cells stay square")


func test_board_centered_horizontally() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		t.check(absf(l.board_rect.get_center().x - safe.get_center().x) < 1.0, "centred in %s" % safe)


func test_touch_targets_are_large_enough() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		for action: StringName in l.buttons:
			var size: Vector2 = (l.buttons[action] as Rect2).size
			t.check(size.x >= MIN_BUTTON_SIZE and size.y >= MIN_BUTTON_SIZE, "%s is %s in %s" % [action, size, safe])


func test_all_actions_have_buttons() -> void:
	var l := GameLayout.compute(Rect2(0, 0, 720, 1280))
	for action in [&"move_left", &"move_right", &"soft_drop", &"rotate_ccw", &"pause"]:
		t.check(l.buttons.has(action), "button for %s" % action)
		t.check(InputMap.has_action(action), "%s is an Input Map action" % action)
	t.check_eq(l.buttons.size(), 5, "no other touch buttons")
	t.check(not l.buttons.has(&"rotate_cw"), "no O button")
	t.check(InputMap.has_action(&"rotate_cw"), "clockwise stays a keyboard action")


func test_controls_sit_below_the_board_and_split_by_hand() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe)
		t.check(l.board_rect.end.y <= l.controls_rect.position.y, "board above controls in %s" % safe)
		t.check((l.buttons[&"move_right"] as Rect2).end.x <= (l.buttons[&"rotate_ccw"] as Rect2).position.x, "movement left of rotation")


func test_safe_area_conversion() -> void:
	# iPhone-like: 1170x2532 window, 141px top inset, 102px bottom inset.
	var window := Vector2(1170, 2532)
	var viewport := Vector2(720, 1558.15)
	var r := GameLayout.safe_rect_in_viewport(Rect2(0, 141, 1170, 2532 - 141 - 102), window, viewport)
	t.check(absf(r.position.y - 141.0 / 1.625) < 0.01, "top inset scaled")
	t.check(absf(r.size.x - 720.0) < 0.01, "full width")
	t.check(absf(r.end.y - (2532.0 - 102.0) / 1.625) < 0.01, "bottom inset scaled")


func test_safe_area_is_clipped_and_falls_back() -> void:
	var vp := Vector2(720, 1280)
	var clipped := GameLayout.safe_rect_in_viewport(Rect2(-50, -50, 2000, 3000), Vector2(720, 1280), vp)
	t.check_eq(clipped, Rect2(Vector2.ZERO, vp), "clipped to viewport")
	t.check_eq(GameLayout.safe_rect_in_viewport(Rect2(0, 0, 100, 100), Vector2.ZERO, vp), Rect2(Vector2.ZERO, vp), "zero window falls back")
	t.check_eq(GameLayout.safe_rect_in_viewport(Rect2(0, 0, 0, 0), Vector2(720, 1280), vp), Rect2(Vector2.ZERO, vp), "empty safe area falls back")


func test_hold_panel_can_be_dropped_for_phones() -> void:
	for safe in _safe_rects():
		var l := GameLayout.compute(safe, false)
		var with_hold := GameLayout.compute(safe)
		t.check(not l.show_hold and not l.hold_rect.has_area(), "no hold panel in %s" % safe)
		t.check_eq(l.hud_rect, with_hold.hud_rect, "HUD unchanged")
		t.check_eq(l.board_rect, with_hold.board_rect, "board unchanged")
		t.check_eq(l.next_rect, with_hold.next_rect, "NEXT unchanged")


# --- full-screen rendering --------------------------------------------------

func test_project_stretches_with_expand_so_nothing_is_letterboxed() -> void:
	t.check_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "scales with the window")
	t.check_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "extra screen becomes viewport, not black bars")
	t.check_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "portrait")
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	t.check(clear.is_equal_approx(RetroDraw.BACKGROUND), "the clear colour is the navy background: it fills notch and home-indicator areas")


func test_layout_fills_tall_iphone_viewports_inside_the_safe_area() -> void:
	# Windows 1179x2556 / 1290x2796 / 750x1334, with iPhone-like insets.
	var cases: Array = [
		[Vector2(1179, 2556), Rect2(0, 177, 1179, 2556 - 177 - 102)],
		[Vector2(1290, 2796), Rect2(0, 177, 1290, 2796 - 177 - 102)],
		[Vector2(750, 1334), Rect2(0, 40, 750, 1334 - 40)],
	]
	for case: Array in cases:
		var window: Vector2 = case[0]
		var screen_safe: Rect2 = case[1]
		# What `expand` produces: 720 wide, height from the window's aspect (no bars).
		var viewport := Vector2(720.0, 720.0 * window.y / window.x)
		var safe := GameLayout.safe_rect_in_viewport(screen_safe, window, viewport)
		t.check(absf(window.x / viewport.x - window.y / viewport.y) < 0.001, "uniform scale, nothing stretched in %s" % window)
		t.check(Rect2(Vector2.ZERO, viewport).encloses(safe), "safe area inside the viewport")
		t.check(safe.position.y > 0.0 and safe.end.y <= viewport.y, "top inset respected (and the bottom one, where there is one) in %s" % window)
		t.check(window.y != 2556.0 or safe.end.y < viewport.y, "home-indicator inset respected")
		for hold in [false, true]:
			var l := GameLayout.compute(safe, hold)
			var rects := _named_rects(l)
			rects["controls"] = l.controls_rect
			for name in rects:
				t.check(safe.encloses(rects[name]), "%s inside the safe area for %s" % [name, window])
			t.check(l.hud_rect.position.y - safe.position.y <= GameLayout.HUD_TOP_MARGIN + 0.01, "HUD hugs the top inset for %s" % window)
			t.check(safe.end.y - l.controls_rect.end.y <= GameLayout.BOTTOM_MARGIN + 0.01, "controller hugs the bottom inset for %s" % window)
			t.check_eq(l.board_rect.size, Vector2(Board.WIDTH, Board.VISIBLE_ROWS) * l.cell_size, "square cells, 10 x 24 for %s" % window)
			t.check(l.cell_size >= 34, "a big board even on the shortest phone: %d for %s" % [l.cell_size, window])


func test_layout_responds_to_resizing() -> void:
	var small := GameLayout.compute(Rect2(0, 0, 720, 1280))
	var tall := GameLayout.compute(Rect2(0, 0, 720, 1560))
	var wide := GameLayout.compute(Rect2(0, 0, 1280, 1280))
	t.check(tall.cell_size > small.cell_size, "more height, bigger cells")
	t.check(tall.controls_rect.position.y > small.controls_rect.position.y, "controller follows the bottom edge")
	t.check_eq(wide.hud_rect.size.x, 720.0 - 2.0 * GameLayout.HUD_SIDE_MARGIN, "extra width is margin, content stays 720 wide")
	t.check(absf(wide.board_rect.get_center().x - 640.0) < 1.0, "board stays centred when the viewport widens")


func test_safe_area_conversion_handles_each_axis_separately() -> void:
	var r := GameLayout.safe_rect_in_viewport(Rect2(0, 100, 1440, 2000), Vector2(1440, 2880), Vector2(720, 1440))
	t.check_eq(r, Rect2(0, 50, 720, 1000), "2x scale on both axes")
	var wide := GameLayout.safe_rect_in_viewport(Rect2(100, 0, 2000, 1280), Vector2(2560, 1280), Vector2(2560, 1280))
	t.check_eq(wide, Rect2(100, 0, 2000, 1280), "1:1 scale when the viewport was widened (expand in landscape)")
