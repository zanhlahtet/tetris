class_name SaveData
extends RefCounted
## Local persistence: high score and user preferences in a ConfigFile under
## user://. Loading never fails hard: a missing, corrupt or tampered file just
## yields defaults. Nothing here is sent anywhere.

const DEFAULT_PATH: String = "user://save.cfg"
const MAX_SCORE: int = 999_999_999

var high_score: int = 0
var sound_enabled: bool = true
var ghost_enabled: bool = true

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Reads the file. Returns false (leaving defaults) if it is missing or unreadable.
func load_from_disk() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return false
	var score: Variant = cfg.get_value("progress", "high_score", 0)
	high_score = clampi(score, 0, MAX_SCORE) if typeof(score) == TYPE_INT else 0
	sound_enabled = _read_bool(cfg, "sound_enabled")
	ghost_enabled = _read_bool(cfg, "ghost_enabled")
	return true


## Writes via a temporary file so a crash mid-write cannot corrupt the save.
func save() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("settings", "sound_enabled", sound_enabled)
	cfg.set_value("settings", "ghost_enabled", ghost_enabled)
	var temp_path: String = _path + ".tmp"
	if cfg.save(temp_path) != OK:
		return false
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	return DirAccess.rename_absolute(temp_path, _path) == OK


## Records a score if it beats the best. Returns true for a new record.
func submit_score(score: int) -> bool:
	if score <= high_score:
		return false
	high_score = mini(score, MAX_SCORE)
	return true


func _read_bool(cfg: ConfigFile, key: String) -> bool:
	var value: Variant = cfg.get_value("settings", key, true)
	return value if typeof(value) == TYPE_BOOL else true
