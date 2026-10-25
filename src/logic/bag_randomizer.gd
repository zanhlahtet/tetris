class_name BagRandomizer
extends RefCounted
## 7-bag randomizer: each bag is a shuffled permutation of all seven types.
## Seedable for reproducible sequences.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bag: Array[int] = []


func _init(seed_value: int = 0, randomize_seed: bool = true) -> void:
	if randomize_seed:
		_rng.randomize()
	else:
		_rng.seed = seed_value


func next() -> int:
	if _bag.is_empty():
		_refill()
	return _bag.pop_back()


func _refill() -> void:
	_bag.assign(Tetromino.ALL_TYPES)
	# Fisher-Yates using our own seeded rng (Array.shuffle uses the global one).
	for i in range(_bag.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = tmp
