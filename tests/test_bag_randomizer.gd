extends RefCounted

var t: Object


func _draw(bag: BagRandomizer, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(n):
		out.append(bag.next())
	return out


func test_each_bag_is_a_permutation() -> void:
	var bag := BagRandomizer.new(123, false)
	for b in range(50):
		var drawn := _draw(bag, 7)
		drawn.sort()
		t.check_eq(drawn, Tetromino.ALL_TYPES, "bag %d has each type once" % b)


func test_distribution_over_many_pieces() -> void:
	var bag := BagRandomizer.new(7, false)
	var counts: Dictionary = {}
	for p in _draw(bag, 700):
		counts[p] = counts.get(p, 0) + 1
	for type in Tetromino.ALL_TYPES:
		t.check_eq(counts[type], 100, "%s count" % Tetromino.type_name(type))


func test_same_seed_same_sequence() -> void:
	t.check_eq(_draw(BagRandomizer.new(42, false), 100), _draw(BagRandomizer.new(42, false), 100), "seed 42 repeats")


func test_different_seeds_differ() -> void:
	t.check(_draw(BagRandomizer.new(1, false), 70) != _draw(BagRandomizer.new(2, false), 70), "seeds 1 and 2 differ")
