extends Node
## Tiny procedural sound system (no audio files needed).
## To use your own sounds, replace the entries in `streams` with loaded files.

const RATE := 22050
const POOL := 10

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var last_played: Dictionary = {}
var next_player := 0
var enabled := true


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["shot"] = _noise(0.05, 0.35, 7.0, 0.1)
	streams["boom"] = _noise(0.7, 1.0, 4.5, 0.85)
	streams["nuke"] = _noise(3.0, 1.0, 1.3, 0.95)
	streams["launch"] = _noise(0.6, 0.8, 2.5, 0.7)
	streams["intercept"] = _noise(0.25, 0.6, 9.0, 0.3)
	streams["alarm"] = _alarm()
	streams["click"] = _noise(0.03, 0.4, 12.0, 0.2)
	streams["deploy"] = _noise(0.12, 0.4, 8.0, 0.6)


func play(sound: String, volume_db: float = 0.0, min_interval: float = 0.05) -> void:
	if not enabled or not streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(sound, -10.0)) < min_interval:
		return
	last_played[sound] = now
	var p := players[next_player]
	next_player = (next_player + 1) % POOL
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.play()


func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


func _noise(duration: float, amp: float, decay: float, smooth: float) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var gain := 1.0 / maxf(1.0 - smooth, 0.05) * 0.35
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * (1.0 - smooth)
		out[i] = lp * minf(gain, 6.0) * exp(-t * decay) * amp * 0.5
	return _make_stream(out)


func _alarm() -> AudioStreamWAV:
	var n := int(1.0 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 880.0 if int(t / 0.16) % 2 == 0 else 640.0
		out[i] = (1.0 if sin(TAU * f * t) > 0.0 else -1.0) * 0.18 * (1.0 - t * 0.4)
	return _make_stream(out)
