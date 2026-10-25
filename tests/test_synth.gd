extends RefCounted

var t: Object


func test_stream_format_and_length() -> void:
	var s := SfxSynth.make([Vector2(440, 0.1)], 0.5)
	t.check_eq(s.format, AudioStreamWAV.FORMAT_16_BITS, "16-bit")
	t.check_eq(s.mix_rate, SfxSynth.MIX_RATE, "mix rate")
	t.check(not s.stereo, "mono")
	t.check_eq(s.data.size(), int(0.1 * SfxSynth.MIX_RATE) * 2, "two bytes per sample")


func test_notes_are_concatenated() -> void:
	var s := SfxSynth.make([Vector2(440, 0.05), Vector2(880, 0.05)], 0.5)
	t.check_eq(s.data.size(), 2 * int(0.05 * SfxSynth.MIX_RATE) * 2, "both notes present")


func test_amplitude_respects_volume_and_decays() -> void:
	var s := SfxSynth.make([Vector2(440, 0.1)], 0.5)
	var peak := 0
	var tail := 0
	var n := s.data.size() / 2
	for i in range(n):
		var v := absi(s.data.decode_s16(i * 2))
		peak = maxi(peak, v)
		if i >= n - 8:
			tail = maxi(tail, v)
	t.check(peak > 0, "not silent")
	t.check(peak <= int(0.5 * 32767.0), "never above the requested volume")
	t.check(tail < peak / 10, "decays to near silence (no click)")


func test_library_has_every_sound_the_session_needs() -> void:
	var lib := SfxSynth.library()
	for name in [&"move", &"rotate", &"hold", &"drop", &"lock", &"clear_1", &"clear_2", &"clear_3", &"clear_4", &"game_over"]:
		t.check(lib.has(name), "has " + name)
		t.check((lib[name] as AudioStreamWAV).data.size() > 0, name + " has audio")
	for name in lib:
		var seconds: float = float((lib[name] as AudioStreamWAV).data.size()) / 2.0 / SfxSynth.MIX_RATE
		t.check(seconds < 1.0, "%s is short (%.2fs)" % [name, seconds])
