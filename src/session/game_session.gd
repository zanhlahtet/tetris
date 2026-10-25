class_name GameSession
extends RefCounted
## Game session/controller. Owns the Board, bag, upcoming queue and active
## piece; (from later milestones) gravity timing, scoring and level. Consumes
## abstract input commands; never touches rendering or input devices.

const PREVIEW_COUNT: int = 3

var board: Board = Board.new()
var active: ActivePiece = null
## Upcoming piece types, next piece first. Always holds PREVIEW_COUNT entries.
var queue: Array[int] = []

var _bag: BagRandomizer


## With no arguments the sequence is random; pass a seed for determinism.
func _init(seed_value: int = 0, use_seed: bool = false) -> void:
	_bag = BagRandomizer.new(seed_value, not use_seed)
	_fill_queue()


## Takes the next piece from the queue and spawns it. Returns false (and leaves
## no active piece) if the spawn position is blocked.
func spawn_next() -> bool:
	var piece := ActivePiece.new(queue.pop_front())
	_fill_queue()
	if not board.can_place(piece.cells()):
		active = null
		return false
	active = piece
	return true


func _fill_queue() -> void:
	while queue.size() < PREVIEW_COUNT:
		queue.append(_bag.next())
