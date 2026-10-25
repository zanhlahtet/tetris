extends RefCounted

var t: Object


func test_line_clear_points_level_one() -> void:
	var expected := {1: 100, 2: 300, 3: 500, 4: 800}
	for n in expected:
		var k := ScoreKeeper.new()
		t.check_eq(k.add_line_clear(n), expected[n], "%d lines awarded" % n)
		t.check_eq(k.score, expected[n], "%d lines score" % n)
		t.check_eq(k.lines, n, "%d lines total" % n)


func test_points_scale_with_level() -> void:
	var k := ScoreKeeper.new()
	k.level = 3
	k.add_line_clear(4)
	t.check_eq(k.score, 2400, "800 x level 3")


func test_drop_points() -> void:
	var k := ScoreKeeper.new()
	k.add_soft_drop(7)
	k.add_hard_drop(10)
	t.check_eq(k.score, 7 + 20, "1 per soft, 2 per hard cell")


func test_level_up_every_ten_lines() -> void:
	var k := ScoreKeeper.new()
	t.check_eq(k.level, 1, "starts at 1")
	for i in range(9):
		k.add_line_clear(1)
	t.check_eq(k.level, 1, "9 lines")
	k.add_line_clear(1)
	t.check_eq(k.level, 2, "10 lines")
	for i in range(10):
		k.add_line_clear(1)
	t.check_eq(k.level, 3, "20 lines")


func test_clear_scored_at_level_before_clear() -> void:
	var k := ScoreKeeper.new()
	for i in range(9):
		k.add_line_clear(1)
	var before := k.score
	k.add_line_clear(4)  # 9 -> 13 lines, crosses into level 2
	t.check_eq(k.score - before, 800, "paid at level 1")
	t.check_eq(k.level, 2, "now level 2")
	t.check_eq(k.lines, 13, "13 lines")
	var next := k.score
	k.add_line_clear(1)
	t.check_eq(k.score - next, 200, "next clear paid at level 2")


func test_gravity_curve() -> void:
	t.check_eq(Gravity.interval_ms(1), 1000, "level 1")
	t.check_eq(Gravity.interval_ms(2), 793, "level 2")
	t.check_eq(Gravity.interval_ms(5), 355, "level 5")
	t.check_eq(Gravity.interval_ms(10), 64, "level 10")
	t.check_eq(Gravity.interval_ms(15), 7, "level 15")
	for level in range(2, 16):
		t.check(Gravity.interval_ms(level) < Gravity.interval_ms(level - 1), "level %d faster" % level)
	t.check_eq(Gravity.interval_ms(30), Gravity.interval_ms(15), "clamped past 15")
	t.check_eq(Gravity.interval_ms(0), 1000, "clamped below 1")
