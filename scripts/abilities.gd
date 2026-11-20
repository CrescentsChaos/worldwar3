class_name Abilities
extends RefCounted
## Utility abilities: what a unit / building can do besides shooting (v6).
## Every item gets a default set from its role (see for_def); data can override with  "abilities": ["smoke", ...]
## (an empty list = none).  Extra tuning keys in units.json: vision, mark_radius, radar_radius, sonar_radius, smoke_radius.
##
## PASSIVE (always on)
##   dig_in      standing still for ~2.5 s entrenches the unit: +3 armour and 20% less damage taken until it moves
##   siege       artillery that stands still for ~3 s deploys: +25% range until it moves
##   suppress    hits pin enemy infantry: they move at half speed for a moment
##   designate   paints enemies in sight: painted targets take +25% damage from everybody and stay visible (spotter / sniper / scout)
##   radar       detects stealth aircraft in a radius, so SAMs / AA get their full range against them
##   sonar       detects submarines and divers in a radius
##   withdraw    badly damaged units fall back to a repair point (depot / hospital / airbase / port / capital), are fixed up and return
## ACTIVE (key Z on the selection; AI units use them on their own)
##   smoke       drops a smoke screen: ground units inside it cannot be targeted from range
##   fortify     builds a sandbag MG nest in front of the unit (engineers)
##   unload      dismounts the carried infantry right now (APCs)

const INFO := {
	"dig_in": {"name": "Dig In", "active": false, "desc": "Stands still for a moment: +3 armour, 20% less damage taken until it moves."},
	"siege": {"name": "Siege Deploy", "active": false, "desc": "Standing still for a moment extends range by 25% until it moves."},
	"suppress": {"name": "Suppression", "active": false, "desc": "Its fire pins enemy infantry: they slow to half speed."},
	"designate": {"name": "Designate Targets", "active": false, "desc": "Paints enemies in sight: +25% damage taken from all your forces, and they stay visible."},
	"radar": {"name": "Radar", "active": false, "desc": "Detects stealth aircraft nearby so air defence can engage them at full range."},
	"sonar": {"name": "Sonar", "active": false, "desc": "Detects submarines and divers nearby."},
	"withdraw": {"name": "Fall Back & Repair", "active": false, "desc": "When badly damaged it retreats to a repair point, gets fixed, then returns."},
	"smoke": {"name": "Smoke Screen", "active": true, "cd": 28.0, "desc": "Drops smoke: ground units inside cannot be targeted from range (Z)."},
	"fortify": {"name": "Fortify", "active": true, "cd": 45.0, "desc": "Builds a sandbag MG nest in front of the unit for free (Z)."},
	"unload": {"name": "Dismount Troops", "active": true, "cd": 5.0, "desc": "Unloads the carried infantry immediately (U or Z)."},
}


static func is_active(id: String) -> bool:
	return bool(INFO.get(id, {}).get("active", false))


static func ability_name(id: String) -> String:
	return str(INFO.get(id, {}).get("name", id))


static func for_def(kind: String, d: Dictionary) -> Array:
	if d.has("abilities"):
		var ex: Variant = d["abilities"]
		return ex if typeof(ex) == TYPE_ARRAY else []
	var out: Array = []
	var id := str(d.get("id", ""))
	if kind == "strategic" or kind == "base":
		return out
	if kind == "structure" or kind == "national":
		if d.has("trap"):
			return out
		var prov: Array = d.get("provides", [])
		if prov.has("radar") or bool(d.get("radar_boost", false)):
			out.append("radar")
		if ["watchtower", "observation_post", "sniper_nest"].has(id) or d.has("aura"):
			out.append("designate")
		return out
	if bool(d.get("kamikaze", false)) or bool(d.get("strafe", false)):
		return out
	if float(d.get("speed", 0.0)) <= 0.0:
		return out
	var tab := str(d.get("tab", ""))
	var role := str(d.get("role", ""))
	var dom := str(d.get("domain", "land"))
	var scout := bool(d.get("scout", false))
	if scout:
		out.append("designate")
	match tab:
		"infantry":
			if role == "support":
				if id == "engineer":
					out.append("fortify")
				if d.has("aura"):
					out.append("designate")
				out.append("dig_in")
			else:
				if ["sniper", "marksman", "commando"].has(id):
					out.append("designate")
				if ["mg_gunner", "assault", "riot_trooper", "shotgunner"].has(id):
					out.append("suppress")
				if role == "artillery":
					out.append("siege")
				out.append("dig_in")
			out.append("withdraw")
		"vehicles":
			if role == "artillery":
				out.append("siege")
			elif role == "anti_air":
				out.append("radar")
			else:
				out.append("smoke")
			if d.has("cargo") or d.has("seats"):
				out.append("unload")
			if ["jeep", "armored_car"].has(id):
				out.append("designate")
			if ["armored_car", "apc", "tank", "heavy_tank", "mammoth"].has(id):
				out.append("suppress")
			out.append("withdraw")
		"air":
			if id == "helicopter" or id == "gunship":
				out.append("suppress")
			if id == "helicopter":
				out.append("sonar")
			if role == "anti_air" or id == "interceptor_jet":
				out.append("radar")
			if d.has("seats"):
				out.append("unload")
			out.append("withdraw")
		"navy":
			if dom == "sub":
				out.append("sonar")
			elif dom == "amphib":
				out.append("withdraw")
			else:
				if role == "carrier" or id == "cruiser" or id == "battleship":
					out.append("radar")
				if id == "destroyer" or id == "frigate" or id == "torpedo_boat":
					out.append("sonar")
				if role != "carrier":
					out.append("smoke")
				out.append("withdraw")
	return out


## How far a unit sees (fog of war + spotting). Data key "vision" wins.
static func vision_for(kind: String, d: Dictionary, cls: String) -> float:
	var mult := float(GameData.settings.get("vision_mult", 1.0))
	if d.has("vision"):
		return float(d["vision"]) * mult
	if kind == "strategic":
		return 0.0
	var base := 250.0
	match cls:
		"infantry":
			base = 230.0
		"armor":
			base = 250.0
		"vehicle":
			base = 280.0
		"ship":
			base = 420.0
		"air":
			base = 620.0
		"structure":
			base = 330.0
	if kind == "base":
		base = 560.0
	var prov: Array = d.get("provides", [])
	if prov.has("radar"):
		base = 950.0
	if d.has("aura") or str(d.get("id", "")) == "watchtower":
		base = maxf(base, 520.0)
	var rng := float(d.get("range", 0.0))
	base = maxf(base, minf(rng, 520.0) * 0.9)
	return base * mult


static func radar_radius(d: Dictionary) -> float:
	var prov: Array = d.get("provides", [])
	var dflt := 900.0 if prov.has("radar") else 520.0
	return float(d.get("radar_radius", dflt))


static func sonar_radius(d: Dictionary) -> float:
	return float(d.get("sonar_radius", 380.0))
