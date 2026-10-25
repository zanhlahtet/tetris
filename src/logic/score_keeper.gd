class_name ScoreKeeper
extends RefCounted
## Score, cleared-line total and level. Pure bookkeeping. Advanced scoring
## (T-spins, combos, back-to-back; M7) extends add_line_clear / adds methods
## here without touching the session's flow.

const LINES_PER_LEVEL: int = 10
## Base points for clearing 0..4 lines at once; multiplied by the level.
const LINE_CLEAR_POINTS: Array[int] = [0, 100, 300, 500, 800]
const SOFT_DROP_POINTS_PER_CELL: int = 1
const HARD_DROP_POINTS_PER_CELL: int = 2

var score: int = 0
var lines: int = 0
var level: int = 1


func add_soft_drop(cells: int) -> void:
	score += cells * SOFT_DROP_POINTS_PER_CELL


func add_hard_drop(cells: int) -> void:
	score += cells * HARD_DROP_POINTS_PER_CELL


## Scores a clear at the level in effect before the clear, then updates the
## line total and level. Returns the points awarded.
func add_line_clear(line_count: int) -> int:
	var points: int = LINE_CLEAR_POINTS[line_count] * level
	score += points
	lines += line_count
	level = 1 + lines / LINES_PER_LEVEL
	return points
