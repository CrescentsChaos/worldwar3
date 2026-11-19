extends Node
## Sound system. Every sound is looked up by NAME:
##   1. user://audio/<name>.ogg|mp3|wav   (drop-in, no re-export; see the Asset Manager)
##   2. res://assets/audio/<name>.ogg|wav|mp3
##   3. a tiny procedural fallback (so the game is never silent or broken)
## Callers use play_any([...names]) so specific names (e.g. "fire_tank") win over generic ones ("shot").
##
## Voice handling (v6): a sound that is playing is NEVER cut off by a less important one.
##   * a pool of POOL voices; a new sound takes an idle voice first
##   * if every voice is busy it may only steal a voice of LOWER priority (nukes > explosions > deaths > shots)
##   * at most MAX_SAME copies of one sound play at once (extra copies are skipped, nothing is cut)
##   * this node keeps running while the game is paused, so a pause menu / game-over screen never chops sounds
##   * radio lines have their own channel and play one after another (see radio.gd)

const RATE := 22050
const POOL := 48
const MAX_SAME := 5

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var p_name: Array = []             # per voice: sound name
var p_prio: Array = []             # per voice: priority
var p_start: Array = []            # per voice: start time (s)
var last_played: Dictionary = {}
var enabled := true
const EXTS := ["ogg", "wav", "mp3"]
const USER_DIR := "user://audio/"
const RES_DIR := "res://assets/audio/"
var files: Dictionary = {}          # name -> AudioStream (or null when no file exists)
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var music_name := ""
var ambient_name := ""
var bus_sfx := "Master"
var bus_music := "Master"
var bus_radio := "Master"
var _duck := 0.0                    # music ducking while the radio talks (0..1)
var _duck_target := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for d in ["audio", "vfx", "tiles", "sprites", "fonts", "layouts", "ui"]:
		DirAccess.make_dir_recursive_absolute("user://" + d)
	_make_buses()
	music_player = AudioStreamPlayer.new()
	ambient_player = AudioStreamPlayer.new()
	music_player.bus = bus_music
	ambient_player.bus = bus_music
	add_child(music_player)
	add_child(ambient_player)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = bus_sfx
		add_child(p)
		players.append(p)
		p_name.append("")
		p_prio.append(0)
		p_start.append(0.0)
	streams["shot"] = _noise(0.05, 0.35, 7.0, 0.1)
	streams["boom"] = _noise(0.7, 1.0, 4.5, 0.85)
	streams["nuke"] = _noise(3.0, 1.0, 1.3, 0.95)
	streams["launch"] = _noise(0.6, 0.8, 2.5, 0.7)
	streams["intercept"] = _noise(0.25, 0.6, 9.0, 0.3)
	streams["alarm"] = _alarm()
	streams["click"] = _noise(0.03, 0.4, 12.0, 0.2)
	streams["deploy"] = _noise(0.12, 0.4, 8.0, 0.6)
	streams["smoke"] = _noise(0.5, 0.5, 3.0, 0.9)
	streams["dig"] = _noise(0.18, 0.5, 6.0, 0.75)
	streams["ping"] = _ping()


func _make_buses() -> void:
	# Separate buses so music / effects / radio can be balanced (and the radio can duck the music).
	for nm in ["Music", "SFX", "Radio"]:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, nm)
			AudioServer.set_bus_send(idx, "Master")
	bus_music = "Music"
	bus_sfx = "SFX"
	bus_radio = "Radio"


func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 2.0)))


func duck_music(on: bool) -> void:
	_duck_target = 1.0 if on else 0.0


func _process(delta: float) -> void:
	if not is_equal_approx(_duck, _duck_target):
		_duck = move_toward(_duck, _duck_target, delta * 4.0)
		var idx := AudioServer.get_bus_index(bus_music)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, lerpf(0.0, -9.0, _duck))


## Forget every cached sound file (used after the Asset Manager replaced one).
func reload() -> void:
	files.clear()
	if music_name != "":
		var m := music_name
		music_name = ""
		play_music(m)
	if ambient_name != "":
		var a := ambient_name
		ambient_name = ""
		play_ambient(a)


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
	if ext == "wav":
		return load_wav_file(path)
	return null


## Minimal RIFF/WAVE reader (PCM 8 / 16 bit, mono or stereo) so .wav files can be dropped in at runtime too.
func load_wav_file(path: String) -> AudioStreamWAV:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var pos := 12
	var channels := 1
	var rate := 44100
	var bits := 16
	var fmt_ok := false
	var data := PackedByteArray()
	while pos + 8 <= b.size():
		var cid := b.slice(pos, pos + 4).get_string_from_ascii()
		var csz := int(b.decode_u32(pos + 4))
		var body := pos + 8
		if cid == "fmt ":
			var tag := int(b.decode_u16(body))
			channels = int(b.decode_u16(body + 2))
			rate = int(b.decode_u32(body + 4))
			bits = int(b.decode_u16(body + 14))
			fmt_ok = (tag == 1 or tag == 0xFFFE)
		elif cid == "data":
			data = b.slice(body, mini(body + csz, b.size()))
			break
		pos = body + csz + (csz % 2)
	if not fmt_ok or data.is_empty() or (bits != 8 and bits != 16) or channels < 1 or channels > 2:
		return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = rate
	w.stereo = channels == 2
	if bits == 8:
		# WAV stores unsigned 8-bit; Godot wants signed.
		var conv := PackedByteArray()
		conv.resize(data.size())
		for i in data.size():
			conv[i] = (int(data[i]) - 128) & 0xFF
		data = conv
	w.data = data
	return w


func has_sound(sound: String) -> bool:
	return files.get(sound, null) != null or streams.has(sound) or file_stream(sound) != null


## How important a sound is: higher priority sounds are never cut off by lower ones.
func priority_of(sound: String) -> int:
	if sound.contains("nuke") or sound == "alarm":
		return 5
	if sound.begins_with("die_base") or sound.begins_with("explosion_large") or sound.begins_with("launch"):
		return 4
	if sound.begins_with("boom") or sound.begins_with("explosion") or sound.begins_with("die_"):
		return 3
	if sound.begins_with("deploy") or sound.begins_with("intercept") or sound.begins_with("ability") or sound == "smoke" or sound == "ping":
		return 2
	if sound == "click":
		return 0
	return 1


func _free_voice(prio: int) -> int:
	# 1. an idle voice
	for i in POOL:
		if not players[i].playing:
			return i
	# 2. steal the least important / oldest voice that is strictly less important than the new sound
	var best := -1
	var best_prio := 99
	var best_start := INF
	for i in POOL:
		var pp: int = p_prio[i]
		if pp >= prio:
			continue
		var st: float = p_start[i]
		if pp < best_prio or (pp == best_prio and st < best_start):
			best = i
			best_prio = pp
			best_start = st
	return best


func play(sound: String, volume_db: float = 0.0, min_interval: float = 0.05, priority: int = -1) -> bool:
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
	var prio := priority if priority >= 0 else priority_of(sound)
	var same := 0
	for i in POOL:
		if players[i].playing and p_name[i] == sound:
			same += 1
	if same >= MAX_SAME:
		return true                      # enough copies already; never cut one of them off
	var v := _free_voice(prio)
	if v < 0:
		return true                      # everything audible is at least as important: drop this one, cut nothing
	last_played[sound] = now
	var p := players[v]
	p.stream = st
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.96, 1.04) if from_file else 1.0
	p_name[v] = sound
	p_prio[v] = prio
	p_start[v] = now
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
		w.loop_end = w.data.size() / ((2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1))
	player.stream = st
	player.volume_db = volume_db
	player.play()


func make_stream(samples: PackedFloat32Array, rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	return s


func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	return make_stream(samples, RATE)


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


func _ping() -> AudioStreamWAV:
	var n := int(0.7 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 1250.0 * t) * exp(-t * 6.0) * 0.3
	return _make_stream(out)
