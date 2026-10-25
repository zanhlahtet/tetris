extends RefCounted

var t: Object

const PATH: String = "user://test_save.cfg"


func _cleanup() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_defaults_when_file_missing() -> void:
	_cleanup()
	var s := SaveData.new(PATH)
	t.check(not s.load_from_disk(), "nothing to load")
	t.check_eq(s.high_score, 0, "high score")
	t.check(s.sound_enabled and s.ghost_enabled, "defaults on")


func test_round_trip() -> void:
	_cleanup()
	var a := SaveData.new(PATH)
	a.high_score = 12345
	a.sound_enabled = false
	a.ghost_enabled = false
	t.check(a.save(), "saved")
	t.check(not FileAccess.file_exists(PATH + ".tmp"), "temp file renamed away")
	var b := SaveData.new(PATH)
	t.check(b.load_from_disk(), "loaded")
	t.check_eq(b.high_score, 12345, "high score")
	t.check(not b.sound_enabled, "sound off persisted")
	t.check(not b.ghost_enabled, "ghost off persisted")
	_cleanup()


func test_overwrite_existing_save() -> void:
	_cleanup()
	var a := SaveData.new(PATH)
	a.high_score = 10
	a.save()
	a.high_score = 99
	t.check(a.save(), "second save")
	var b := SaveData.new(PATH)
	b.load_from_disk()
	t.check_eq(b.high_score, 99, "latest value")
	_cleanup()


func test_corrupt_file_falls_back_to_defaults() -> void:
	_cleanup()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("this is [[ not a config file\n" + char(0) + char(1))
	f.close()
	var s := SaveData.new(PATH)
	s.load_from_disk()
	t.check_eq(s.high_score, 0, "default score")
	t.check(s.sound_enabled and s.ghost_enabled, "default prefs")
	_cleanup()


func test_wrong_types_and_ranges_are_rejected() -> void:
	_cleanup()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string('[progress]\nhigh_score="lots"\n[settings]\nsound_enabled=3\nghost_enabled="no"\n')
	f.close()
	var s := SaveData.new(PATH)
	t.check(s.load_from_disk(), "parses")
	t.check_eq(s.high_score, 0, "string score ignored")
	t.check(s.sound_enabled and s.ghost_enabled, "non-bool prefs ignored")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[progress]\nhigh_score=-50\n")
	f.close()
	s.load_from_disk()
	t.check_eq(s.high_score, 0, "negative clamped")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[progress]\nhigh_score=99999999999999\n")
	f.close()
	s.load_from_disk()
	t.check_eq(s.high_score, SaveData.MAX_SCORE, "huge clamped")
	_cleanup()


func test_submit_score() -> void:
	var s := SaveData.new(PATH)
	t.check(s.submit_score(500), "first score is a record")
	t.check_eq(s.high_score, 500, "stored")
	t.check(not s.submit_score(500), "a tie is not a record")
	t.check(not s.submit_score(100), "lower score ignored")
	t.check_eq(s.high_score, 500, "unchanged")
	t.check(s.submit_score(501), "higher is a record")
	t.check(not s.submit_score(0), "zero never a record")


func test_unwritable_path_reports_failure() -> void:
	var s := SaveData.new("user://no_such_dir_xyz/save.cfg")
	t.check(not s.save(), "save fails cleanly")
