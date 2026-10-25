class_name Gravity
extends RefCounted
## Automatic fall speed, driven by the run's score (a deliberate custom
## Marathon variant, not the Guideline level curve). The whole progression is
## this one table of (minimum score, milliseconds per row); the last row is
## the speed cap, so the fastest fall is MIN_INTERVAL_MS per row.
## LEVEL (lines / 10) is tracked separately and does not affect gravity.

const TABLE: Array[Vector2i] = [
	Vector2i(0, 1000),
	Vector2i(1000, 850),
	Vector2i(3000, 700),
	Vector2i(6000, 550),
	Vector2i(10000, 430),
	Vector2i(15000, 340),
	Vector2i(22000, 270),
	Vector2i(30000, 220),
	Vector2i(40000, 180),
	Vector2i(55000, 150),
	Vector2i(75000, 120),
]
## The cap: never faster than this, however high the score.
const MIN_INTERVAL_MS: int = 120


## Milliseconds per row at the given run score. Non-increasing in score.
static func interval_for_score(score: int) -> int:
	var interval: int = TABLE[0].y
	for entry in TABLE:
		if score < entry.x:
			break
		interval = entry.y
	return interval
