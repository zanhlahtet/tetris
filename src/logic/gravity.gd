class_name Gravity
extends RefCounted
## Gravity progression: the Tetris Guideline curve,
##   seconds per row = (0.8 - (level - 1) * 0.007) ^ (level - 1)
## converted to whole milliseconds (level 1 = 1000, level 5 = 355,
## level 10 = 64, level 15 = 7). The curve is clamped at CURVE_MAX_LEVEL, so
## every later level falls at the level-15 speed, and never below 1 ms/row.

const CURVE_MAX_LEVEL: int = 15


static func interval_ms(level: int) -> int:
	var l: int = clampi(level, 1, CURVE_MAX_LEVEL)
	var seconds: float = pow(0.8 - (l - 1) * 0.007, l - 1)
	return maxi(1, roundi(seconds * 1000.0))
