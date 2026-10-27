extends RefCounted
## Score-based gravity: the table, its use by GameSession, and the large-score HUD fit.

var t: Object

const EXPECTED: Array = [
	[0, 1000], [1249, 1000], [1250, 850], [3749, 850], [3750, 700], [7499, 700],
	[7500, 550], [12499, 550], [12500, 430], [18749, 430], [18750, 340], [27499, 340],
	[27500, 270], [37499, 270], [37500, 240], [49999, 240], [50000, 210], [68749, 210],
	[68750, 190], [93749, 190], [93750, 170], [93751, 170], [1000000, 170],
]


func _session() -> GameSession:
	var s := GameSession.new(1, true)
	s.spawn_next()
	s.active = ActivePiece.new(Tetromino.Type.O)
	return s


func _rows_fallen(s: GameSession, total_ms: int, step: int) -> int:
	var y0: int = s.active.origin.y
	var left: int = total_ms
	while left > 0:
		s.tick(mini(step, left))
		left -= step
	return s.active.origin.y - y0


func test_table_values() -> void:
	for pair in EXPECTED:
		t.check_eq(Gravity.interval_for_score(pair[0]), pair[1], "score %d" % pair[0])
	t.check_eq(Gravity.interval_for_score(-50), 1000, "negative score clamps to the start")


func test_table_shape_and_cap() -> void:
	t.check_eq(Gravity.TABLE[0], Vector2i(0, 1000), "starts at 1000 ms")
	t.check_eq(Gravity.TABLE.back().y, Gravity.MIN_INTERVAL_MS, "last row is the cap")
	for i in range(1, Gravity.TABLE.size()):
		t.check(Gravity.TABLE[i].x > Gravity.TABLE[i - 1].x, "thresholds ascend at %d" % i)
		t.check(Gravity.TABLE[i].y < Gravity.TABLE[i - 1].y, "speed rises at %d" % i)
	for score in range(0, 120000, 250):
		t.check(Gravity.interval_for_score(score) >= Gravity.MIN_INTERVAL_MS, "never faster than the cap at %d" % score)


func test_never_gets_easier_as_score_rises() -> void:
	var previous: int = Gravity.interval_for_score(0)
	for score in range(0, 200000, 97):
		var now: int = Gravity.interval_for_score(score)
		t.check(now <= previous, "interval did not rise at %d" % score)
		previous = now


func test_session_uses_run_score_not_level_or_best() -> void:
	var s := _session()
	t.check_eq(s.gravity_interval_ms(), 1000, "fresh run")
	s.stats.score = 4000
	t.check_eq(s.gravity_interval_ms(), 700, "follows the run's score")
	s.stats.lines = 90
	s.stats.level = 10
	s.stats.score = 0
	t.check_eq(s.gravity_interval_ms(), 1000, "a high LEVEL alone does not speed gravity")


func test_level_still_follows_lines() -> void:
	var k := ScoreKeeper.new()
	for lines in [0, 9, 10, 19, 20, 99, 100]:
		k.lines = lines
		k.register_lock(0, TSpin.Kind.NONE, false)
		t.check_eq(k.level, 1 + lines / 10, "level at %d lines" % lines)


func test_restart_resets_difficulty() -> void:
	var s := _session()
	s.stats.score = 100000
	t.check_eq(s.gravity_interval_ms(), 170, "fast")
	s.restart(1, true)
	t.check_eq(s.gravity_interval_ms(), 1000, "restart returns to the start speed")
	var y0: int = s.active.origin.y
	s.tick(999)
	t.check_eq(s.active.origin.y, y0, "and falls at 1000 ms again")
	s.tick(1)
	t.check_eq(s.active.origin.y, y0 + 1, "one row at 1000 ms")


func test_pause_and_resume_keep_difficulty() -> void:
	var s := _session()
	s.stats.score = 13000
	var y0: int = s.active.origin.y
	s.tick(300)
	s.pause()
	s.tick(10000)
	t.check_eq(s.active.origin.y, y0, "no fall while paused")
	t.check_eq(s.gravity_interval_ms(), 430, "difficulty preserved")
	s.resume()
	s.tick(129)
	t.check_eq(s.active.origin.y, y0, "progress kept: 300+129 < 430")
	s.tick(1)
	t.check_eq(s.active.origin.y, y0 + 1, "falls once 430 ms accumulated")


func test_fall_is_frame_rate_independent_at_each_speed() -> void:
	for score in [0, 1250, 27500, 93750]:
		var results: Array[int] = []
		for step in [1, 7, 16, 17, 33, 250]:
			var s := _session()
			s.stats.score = score
			results.append(_rows_fallen(s, 2160, step))
		for r in results:
			t.check_eq(r, results[0], "score %d: same rows at every frame step" % score)
		t.check_eq(results[0], 2160 / Gravity.interval_for_score(score), "score %d: rows = time / interval" % score)


func test_speed_never_exceeds_one_row_per_170ms() -> void:
	t.check_eq(Gravity.MIN_INTERVAL_MS, 170, "cap is 170 ms per row")
	var s := _session()
	s.stats.score = 5000000
	t.check_eq(_rows_fallen(s, 1699, 1), 9, "9 rows in 1699 ms")
	t.check_eq(_rows_fallen(s, 1, 1), 1, "10th row at 1700 ms")


func test_soft_drop_at_max_speed() -> void:
	var s := _session()
	s.stats.score = 93750
	s.set_soft_drop(true)
	var y0: int = s.active.origin.y
	s.tick(80)
	t.check_eq(s.active.origin.y - y0, 10, "20x faster than 170 ms = 8 ms per row (integer ms)")
	s.set_soft_drop(false)
	var y1: int = s.active.origin.y
	s.tick(169)
	t.check_eq(s.active.origin.y, y1, "back to normal speed on release")


func test_crossing_a_threshold_mid_fall_keeps_progress() -> void:
	var s := _session()
	s.stats.score = 1249
	var y0: int = s.active.origin.y
	s.tick(500)
	s.stats.score = 1250
	s.tick(0)
	t.check_eq(s.active.origin.y, y0, "no jump when the speed changes")
	s.tick(424)
	t.check_eq(s.active.origin.y, y0, "half a row at 850 ms is 425")
	s.tick(1)
	t.check_eq(s.active.origin.y, y0 + 1, "row completes on schedule")


func test_one_big_score_crosses_several_thresholds_without_a_burst() -> void:
	var s := _session()
	var y0: int = s.active.origin.y
	s.tick(900)
	s.stats.score = 100000
	s.tick(0)
	t.check_eq(s.active.origin.y, y0, "no burst of rows")
	t.check_eq(s.gravity_interval_ms(), 170, "jumped straight to the cap")
	s.tick(16)
	t.check_eq(s.active.origin.y, y0, "progress scaled to 153 of 170 ms")
	s.tick(1)
	t.check_eq(s.active.origin.y, y0 + 1, "completes after a total of 170 ms-equivalent")


func test_hard_drop_points_count_towards_thresholds() -> void:
	var s := _session()
	s.stats.score = 1230
	s.active.origin = Vector2i(3, 19)
	s.hard_drop()  # a long drop, at 2 points per cell
	t.check(s.stats.score >= 1250, "score crossed 1250")
	t.check_eq(s.gravity_interval_ms(), 850, "gravity followed")


# --- large scores in the HUD -----------------------------------------------

func test_large_scores_fit_without_truncation() -> void:
	var font: Font = RetroFont.bold()
	for safe in [Rect2(0, 0, 720, 1280), Rect2(40, 0, 640, 1280), Rect2(0, 0, 720, 1560)]:
		var l := GameLayout.compute(safe)
		# A value label is its HUD section minus the padding either side.
		var width: float = l.stat_rects[0].size.x - 2.0 * GameLayout.HUD_PADDING
		var base: int = l.stat_font_size
		for text in ["0", "12840", "999999999", "1234567890"]:
			var size: int = Hud.fit_font_size(font, text, base, width)
			t.check(size >= Hud.MIN_VALUE_FONT_SIZE and size <= base, "%s size %d within bounds" % [text, size])
			t.check(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width, "%s fits at %d in %s" % [text, size, safe])
		t.check_eq(Hud.fit_font_size(font, "0", base, width), base, "short numbers keep the full size")
		t.check(Hud.fit_font_size(font, "999999999", base, width) >= 12, "nine digits stay legible in %s" % safe)


func test_real_hud_keeps_large_scores_inside_its_sections() -> void:
	var layout := GameLayout.compute(Rect2(0, 0, 720, 1560), false)
	var session := GameSession.new(1, true)
	session.spawn_next()
	var hud := Hud.new()
	t.root.add_child(hud)
	await t.process_frame  # lets the node enter the tree and run _ready
	hud.bind(session, SaveData.new())
	hud.apply_layout(layout)
	session.stats.score = 1234567890
	session.stats.lines = 99999
	hud._refresh()
	for i in range(GameLayout.STAT_COUNT):
		var label: Label = hud._values[i]
		var caption: Label = hud._captions[i]
		var section: Rect2 = layout.stat_rects[i]
		var text_size: Vector2 = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
		t.check(text_size.x <= label.size.x, "value %d fits its label (%s of %s)" % [i, text_size.x, label.size.x])
		t.check(section.encloses(Rect2(label.position, label.size)), "value label %d inside its section" % i)
		t.check(layout.hud_rect.encloses(Rect2(caption.position, caption.size)), "caption %d inside the HUD" % i)
		t.check(label.position.y >= caption.position.y + caption.size.y - 0.01, "value %d below its caption (caption y %s h %s, value y %s)" % [i, caption.position.y, caption.size.y, label.position.y])
		t.check_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "value %d centred" % i)
		t.check_eq(caption.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "caption %d centred" % i)
	t.check(Rect2(hud._values[0].position, hud._values[0].size).end.y <= layout.hud_rect.end.y, "values inside the HUD height")
	t.root.remove_child(hud)
	hud.free()
