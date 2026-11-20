extends Node
## Loads all unit / weapon / balance / map data from the res://data/ folder.
##
## The data is split into small files (see tools/datafiles.py for the full layout):
##   settings.json  logistics.json  projectiles.json  national.json  strategic.json  country.json
##   units/<tab>.json   structures/<tab>.json   factions/<army>.json   maps/<map>.json
## Every file is a dictionary; the files of a folder are merged. To mod without touching the project,
## put a file with the same relative path under user://data/ (it replaces the bundled one) or add NEW files
## to user://data/units/ etc. (their entries are merged in). A legacy single-file user://units.json still
## works and replaces the whole bundled data set.

const DATA_DIR := "res://data/"
const USER_DIR := "user://data/"
const LEGACY_USER := "user://units.json"

var settings: Dictionary = {}
var base: Dictionary = {}
var units: Dictionary = {}
var structures: Dictionary = {}
var national: Dictionary = {}       # country buildings: cities, factories, airbases, silos...
var strategic: Dictionary = {}
var projectiles: Dictionary = {}
var tabs: Array = []
var capabilities: Dictionary = {}   # capability id -> display name
var country: Array = []             # [[national_id, x_from_own_edge, y], ...] of the current map
var factions: Dictionary = {}       # army factions (prematch build), see data/factions
var logistics: Dictionary = {}      # mobility, ammo, transport, flight and sector tuning (data/logistics.json)
var maps: Dictionary = {}           # map id -> map definition (data/maps)
var default_country: Array = []
var current_map := "dnieper"
var team_faction: Array = ["", ""]  # chosen faction id per team ("" = generic roster)
var team_strategy: Array = ["", ""]
var _team_cache: Array = [{}, {}]
var _stat_max: Dictionary = {}


func _ready() -> void:
	reload()


# ------------------------------------------------------------------ file helpers

func _path_for(rel: String) -> String:
	if FileAccess.file_exists(USER_DIR + rel):
		return USER_DIR + rel
	return DATA_DIR + rel


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_warning("Invalid JSON: " + path)
	return parsed


func _read_dict(rel: String) -> Dictionary:
	var v: Variant = _read_json(_path_for(rel))
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v
		return d
	return {}


## Names of the .json files of a data sub folder, bundled and user-added, sorted.
func _json_names(sub: String) -> Array:
	var seen := {}
	for root in [DATA_DIR, USER_DIR]:
		var da := DirAccess.open(str(root) + sub)
		if da == null:
			continue
		for f in da.get_files():
			var fname: String = f
			if fname.ends_with(".json"):
				seen[fname] = true
	var names: Array = seen.keys()
	names.sort()
	return names


## Merges every <sub>/*.json (each file is {id: definition}).
func _merge_folder(sub: String) -> Dictionary:
	var out: Dictionary = {}
	for n in _json_names(sub):
		var part: Dictionary = _read_dict(sub + "/" + str(n))
		for k in part:
			out[k] = part[k]
	return out


## Every <sub>/<id>.json is one entry keyed by its file name (factions, maps).
func _keyed_folder(sub: String) -> Dictionary:
	var out: Dictionary = {}
	for n in _json_names(sub):
		var fname: String = str(n)
		out[fname.trim_suffix(".json")] = _read_dict(sub + "/" + fname)
	return out


func _load_split() -> Dictionary:
	var data: Dictionary = {}
	var st: Dictionary = _read_dict("settings.json")
	for k in st:
		data[k] = st[k]
	data["logistics"] = _read_dict("logistics.json")
	var ctry: Variant = _read_json(_path_for("country.json"))
	data["country"] = ctry if typeof(ctry) == TYPE_ARRAY else []
	for key in ["projectiles", "national", "strategic"]:
		data[key] = _read_dict(str(key) + ".json")
	data["units"] = _merge_folder("units")
	data["structures"] = _merge_folder("structures")
	data["factions"] = _keyed_folder("factions")
	data["maps"] = _keyed_folder("maps")
	return data


func reload() -> void:
	var parsed: Dictionary = {}
	if FileAccess.file_exists(LEGACY_USER):
		var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_USER))
		if typeof(legacy) == TYPE_DICTIONARY:
			parsed = legacy
		else:
			push_warning("user://units.json is not valid JSON - using bundled data")
	if parsed.is_empty():
		parsed = _load_split()
	if parsed.get("units", {}).is_empty():
		push_error("Could not load game data from " + DATA_DIR)
		return
	settings = parsed.get("settings", {})
	base = parsed.get("base", {})
	base["id"] = "hq"
	base["hp"] = float(settings.get("base_hp", base.get("hp", 5000)))
	units = parsed.get("units", {})
	structures = parsed.get("structures", {})
	national = parsed.get("national", {})
	strategic = parsed.get("strategic", {})
	projectiles = parsed.get("projectiles", {})
	tabs = parsed.get("tabs", [])
	capabilities = parsed.get("capabilities", {})
	default_country = parsed.get("country", [])
	factions = parsed.get("factions", {})
	logistics = parsed.get("logistics", {})
	maps = parsed.get("maps", {})
	_team_cache = [{}, {}]
	_stat_max = {}
	for group in [units, structures, national, strategic]:
		for key in group:
			group[key]["id"] = key
	set_map(str(settings.get("map", "dnieper")))


# ------------------------------------------------------------------ maps

## Picks the battlefield. Unknown ids fall back to the first map (or the old procedural one if there are none).
func set_map(id: String) -> void:
	if id == "":
		id = str(settings.get("map", "dnieper"))
	if not maps.has(id):
		if maps.is_empty():
			current_map = ""
			country = default_country
			return
		id = str(maps.keys()[0])
	current_map = id
	var m: Dictionary = maps[id]
	var c: Variant = m.get("country", default_country)
	country = c if typeof(c) == TYPE_ARRAY else default_country


func map_def() -> Dictionary:
	if maps.has(current_map):
		var m: Dictionary = maps[current_map]
		return m
	return {"procedural": true, "name": "Classic", "coast": {"half": 760.0, "bay_depth": 250.0, "bay_sigma": 420.0, "bay_x": 3200.0},
		"roads": [], "sectors": [], "waterways": [], "bridges": [], "forests": {"count": 420, "min": 4, "max": 8}, "craters": 520}


func map_ids() -> Array:
	var ids: Array = maps.keys()
	ids.sort()
	return ids


## logistics.json helpers -------------------------------------------------
func logi(section: String, key: String, fallback: Variant) -> Variant:
	var sec: Dictionary = logistics.get(section, {})
	return sec.get(key, fallback)


func supply_cost(cls: String) -> float:
	var a: Dictionary = logistics.get("ammo", {})
	var sc: Dictionary = a.get("supply_cost", {})
	return float(sc.get(cls, 5.0))


func mobility(drive: String) -> Dictionary:
	var mob: Dictionary = logistics.get("mobility", {})
	var d: Dictionary = mob.get(drive, {})
	return d


## kind: "unit" | "structure" | "national" | "strategic" | "base"
func get_def(kind: String, id: String) -> Dictionary:
	match kind:
		"unit": return units.get(id, {})
		"structure": return structures.get(id, {})
		"national": return national.get(id, {})
		"strategic": return strategic.get(id, {})
		"base": return base
	return {}


## Returns [[kind, id], ...] for every deployable item in a tab, in file order.
func items_for_tab(tab: String, team: int = -1) -> Array:
	var out: Array = []
	for id in units:
		if units[id].get("tab", "") == tab and (team < 0 or not is_banned(team, "unit", id)): out.append(["unit", id])
	for id in structures:
		if structures[id].get("tab", "") == tab and (team < 0 or not is_banned(team, "structure", id)): out.append(["structure", id])
	for id in national:
		if national[id].get("tab", "") == tab: out.append(["national", id])
	for id in strategic:
		if strategic[id].get("tab", "") == tab: out.append(["strategic", id])
	return out


## The capabilities an item needs (a country building that provides them must be alive).
func requirements(d: Dictionary) -> Array:
	var r: Variant = d.get("requires", [])
	if typeof(r) == TYPE_STRING:
		return [r] if str(r) != "" else []
	if typeof(r) == TYPE_ARRAY:
		return r
	return []


func cap_name(cap: String) -> String:
	return str(capabilities.get(cap, cap))


## Id of the first national building type that provides a capability ("" if none).
func national_providing(cap: String) -> String:
	for id in national:
		var prov: Array = national[id].get("provides", [])
		if prov.has(cap):
			return id
	return ""


## Global size multiplier for every sprite, hit radius and label (settings.sprite_scale in units.json).
func sprite_scale() -> float:
	return maxf(float(settings.get("sprite_scale", 1.4)), 0.2)


# ------------------------------------------------------------------ army factions (prematch build)

## Picks the armies for this match. Unknown ids fall back to the generic roster.
func set_teams(p_faction: String, p_strategy: String, e_faction: String, e_strategy: String) -> void:
	team_faction = [p_faction if factions.has(p_faction) else "", e_faction if factions.has(e_faction) else ""]
	team_strategy = [p_strategy, e_strategy]
	for t in 2:
		if str(team_faction[t]) == "" or strategy_def(t).is_empty():
			team_strategy[t] = ""
	_team_cache = [{}, {}]


func faction_def(team: int) -> Dictionary:
	if team < 0 or team > 1:
		return {}
	var f: Dictionary = factions.get(str(team_faction[team]), {})
	return f


func strategy_def(team: int) -> Dictionary:
	var f := faction_def(team)
	if f.is_empty():
		return {}
	var ss: Dictionary = f.get("strategies", {})
	var s: Dictionary = ss.get(str(team_strategy[team]), {})
	return s


func income_mult(team: int) -> float:
	return float(faction_def(team).get("income", 1.0)) * float(strategy_def(team).get("income", 1.0))


func money_mult(team: int) -> float:
	return float(faction_def(team).get("money", 1.0)) * float(strategy_def(team).get("money", 1.0))


## AI play style of a team's strategy: balanced | offense | defense | air | naval | missile | infantry
func strategy_style(team: int) -> String:
	return str(strategy_def(team).get("style", "balanced"))


func setup_for(team: int) -> Array:
	var a: Array = strategy_def(team).get("setup", [])
	return a


func team_label(team: int) -> String:
	var f := faction_def(team)
	if f.is_empty():
		return "Generic Army"
	var s := strategy_def(team)
	return str(f.get("name", "?")) + (" - " + str(s.get("name", "")) if not s.is_empty() else "")


func is_banned(team: int, kind: String, id: String) -> bool:
	return bool(def_for(team, kind, id).get("banned", false))


## The definition of an item as THIS team sees it: faction names, bans and cost / stat modifiers applied.
## Items are cached per team; with no faction this is just get_def().
func def_for(team: int, kind: String, id: String) -> Dictionary:
	var base_def: Dictionary = get_def(kind, id)
	if base_def.is_empty() or team < 0 or team > 1 or str(team_faction[team]) == "":
		return base_def
	var cache: Dictionary = _team_cache[team]
	var key := kind + ":" + id
	if cache.has(key):
		var hit: Dictionary = cache[key]
		return hit
	var d: Dictionary = _build_def(str(team_faction[team]), str(team_strategy[team]), kind, id)
	cache[key] = d
	return d


## Same as def_for() but for an explicit army (used by the Arsenal browser on the prematch screen).
func def_for_faction(faction_id: String, kind: String, id: String, strategy_id: String = "") -> Dictionary:
	var base_def: Dictionary = get_def(kind, id)
	if base_def.is_empty() or not factions.has(faction_id):
		return base_def
	return _build_def(faction_id, strategy_id, kind, id)


## Slot definition -> army definition. An army's `roster` entry is a COMPLETE replacement of the slot's
## stats, name, class, specs and description (not a rename); `names` is only a fallback for armies
## without a roster entry. Doctrine mods are applied on top.
func _build_def(faction_id: String, strategy_id: String, kind: String, id: String) -> Dictionary:
	var d: Dictionary = get_def(kind, id).duplicate(true)
	var f: Dictionary = factions.get(faction_id, {})
	var roster: Dictionary = f.get("roster", {})
	if roster.has(id):
		var r: Dictionary = roster[id]
		for k in r:
			var v: Variant = r[k]
			if v is Dictionary or v is Array:
				v = v.duplicate(true)
			d[k] = v
	else:
		var names: Dictionary = f.get("names", {})
		if names.has(id):
			d["name"] = str(names[id])
	d["faction"] = faction_id
	var ban: Array = f.get("ban", [])
	if ban.has(id):
		d["banned"] = true
	var mods: Array = []
	mods.append_array(f.get("mods", []))
	var ss: Dictionary = f.get("strategies", {})
	var strat: Dictionary = ss.get(strategy_id, {})
	mods.append_array(strat.get("mods", []))
	for m in mods:
		if _matches(str(m.get("match", "all")), kind, d):
			_apply_mod(d, m)
	return d


# ------------------------------------------------------------------ datasheet helpers

## Damage per second as shown on datasheets (a kamikaze's single blast is averaged over 2.5 s).
func dps_of(d: Dictionary) -> float:
	var dmg := float(d.get("damage", 0.0))
	if dmg <= 0.0:
		return 0.0
	if bool(d.get("kamikaze", false)):
		return dmg / 2.5
	return dmg / maxf(float(d.get("cooldown", 1.0)), 0.05)


## Largest value of each stat within a tab, across the generic roster AND every army's roster, so
## the bars on a datasheet are comparable between armies. Cached; cleared on reload().
func stat_max(tab: String) -> Dictionary:
	if _stat_max.has(tab):
		var hit: Dictionary = _stat_max[tab]
		return hit
	var m := {"hp": 1.0, "armor": 1.0, "dps": 1.0, "range": 1.0, "speed": 1.0, "damage": 1.0, "splash": 1.0}
	var all_defs: Array = []
	for group in [units, structures, strategic]:
		for k in group:
			all_defs.append(group[k])
	for fid in factions:
		var ro: Dictionary = factions[fid].get("roster", {})
		for id in ro:
			var bd: Dictionary = {}
			for group in [units, structures, strategic]:
				if group.has(id):
					bd = group[id]
			if bd.is_empty():
				continue
			var merged: Dictionary = bd.duplicate()
			merged.merge(ro[id], true)
			all_defs.append(merged)
	for dd in all_defs:
		var dict: Dictionary = dd
		if str(dict.get("tab", "")) != tab:
			continue
		m["hp"] = maxf(float(m["hp"]), float(dict.get("hp", 0.0)))
		m["armor"] = maxf(float(m["armor"]), float(dict.get("armor", 0.0)))
		m["dps"] = maxf(float(m["dps"]), dps_of(dict))
		m["range"] = maxf(float(m["range"]), float(dict.get("range", 0.0)))
		m["speed"] = maxf(float(m["speed"]), float(dict.get("speed", 0.0)))
		m["damage"] = maxf(float(m["damage"]), float(dict.get("damage", 0.0)))
		m["splash"] = maxf(float(m["splash"]), float(dict.get("splash", 0.0)))
	_stat_max[tab] = m
	return m


func _matches(rule: String, kind: String, d: Dictionary) -> bool:
	if rule == "all":
		return true
	var p := rule.split(":")
	if p.size() < 2:
		return false
	match p[0]:
		"kind":
			return kind == p[1]
		"tab":
			return str(d.get("tab", "")) == p[1]
		"role":
			return str(d.get("role", "")) == p[1]
		"id":
			return str(d.get("id", "")) == p[1]
	return false


func _apply_mod(d: Dictionary, m: Dictionary) -> void:
	for k in m:
		if str(k) == "match" or not d.has(k):
			continue
		var t := typeof(d[k])
		if t != TYPE_FLOAT and t != TYPE_INT:
			continue
		d[k] = float(d[k]) * float(m[k])
	if m.has("cost") and d.has("cost"):
		d["cost"] = roundf(float(d["cost"]))


## Human-readable perk lines for the prematch screen, generated from the data.
func describe_mods(mods: Array) -> Array:
	var out: Array = []
	for m in mods:
		var parts := PackedStringArray()
		for k in m:
			if str(k) == "match":
				continue
			var pct := int(round((float(m[k]) - 1.0) * 100.0))
			parts.append("%s %s%d%%" % [_stat_label(str(k)), "+" if pct >= 0 else "", pct])
		out.append("%s: %s" % [_match_label(str(m.get("match", "all"))), ", ".join(parts)])
	return out


func _stat_label(k: String) -> String:
	match k:
		"hp": return "HP"
		"deploy_cd": return "deploy delay"
		"splash": return "blast"
	return k


func _match_label(rule: String) -> String:
	if rule == "all":
		return "Everything"
	var p := rule.split(":")
	if p.size() < 2:
		return rule
	match p[0]:
		"tab":
			return {"infantry": "Infantry", "vehicles": "Vehicles", "air": "Air units", "navy": "Navy", "defenses": "Defenses"}.get(p[1], p[1].capitalize())
		"kind":
			return {"structure": "Defenses", "unit": "Units", "strategic": "Missiles"}.get(p[1], p[1].capitalize())
		"role":
			return p[1].replace("_", " ").capitalize()
		"id":
			var dd: Dictionary = units.get(p[1], structures.get(p[1], strategic.get(p[1], {})))
			return str(dd.get("name", p[1]))
	return rule
