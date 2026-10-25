class_name ScoreKeeper
extends RefCounted
## Score, cleared-line total, level and the scoring chains (Back-to-Back and
## combo). Pure bookkeeping; see docs/GAME_RULES.md for the rules and for the
## intentional differences from other published implementations.
##
## Every lock is reported exactly once through register_lock().

const LINES_PER_LEVEL: int = 10
## Base points for clearing 0..4 lines at once; multiplied by the level.
const LINE_CLEAR_POINTS: Array[int] = [0, 100, 300, 500, 800]
## T-Spin base points for 0..3 lines (a T cannot clear four).
const T_SPIN_POINTS: Array[int] = [400, 800, 1200, 1600]
## T-Spin Mini base points for 0..2 lines.
const T_SPIN_MINI_POINTS: Array[int] = [100, 200, 400]
## Perfect-clear bonus for 1..4 lines (index 0 unused), added on top of the
## normal clear score.
const PERFECT_CLEAR_POINTS: Array[int] = [0, 800, 1200, 1800, 2000]
## Perfect-clear bonus for a Back-to-Back Tetris, replacing the 2000 above.
const PERFECT_CLEAR_B2B_TETRIS_POINTS: int = 3200
## Back-to-Back multiplier on the base action score, as a fraction (3/2 = 1.5).
const B2B_NUMERATOR: int = 3
const B2B_DENOMINATOR: int = 2
const COMBO_POINTS_PER_STEP: int = 50
const SOFT_DROP_POINTS_PER_CELL: int = 1
const HARD_DROP_POINTS_PER_CELL: int = 2

var score: int = 0
var lines: int = 0
var level: int = 1
## True while the last line-clearing lock was a "difficult" clear (Tetris or any
## T-Spin that cleared lines). The next difficult clear then gets the bonus.
var back_to_back: bool = false
## Consecutive line-clearing locks beyond the first: -1 when no chain is
## running, 0 after the first clear, 1 after the second, ...
var combo: int = -1


## What one lock was worth and why. Used for the HUD and tests.
class LockResult:
	var lines: int = 0
	var spin: int = TSpin.Kind.NONE
	var points: int = 0
	var back_to_back_applied: bool = false
	var combo: int = -1
	var perfect_clear: bool = false

	## Short multi-line description of the award; empty if nothing notable.
	func describe() -> String:
		var parts: Array[String] = []
		var name: String = _action_name()
		if name != "":
			parts.append(name)
		if back_to_back_applied:
			parts.append("BACK-TO-BACK")
		if combo > 0:
			parts.append("COMBO %d" % combo)
		if perfect_clear:
			parts.append("PERFECT CLEAR")
		return "\n".join(parts)

	func _action_name() -> String:
		var count_name: String = ["", "SINGLE", "DOUBLE", "TRIPLE", "TETRIS"][lines]
		match spin:
			TSpin.Kind.MINI:
				return "T-SPIN MINI" if lines == 0 else "T-SPIN MINI " + count_name
			TSpin.Kind.FULL:
				return "T-SPIN" if lines == 0 else "T-SPIN " + count_name
		return count_name


func add_soft_drop(cells: int) -> void:
	score += cells * SOFT_DROP_POINTS_PER_CELL


func add_hard_drop(cells: int) -> void:
	score += cells * HARD_DROP_POINTS_PER_CELL


## Scores one piece lock: `line_count` lines cleared (0-4), the T-Spin kind
## detected for the piece, and whether the clear left the board empty. All
## points use the level in effect before this lock's lines are added.
func register_lock(line_count: int, spin: int, perfect_clear: bool) -> LockResult:
	var result := LockResult.new()
	result.lines = line_count
	# A Mini that clears three or more lines cannot occur in SRS; score it as full.
	result.spin = TSpin.Kind.FULL if (spin == TSpin.Kind.MINI and line_count > 2) else spin
	result.perfect_clear = perfect_clear and line_count > 0

	var base: int = _base_points(line_count, result.spin)
	var difficult: bool = line_count > 0 and (result.spin != TSpin.Kind.NONE or line_count == 4)
	if line_count > 0:
		if difficult:
			if back_to_back:
				base = base * B2B_NUMERATOR / B2B_DENOMINATOR
				result.back_to_back_applied = true
			back_to_back = true
		else:
			back_to_back = false
		combo += 1
	else:
		combo = -1  # a lock without a clear ends the combo; B2B is untouched

	var points: int = base * level
	if combo > 0:
		points += COMBO_POINTS_PER_STEP * combo * level
	if result.perfect_clear:
		var bonus: int = PERFECT_CLEAR_POINTS[line_count]
		if line_count == 4 and result.back_to_back_applied:
			bonus = PERFECT_CLEAR_B2B_TETRIS_POINTS
		points += bonus * level

	result.points = points
	result.combo = combo
	score += points
	lines += line_count
	level = 1 + lines / LINES_PER_LEVEL
	return result


func _base_points(line_count: int, spin: int) -> int:
	match spin:
		TSpin.Kind.MINI:
			return T_SPIN_MINI_POINTS[line_count]
		TSpin.Kind.FULL:
			return T_SPIN_POINTS[mini(line_count, T_SPIN_POINTS.size() - 1)]
	return LINE_CLEAR_POINTS[line_count]
