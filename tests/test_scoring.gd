extends RefCounted

var t: Object

const NONE := TSpin.Kind.NONE
const MINI := TSpin.Kind.MINI
const FULL := TSpin.Kind.FULL


## Registers a clear, then a lock with no clear so the combo chain restarts.
## (Back-to-Back is unaffected by the reset lock.)
func _isolated(k: ScoreKeeper, line_count: int, spin: int = NONE, perfect: bool = false) -> int:
	var points := k.register_lock(line_count, spin, perfect).points
	k.register_lock(0, NONE, false)
	return points


func test_plain_line_clear_points() -> void:
	var expected := {1: 100, 2: 300, 3: 500, 4: 800}
	for n in expected:
		var k := ScoreKeeper.new()
		var r := k.register_lock(n, NONE, false)
		t.check_eq(r.points, expected[n], "%d lines awarded" % n)
		t.check_eq(k.score, expected[n], "%d lines score" % n)
		t.check_eq(k.lines, n, "%d lines total" % n)


func test_no_clear_scores_nothing() -> void:
	var k := ScoreKeeper.new()
	t.check_eq(k.register_lock(0, NONE, false).points, 0, "plain lock")
	t.check_eq(k.score, 0, "score untouched")


func test_points_scale_with_level() -> void:
	var k := ScoreKeeper.new()
	k.level = 3
	k.register_lock(4, NONE, false)
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
		_isolated(k, 1)
	t.check_eq(k.level, 1, "9 lines")
	_isolated(k, 1)
	t.check_eq(k.level, 2, "10 lines")
	for i in range(10):
		_isolated(k, 1)
	t.check_eq(k.level, 3, "20 lines")


func test_clear_scored_at_level_before_clear() -> void:
	var k := ScoreKeeper.new()
	for i in range(9):
		_isolated(k, 1)
	var before := k.score
	var r := k.register_lock(4, NONE, false)  # 9 -> 13 lines, crosses into level 2
	t.check_eq(r.points, 800, "paid at level 1")
	t.check_eq(k.score - before, 800, "score delta")
	t.check_eq(k.level, 2, "now level 2")
	t.check_eq(k.lines, 13, "13 lines")
	k.register_lock(0, NONE, false)
	t.check_eq(k.register_lock(1, NONE, false).points, 200, "next clear paid at level 2")


# --- T-Spins ---------------------------------------------------------------

func test_t_spin_points() -> void:
	var expected_full := {0: 400, 1: 800, 2: 1200, 3: 1600}
	for n in expected_full:
		t.check_eq(_isolated(ScoreKeeper.new(), n, FULL), expected_full[n], "T-Spin %d lines" % n)
	var expected_mini := {0: 100, 1: 200, 2: 400}
	for n in expected_mini:
		t.check_eq(_isolated(ScoreKeeper.new(), n, MINI), expected_mini[n], "T-Spin Mini %d lines" % n)


func test_t_spin_points_scale_with_level() -> void:
	var k := ScoreKeeper.new()
	k.lines = 30  # level 4
	k.level = 4
	t.check_eq(k.register_lock(2, FULL, false).points, 4800, "TSD at level 4")
	k.register_lock(0, NONE, false)
	t.check_eq(k.register_lock(0, MINI, false).points, 400, "zero-line mini at level 4")


func test_impossible_mini_triple_scores_as_full() -> void:
	t.check_eq(ScoreKeeper.new().register_lock(3, MINI, false).points, 1600, "treated as full")


# --- Back-to-Back --------------------------------------------------------

func test_first_difficult_clear_has_no_bonus_second_does() -> void:
	var k := ScoreKeeper.new()
	var first := k.register_lock(4, NONE, false)
	t.check_eq(first.points, 800, "first Tetris plain")
	t.check(not first.back_to_back_applied, "no B2B yet")
	t.check(k.back_to_back, "chain started")
	var second := k.register_lock(4, NONE, false)
	t.check_eq(second.points, 1200 + 50, "B2B Tetris 1.5x plus combo 1")
	t.check(second.back_to_back_applied, "B2B applied")


func test_back_to_back_chain_of_three() -> void:
	var k := ScoreKeeper.new()
	_isolated(k, 4)
	t.check_eq(_isolated(k, 4), 1200, "second")
	t.check_eq(_isolated(k, 4), 1200, "third keeps the bonus")


func test_single_double_triple_break_the_chain() -> void:
	for n in [1, 2, 3]:
		var k := ScoreKeeper.new()
		_isolated(k, 4)
		_isolated(k, n)
		t.check(not k.back_to_back, "%d lines breaks B2B" % n)
		t.check_eq(_isolated(k, 4), 800, "next Tetris plain after a %d" % n)


func test_lock_without_clear_neither_breaks_nor_extends_chain() -> void:
	var k := ScoreKeeper.new()
	_isolated(k, 4)
	k.register_lock(0, NONE, false)
	k.register_lock(0, FULL, false)  # T-Spin with no lines
	t.check(k.back_to_back, "chain intact")
	t.check_eq(_isolated(k, 4), 1200, "bonus still applies")


func test_zero_line_t_spin_does_not_start_chain() -> void:
	var k := ScoreKeeper.new()
	k.register_lock(0, FULL, false)
	t.check(not k.back_to_back, "no chain from a T-Spin with no lines")
	t.check_eq(_isolated(k, 4), 800, "first Tetris plain")


func test_t_spins_are_difficult() -> void:
	var k := ScoreKeeper.new()
	t.check_eq(_isolated(k, 2, FULL), 1200, "TSD starts the chain")
	t.check_eq(_isolated(k, 2, FULL), 1800, "B2B TSD")
	t.check_eq(_isolated(k, 1, MINI), 300, "B2B mini single: 200 x 1.5")
	t.check_eq(_isolated(k, 4), 1200, "Tetris continues a T-Spin chain")
	t.check_eq(_isolated(k, 3, FULL), 2400, "B2B TST: 1600 x 1.5")


func test_back_to_back_bonus_scales_with_level() -> void:
	var k := ScoreKeeper.new()
	_isolated(k, 4)
	k.level = 2
	t.check_eq(_isolated(k, 4), 2400, "1200 x level 2")


# --- Combos -------------------------------------------------------------------

func test_combo_chain_and_reset() -> void:
	var k := ScoreKeeper.new()
	t.check_eq(k.combo, -1, "no chain")
	t.check_eq(k.register_lock(1, NONE, false).points, 100, "first clear: no combo bonus")
	t.check_eq(k.combo, 0, "combo 0")
	t.check_eq(k.register_lock(1, NONE, false).points, 150, "second: +50")
	t.check_eq(k.register_lock(1, NONE, false).points, 200, "third: +100")
	t.check_eq(k.combo, 2, "combo 2")
	var gap := k.register_lock(0, NONE, false)
	t.check_eq(gap.points, 0, "no points for a lock without a clear")
	t.check_eq(k.combo, -1, "reset by a lock without a clear")
	t.check_eq(k.register_lock(1, NONE, false).points, 100, "chain restarts with no bonus")


func test_combo_bonus_scales_with_level_and_adds_to_advanced_scores() -> void:
	var k := ScoreKeeper.new()
	k.lines = 20  # level 3
	k.level = 3
	k.register_lock(1, NONE, false)
	t.check_eq(k.register_lock(2, FULL, false).points, 1200 * 3 + 50 * 1 * 3, "TSD with combo 1 at level 3")


func test_zero_line_t_spin_resets_combo() -> void:
	var k := ScoreKeeper.new()
	k.register_lock(1, NONE, false)
	k.register_lock(0, FULL, false)
	t.check_eq(k.combo, -1, "no clear, no combo")


func test_combo_uses_pre_clear_level() -> void:
	var k := ScoreKeeper.new()
	k.lines = 8  # level 1; the next double crosses to level 2
	k.register_lock(1, NONE, false)  # 9 lines, combo 0
	var r := k.register_lock(2, NONE, false)  # 11 lines -> level 2 afterwards
	t.check_eq(r.points, 300 + 50, "paid at level 1, combo 1")
	t.check_eq(k.level, 2, "level up applied after scoring")


# --- Perfect clears -----------------------------------------------------------------

func test_perfect_clear_points() -> void:
	var expected := {1: 100 + 800, 2: 300 + 1200, 3: 500 + 1800, 4: 800 + 2000}
	for n in expected:
		t.check_eq(_isolated(ScoreKeeper.new(), n, NONE, true), expected[n], "perfect clear with %d lines" % n)


func test_back_to_back_tetris_perfect_clear() -> void:
	var k := ScoreKeeper.new()
	_isolated(k, 4)
	var r := k.register_lock(4, NONE, true)
	t.check_eq(r.points, 1200 + 3200, "B2B Tetris 1200 + B2B PC 3200")
	t.check(r.perfect_clear and r.back_to_back_applied, "flags")


func test_perfect_clear_does_not_claim_b2b_without_chain() -> void:
	var k := ScoreKeeper.new()
	t.check_eq(k.register_lock(4, NONE, true).points, 800 + 2000, "first Tetris PC uses the 2000 bonus")


func test_perfect_clear_scales_with_level() -> void:
	var k := ScoreKeeper.new()
	k.level = 2
	t.check_eq(k.register_lock(1, NONE, true).points, (100 + 800) * 2, "x level")


func test_perfect_clear_requires_a_clear() -> void:
	var k := ScoreKeeper.new()
	t.check_eq(k.register_lock(0, NONE, true).points, 0, "no lines, no bonus")


func test_t_spin_perfect_clear() -> void:
	var k := ScoreKeeper.new()
	t.check_eq(k.register_lock(2, FULL, true).points, 1200 + 1200, "TSD + PC double bonus")


# --- Descriptions ---------------------------------------------------------------------

func test_descriptions() -> void:
	var k := ScoreKeeper.new()
	t.check_eq(k.register_lock(2, FULL, false).describe(), "T-SPIN DOUBLE", "TSD")
	t.check_eq(k.register_lock(0, MINI, false).describe(), "T-SPIN MINI", "mini")
	t.check_eq(k.register_lock(1, NONE, false).describe(), "SINGLE", "single")
	var chained := ScoreKeeper.new()
	chained.register_lock(4, NONE, false)
	t.check_eq(chained.register_lock(4, NONE, true).describe(), "TETRIS\nBACK-TO-BACK\nCOMBO 1\nPERFECT CLEAR", "full")
	t.check_eq(ScoreKeeper.new().register_lock(0, NONE, false).describe(), "", "nothing notable")
