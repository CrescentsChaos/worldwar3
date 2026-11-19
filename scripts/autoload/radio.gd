extends Node
## Radio comms (v6). Game events call Radio.say("event", {context}); the radio picks a line, queues it and plays it:
##   * every line is shown as a subtitle on the RADIO NET panel (click it to jump the camera to where it happened)
##   * audio: a voice file named  radio_<event>_<n>.ogg|mp3|wav  (n = 1, 2, 3 ... matches the variant)  or
##     radio_<event>.ogg  in user://audio/ or res://assets/audio/  - otherwise a synthesised radio babble with static
##   * lines are played one after another on their own channel and are NEVER cut off by other sounds or by each other;
##     the music ducks while somebody is talking.   M mutes the radio audio (subtitles stay).
## All text lives in LINES below (tokens: {cs} unit callsign, {hq} headquarters callsign, {grid} map reference,
## {n} count, {what} unit class, {name} unit / building name).

const MAX_QUEUE := 7
const MAX_LOG := 60
const CALLSIGNS := {
	"infantry": ["Dagger", "Viper", "Ranger", "Wolf", "Badger"],
	"armor": ["Hammer", "Anvil", "Steel", "Titan", "Bulldog"],
	"vehicle": ["Rover", "Mule", "Jackal", "Scout"],
	"air": ["Hawk", "Falcon", "Raven", "Talon", "Eagle"],
	"ship": ["Trident", "Neptune", "Harbor", "Anchor"],
	"drone": ["Eyes", "Peeper", "Overwatch", "Sparrow"],
}
const HQ_NAMES := {
	"wehrmacht": "Oberkommando", "red_army": "Stavka", "ija": "Daihonei", "british_army": "Whitehall",
	"us_army": "Overlord", "french_army": "Etat-Major", "italian_army": "Comando Supremo", "russian_gf": "Zvezda",
}
const COOLDOWN := {
	"under_attack": 9.0, "unit_lost": 7.0, "kill": 10.0, "unit_ready": 3.5, "enemy_spotted": 9.0, "structure_spotted": 14.0,
	"ack_move": 1.4, "ack_attack": 1.4, "ack_hold": 1.4, "retreat": 12.0, "smoke": 14.0, "recon_lost": 12.0,
	"capital_hit": 14.0, "enemy_comms": 30.0, "power_down": 20.0, "repaired": 12.0, "dig_in": 40.0, "fortify": 10.0,
	"intercept_ok": 6.0, "structure_lost": 4.0,
}
const PRIO := {
	"nuke_enemy": 3, "capital_hit": 3, "victory": 3, "defeat": 3, "battle_start": 3, "prep_start": 2,
	"missile_enemy": 2, "structure_lost": 2, "power_down": 2, "under_attack": 1, "unit_lost": 1, "enemy_spotted": 1,
	"structure_spotted": 1, "intercept_ok": 1, "recon_lost": 1,
}
# {event: [speaker kind, [variants]]}   speaker kind: hq | unit | enemy
const LINES := {
	"prep_start": ["hq", [
		"{hq} to all stations: preparation window open. Lay out your defences, check your fields of fire, then give the word.",
		"{hq}, all units: we have a short window before contact. Dig in, rotate your sites, set the plan.",
	]],
	"battle_start": ["hq", [
		"{hq} to all stations: weapons free. Execute the plan. Good hunting.",
		"{hq}: H-hour. All units, move out and make contact.",
		"All stations, {hq}: the war has begun. Keep your eyes open and your radios clear.",
	]],
	"victory": ["hq", [
		"{hq}: enemy capital is down. All stations, the day is ours.",
		"{hq} to all units: it is over. Outstanding work.",
	]],
	"defeat": ["hq", [
		"{hq}: capital has fallen. All stations, break contact. Break contact.",
		"Mayday, mayday. Headquarters is lost.",
	]],
	"unit_ready": ["hq", [
		"{hq}: {name} is ready for tasking.",
		"{name} rolled out and awaiting orders.",
		"Reinforcement on the net: {name}.",
	]],
	"under_attack": ["unit", [
		"{cs}: taking fire at {grid}! Request support!",
		"{cs}: contact, we are engaged at {grid}.",
		"{cs}: under attack at {grid}, holding for now.",
		"{cs}: they're all over us at {grid}!",
	]],
	"unit_lost": ["unit", [
		"{cs}: {name} is down. I say again, {name} is down.",
		"We lost {name} at {grid}.",
		"{cs}: {name} destroyed. Moving to cover.",
	]],
	"structure_lost": ["hq", [
		"{hq}: we have lost the {name} at {grid}.",
		"{name} is destroyed. Damage control is on it.",
		"Be advised, {name} at {grid} is gone.",
	]],
	"kill": ["unit", [
		"{cs}: target destroyed.",
		"{cs}: good effect on target. Splash one.",
		"{cs}: hostile down, scanning for more.",
	]],
	"enemy_spotted": ["unit", [
		"{cs}: contact, {n} hostile {what} at {grid}. Over.",
		"{cs}: eyes on {n} enemy {what}, grid {grid}.",
		"{cs}: visual on enemy {what} near {grid}. Mark and report.",
	]],
	"structure_spotted": ["unit", [
		"{cs}: enemy emplacement spotted at {grid}: {name}.",
		"{cs}: new defensive position at {grid}, looks like a {name}.",
	]],
	"missile_enemy": ["hq", [
		"{hq}: missile launch detected! Incoming: {name}. All air defence units, engage!",
		"Launch warning! {name} inbound, impact area marked.",
	]],
	"nuke_enemy": ["hq", [
		"{hq}: NUCLEAR LAUNCH DETECTED. All stations, this is not a drill. Take cover.",
		"Flash traffic, flash traffic: strategic launch. Interceptors, free to engage.",
	]],
	"intercept_ok": ["hq", [
		"{hq}: intercept confirmed, missile destroyed.",
		"Good kill on the inbound. Air defence, well done.",
	]],
	"capital_hit": ["hq", [
		"{hq}: capital is under fire! Hull integrity at {n} percent!",
		"Mayday, the capital is taking hits. {n} percent and falling!",
	]],
	"power_down": ["hq", [
		"{hq}: power grid is down. Powered defences are offline!",
		"We have lost power. SAMs and railguns are dark.",
	]],
	"recon_lost": ["unit", [
		"{cs}: recon asset lost. Eyes on that sector are gone.",
		"We lost the {name}. Sending another?",
	]],
	"retreat": ["unit", [
		"{cs}: heavily damaged, falling back to repair.",
		"{cs}: breaking off, returning to base.",
		"{cs}: I'm hit bad. Withdrawing.",
	]],
	"repaired": ["unit", [
		"{cs}: repairs complete, back in the fight.",
		"{cs}: green across the board. Returning to the line.",
	]],
	"smoke": ["unit", [
		"{cs}: popping smoke!",
		"{cs}: smoke out, covering the advance.",
	]],
	"dig_in": ["unit", [
		"{cs}: we're dug in. Let them come.",
	]],
	"fortify": ["unit", [
		"{cs}: building a fighting position here.",
		"{cs}: sandbags going up.",
	]],
	"unload": ["unit", [
		"{cs}: dismounting troops!",
		"{cs}: infantry out, out, out!",
	]],
	"ack_move": ["unit", ["{cs}: moving.", "{cs}: copy, on my way.", "{cs}: roger that.", "{cs}: wilco."]],
	"ack_attack": ["unit", ["{cs}: engaging.", "{cs}: attack move, weapons free.", "{cs}: advancing to contact."]],
	"ack_hold": ["unit", ["{cs}: holding position.", "{cs}: set and waiting.", "{cs}: copy, we hold."]],
	"enemy_comms": ["enemy", [
		"...repeat, armour is stuck at the river, we need a bridge...",
		"...send the bombers to grid {grid}, they are pushing too far...",
		"...their drones are everywhere, shoot anything that flies...",
		"...hold the line, reinforcements in ten minutes...",
		"...ammunition is low, request resupply at {grid}...",
		"...do not answer on this frequency, they are listening...",
	]],
}

var enabled := true                 # voice audio (subtitles always show)
var queue: Array = []
var log_lines: Array = []           # finished + current entries, newest last
var current: Dictionary = {}
var _timer := 0.0
var _gap := 0.0
var _cd: Dictionary = {}
var _cache: Dictionary = {}
var _player: AudioStreamPlayer
var _seq := 0
var _comm_t := 40.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = Sfx.bus_radio
	add_child(_player)


func reset() -> void:
	queue.clear()
	log_lines.clear()
	current = {}
	_timer = 0.0
	_cd.clear()
	_comm_t = randf_range(35.0, 70.0)
	_player.stop()
	Sfx.duck_music(false)


func toggle_voice() -> bool:
	enabled = not enabled
	if not enabled:
		_player.stop()
	return enabled


func hq_name(team: int = 0) -> String:
	var f := str(GameData.team_faction[clampi(team, 0, 1)])
	return str(HQ_NAMES.get(f, "Headquarters"))


func grid_ref(p: Vector2) -> String:
	var gx := clampi(int(p.x / 400.0), 0, 25)
	var gy := clampi(int((p.y - float(Water.Y_MIN)) / 400.0) + 1, 1, 9)
	return "%s-%d" % [char(65 + gx), gy]


func callsign_for(c) -> String:
	if c == null or not is_instance_valid(c):
		return hq_name(0)
	if c.callsign != "":
		return c.callsign
	var pool_key := "vehicle"
	var d: Dictionary = c.def
	if c.kind == "structure" or c.kind == "national" or c.kind == "base":
		c.callsign = str(d.get("name", c.id)).to_upper()
		return c.callsign
	if bool(d.get("scout", false)):
		pool_key = "drone"
	elif c.cls == "infantry":
		pool_key = "infantry"
	elif c.cls == "armor":
		pool_key = "armor"
	elif c.cls == "air":
		pool_key = "air"
	elif c.cls == "ship":
		pool_key = "ship"
	var pool: Array = CALLSIGNS[pool_key]
	var h := absi(int(hash(str(c.get_instance_id()))))
	c.callsign = "%s %d-%d" % [str(pool[h % pool.size()]), 1 + (h / 7) % 6, 1 + (h / 53) % 9]
	return c.callsign


## Queue a radio line for `event`. ctx keys (all optional): unit (Combatant), pos (Vector2), n, what, name, force (bool).
func say(event: String, ctx: Dictionary = {}) -> void:
	if not LINES.has(event):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var cd := float(COOLDOWN.get(event, 0.0))
	if cd > 0.0 and now - float(_cd.get(event, -999.0)) < cd and not bool(ctx.get("force", false)):
		return
	var spec: Array = LINES[event]
	var variants: Array = spec[1]
	var vi := randi() % variants.size()
	var text := str(variants[vi])
	var unit = ctx.get("unit", null)
	var pos := Vector2.ZERO
	var has_pos := false
	if ctx.has("pos"):
		pos = ctx["pos"]
		has_pos = true
	elif unit != null and is_instance_valid(unit):
		pos = unit.position
		has_pos = true
	var speaker_kind := str(spec[0])
	var speaker := hq_name(0)
	if speaker_kind == "unit":
		speaker = callsign_for(unit) if unit != null else hq_name(0)
	elif speaker_kind == "enemy":
		speaker = "INTERCEPT " + hq_name(1)
		if not has_pos:
			pos = Vector2(randf_range(1500.0, 5800.0), randf_range(-100.0, 1100.0))
	var nm := str(ctx.get("name", ""))
	if nm == "" and unit != null and is_instance_valid(unit):
		nm = str(unit.def.get("name", unit.id))
	text = text.replace("{cs}", speaker).replace("{hq}", hq_name(0)).replace("{grid}", grid_ref(pos)) \
		.replace("{n}", str(ctx.get("n", 1))).replace("{what}", str(ctx.get("what", "units"))).replace("{name}", nm)
	_cd[event] = now
	_seq += 1
	var entry := {"id": _seq, "event": event, "variant": vi + 1, "speaker": speaker, "text": text, "pos": pos,
		"has_pos": has_pos, "prio": int(PRIO.get(event, 0)), "kind": speaker_kind, "born": now}
	_enqueue(entry)


func _enqueue(entry: Dictionary) -> void:
	# stale chatter is useless: drop it when something important arrives behind it
	if int(entry["prio"]) >= 2:
		var i := 0
		while i < queue.size():
			if int(queue[i]["prio"]) == 0:
				queue.remove_at(i)
			else:
				i += 1
	if queue.size() >= MAX_QUEUE:
		var worst := 0
		for i in queue.size():
			if int(queue[i]["prio"]) < int(queue[worst]["prio"]):
				worst = i
		if int(queue[worst]["prio"]) > int(entry["prio"]):
			return
		queue.remove_at(worst)
	if int(entry["prio"]) >= 3:
		queue.push_front(entry)
	else:
		queue.append(entry)


func _process(delta: float) -> void:
	# random enemy chatter picked up by signals intelligence
	var b = get_tree().current_scene
	if b is Battle and not (b as Battle).over and not (b as Battle).prep and (b as Battle).elapsed > 20.0:
		_comm_t -= delta
		if _comm_t <= 0.0:
			_comm_t = randf_range(50.0, 95.0)
			say("enemy_comms")
	if not current.is_empty():
		_timer -= delta
		if _timer <= 0.0:
			current = {}
			_gap = 0.22
			if queue.is_empty():
				Sfx.duck_music(false)
		return
	if _gap > 0.0:
		_gap -= delta
		return
	if queue.is_empty():
		return
	# drop chatter that waited too long
	var now := Time.get_ticks_msec() / 1000.0
	var e: Dictionary = queue.pop_front()
	if int(e["prio"]) == 0 and now - float(e["born"]) > 6.0:
		return
	_start(e)


func _start(e: Dictionary) -> void:
	current = e
	log_lines.append(e)
	while log_lines.size() > MAX_LOG:
		log_lines.remove_at(0)
	var text := str(e["text"])
	_timer = 1.6 + float(text.length()) * 0.034
	e["start"] = Time.get_ticks_msec() / 1000.0
	if not enabled:
		return
	var st: AudioStream = Sfx.file_stream("radio_%s_%d" % [str(e["event"]), int(e["variant"])])
	if st == null:
		st = Sfx.file_stream("radio_%s" % str(e["event"]))
	var from_file := st != null
	if st == null:
		st = _synth(text, str(e["kind"]))
	if st == null:
		return
	_timer = maxf(st.get_length() + 0.15, 1.0)
	_player.stream = st
	_player.volume_db = 0.0 if from_file else -4.0
	_player.pitch_scale = 1.0
	_player.play()
	Sfx.duck_music(true)


## Jump target of the most recent line that carries a map position (the HUD uses it for the radio panel click).
func last_position() -> Variant:
	for i in range(log_lines.size() - 1, -1, -1):
		if bool(log_lines[i].get("has_pos", false)):
			return log_lines[i]["pos"]
	return null


# ------------------------------------------------------------- procedural voice
const VOWELS := [[730.0, 1090.0], [530.0, 1840.0], [270.0, 2290.0], [570.0, 840.0], [300.0, 870.0], [660.0, 1720.0]]


## A radio-ish babble: a glottal pulse train through two formant resonators, syllable envelopes, band-limiting,
## hard clipping and static, framed by a squelch click. Not speech - just the feel of a voice on a bad channel.
func _synth(text: String, kind: String) -> AudioStreamWAV:
	var key := kind + "|" + text
	if _cache.has(key):
		return _cache[key]
	var rate := 11025
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	var syl := clampi(text.length() / 3, 4, 34)
	var f_lo := 95.0
	var f_hi := 125.0
	if kind == "unit":
		f_lo = 115.0
		f_hi = 175.0
	elif kind == "enemy":
		f_lo = 140.0
		f_hi = 210.0
	var open_n := int(0.06 * float(rate))
	var tail_n := int(0.09 * float(rate))
	var out := PackedFloat32Array()
	var lp := 0.0
	var y1a := 0.0
	var y2a := 0.0
	var y1b := 0.0
	var y2b := 0.0
	var phase := 0.0
	# squelch open
	for i in open_n:
		var t := float(i) / float(open_n)
		out.append((rng.randf() * 2.0 - 1.0) * 0.5 * (1.0 - t) * (1.0 - t))
	var word_left := rng.randi_range(2, 4)
	for s in syl:
		var seg := rng.randf_range(0.085, 0.14)
		var n := int(seg * float(rate))
		var v: Array = VOWELS[rng.randi() % VOWELS.size()]
		var f0 := rng.randf_range(f_lo, f_hi)
		var drift := rng.randf_range(-0.18, 0.18)
		var amp := rng.randf_range(0.55, 1.0)
		var last_in_text := s == syl - 1
		var ra := exp(-TAU * 70.0 / float(rate))
		var ca := 2.0 * ra * cos(TAU * float(v[0]) / float(rate))
		var rb := exp(-TAU * 110.0 / float(rate))
		var cb := 2.0 * rb * cos(TAU * float(v[1]) / float(rate))
		for i in n:
			var t := float(i) / float(n)
			var env := sin(t * PI)
			env *= env
			if last_in_text:
				env *= (1.0 - t * 0.5)
			var f := f0 * (1.0 + drift * (t - 0.5))
			phase += f / float(rate)
			var pulse := 0.0
			if phase >= 1.0:
				phase -= 1.0
				pulse = 1.0
			var ya := pulse * (1.0 - ra) + ca * y1a - ra * ra * y2a
			y2a = y1a
			y1a = ya
			var yb := pulse * (1.0 - rb) + cb * y1b - rb * rb * y2b
			y2b = y1b
			y1b = yb
			var x := (ya * 5.0 + yb * 3.0) * env * amp
			lp += (x - lp) * 0.05
			x = x - lp                                     # crude high-pass: thin, telephone-like
			x = clampf(x * 1.8, -0.8, 0.8)                 # hard-ish clipping
			x += (rng.randf() * 2.0 - 1.0) * 0.035         # static
			out.append(x * 0.8)
		word_left -= 1
		if word_left <= 0:
			word_left = rng.randi_range(2, 4)
			var gap := int(rng.randf_range(0.04, 0.09) * float(rate))
			for i in gap:
				out.append((rng.randf() * 2.0 - 1.0) * 0.03)
	# squelch tail
	for i in tail_n:
		var t2 := float(i) / float(tail_n)
		out.append((rng.randf() * 2.0 - 1.0) * 0.45 * (1.0 - t2) * (1.0 - t2) * (1.0 if i < tail_n / 2 else 0.4))
	var st := Sfx.make_stream(out, rate)
	_cache[key] = st
	if _cache.size() > 160:
		_cache.erase(_cache.keys()[0])
	return st
