class_name Sfx
extends Node
## Plays the sound effects in response to session events. Pure output: it only
## listens to the session and never changes game state.

const VOLUME_DB: float = -6.0

var enabled: bool = true

var _players: Dictionary = {}
var _hard_dropped: bool = false


func _ready() -> void:
	var streams: Dictionary = SfxSynth.library()
	for sound_name: StringName in streams:
		var player := AudioStreamPlayer.new()
		player.stream = streams[sound_name]
		player.volume_db = VOLUME_DB
		add_child(player)
		_players[sound_name] = player


func bind(session: GameSession) -> void:
	session.moved.connect(play.bind(&"move"))
	session.rotated.connect(play.bind(&"rotate"))
	session.held.connect(play.bind(&"hold"))
	session.hard_dropped.connect(_on_hard_dropped)
	session.locked.connect(_on_locked)
	session.lines_cleared.connect(_on_lines_cleared)
	session.game_ended.connect(play.bind(&"game_over"))


func play(sound_name: StringName) -> void:
	if not enabled:
		return
	var player: AudioStreamPlayer = _players.get(sound_name)
	if player != null:
		player.play()


func _on_hard_dropped(_cells: Array[Vector2i], _distance: int) -> void:
	_hard_dropped = true
	play(&"drop")


func _on_locked() -> void:
	# A hard drop already made its own thud.
	if not _hard_dropped:
		play(&"lock")
	_hard_dropped = false


func _on_lines_cleared(rows: Array[int]) -> void:
	play(StringName("clear_%d" % clampi(rows.size(), 1, 4)))
