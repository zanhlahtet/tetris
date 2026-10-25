extends SceneTree
## Headless test runner. Discovers tests/test_*.gd, runs every method named
## test_*, and exits non-zero on failure.
##   godot --headless --path . --script res://tests/run_tests.gd

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	var tests: int = 0
	for file in _test_files():
		var script := load("res://tests/" + file) as GDScript
		var suite: RefCounted = script.new()
		suite.set("t", self)
		for method in suite.get_method_list():
			var name: String = method["name"]
			if name.begins_with("test_"):
				tests += 1
				print("  ", file.get_basename(), ".", name)
				suite.call(name)
	print("%d tests, %d checks, %d failures" % [tests, _checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String = "") -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
		print("    FAIL: ", message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func _test_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out
