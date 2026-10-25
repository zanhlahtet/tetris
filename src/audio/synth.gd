class_name SfxSynth
extends RefCounted
## Generates the retro sound effects procedurally (square-wave blips), so the
## project ships no audio assets.

const MIX_RATE: int = 22050


## One square-wave note per (frequency_hz, seconds) pair, played back to back.
## Each note decays linearly to silence so there are no clicks.
static func make(notes: Array[Vector2], volume: float = 0.5) -> AudioStreamWAV:
	var samples := PackedByteArray()
	for note in notes:
		var count: int = int(note.y * MIX_RATE)
		var period: float = MIX_RATE / note.x
		for i in range(count):
			var wave: float = 1.0 if fposmod(i, period) < period / 2.0 else -1.0
			var envelope: float = 1.0 - float(i) / count
			var value: int = int(wave * envelope * volume * 32767.0)
			samples.append(value & 0xFF)
			samples.append((value >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = samples
	return stream


## The effect set, keyed by name.
static func library() -> Dictionary:
	return {
		&"move": make([Vector2(520, 0.025)], 0.25),
		&"rotate": make([Vector2(780, 0.035)], 0.3),
		&"hold": make([Vector2(520, 0.04), Vector2(700, 0.05)], 0.3),
		&"drop": make([Vector2(150, 0.12)], 0.55),
		&"lock": make([Vector2(260, 0.05)], 0.3),
		&"clear_1": make([Vector2(520, 0.07), Vector2(780, 0.09)], 0.35),
		&"clear_2": make([Vector2(520, 0.07), Vector2(660, 0.07), Vector2(880, 0.1)], 0.35),
		&"clear_3": make([Vector2(520, 0.07), Vector2(660, 0.07), Vector2(780, 0.07), Vector2(1040, 0.12)], 0.35),
		&"clear_4": make([Vector2(520, 0.07), Vector2(660, 0.07), Vector2(780, 0.07), Vector2(1040, 0.07), Vector2(1320, 0.2)], 0.4),
		&"game_over": make([Vector2(440, 0.15), Vector2(370, 0.15), Vector2(294, 0.15), Vector2(220, 0.4)], 0.4),
	}
