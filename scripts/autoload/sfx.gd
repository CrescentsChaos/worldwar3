extends Node
## Sound system. Every sound is looked up by NAME:
##   1. user://audio/<name>.ogg|mp3     (drop-in, no re-export; see assets/audio/README.md)
##   2. res://assets/audio/<name>.ogg|wav|mp3
##   3. a tiny procedural fallback (so the game is never silent or broken)
## Callers use play_any([...names]) so specific names (e.g. "fire_tank") win over generic ones ("shot").

const RATE := 22050
const POOL := 10

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var last_played: Dictionary = {}
var next_player := 0
var enabled := true
const EXTS := ["ogg", "wav", "mp3"]
const USER_DIR := "user://audio/"
const RES_DIR := "res://assets/audio/"
var files: Dictionary = {}          # name -> AudioStream (or null when no file exists)
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var music_name := ""
var ambient_name := ""


func _ready() -> void:
	for d in ["audio", "vfx", "tiles", "sprites"]:
		DirAccess.make_dir_recursive_absolute("user://" + d)
	music_player = AudioStreamPlayer.new()
	ambient_player = AudioStreamPlayer.new()
	add_child(music_player)
	add_child(ambient_player)
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


## Finds a sound file by name (user:// first, then res://). Returns null if there is none.
func file_stream(sound: String) -> AudioStream:
	if files.has(sound):
		return files[sound]
	var s: AudioStream = null
	for ext in EXTS:
		var up: String = USER_DIR + sound + "." + ext
		if FileAccess.file_exists(up):
			s = _load_user(up, ext)
			if s != null:
				break
	if s == null:
		for ext in EXTS:
			var rp: String = RES_DIR + sound + "." + ext
			if ResourceLoader.exists(rp):
				s = load(rp) as AudioStream
				if s != null:
					break
	files[sound] = s
	return s


func _load_user(path: String, ext: String) -> AudioStream:
	if ext == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	if ext == "mp3":
		var m := AudioStreamMP3.new()
		m.data = FileAccess.get_file_as_bytes(path)
		return m
	return null     # wav: put it in res://assets/audio/ (Godot imports it) or convert to ogg


func has_sound(sound: String) -> bool:
	return files.get(sound, null) != null or streams.has(sound) or file_stream(sound) != null


func play(sound: String, volume_db: float = 0.0, min_interval: float = 0.05) -> bool:
	if not enabled:
		return false
	var st: AudioStream = file_stream(sound)
	var from_file := st != null
	if st == null:
		if not streams.has(sound):
			return false
		st = streams[sound]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(sound, -10.0)) < min_interval:
		return true
	last_played[sound] = now
	var p := players[next_player]
	next_player = (next_player + 1) % POOL
	p.stream = st
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.96, 1.04) if from_file else 1.0
	p.play()
	return true


## Plays the first name in the list that has a sound (file or built-in). Most specific name first.
func play_any(names: Array, volume_db: float = 0.0, min_interval: float = 0.05) -> bool:
	for n in names:
		if has_sound(str(n)):
			return play(str(n), volume_db, min_interval)
	return false


## Looping background music / ambience. Does nothing if no file named `sound` exists.
func play_music(sound: String, volume_db: float = -8.0) -> void:
	_play_loop(music_player, sound, volume_db, true)


func play_ambient(sound: String, volume_db: float = -14.0) -> void:
	_play_loop(ambient_player, sound, volume_db, false)


func stop_ambient() -> void:
	ambient_name = ""
	ambient_player.stop()


func stop_music() -> void:
	music_name = ""
	music_player.stop()


func _play_loop(player: AudioStreamPlayer, sound: String, volume_db: float, is_music: bool) -> void:
	var current := music_name if is_music else ambient_name
	if sound == current and player.playing:
		return
	if is_music:
		music_name = sound
	else:
		ambient_name = sound
	var st := file_stream(sound)
	if st == null:
		player.stop()
		return
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = w.data.size() / (2 * (2 if w.stereo else 1))
	player.stream = st
	player.volume_db = volume_db
	player.play()


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
