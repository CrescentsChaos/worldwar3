extends Node
## Loads all unit / weapon / balance data from res://data/units.json.
## Drop a modified copy at user://units.json to override the bundled one
## without touching the project (handy for balance mods).

const DATA_PATH := "res://data/units.json"
const USER_OVERRIDE := "user://units.json"

var settings: Dictionary = {}
var base: Dictionary = {}
var units: Dictionary = {}
var structures: Dictionary = {}
var national: Dictionary = {}       # country buildings: cities, factories, airbases, silos...
var strategic: Dictionary = {}
var projectiles: Dictionary = {}
var tabs: Array = []
var capabilities: Dictionary = {}   # capability id -> display name
var country: Array = []             # [[national_id, x_from_own_edge, y], ...]
var factions: Dictionary = {}       # army factions (prematch build), see units.json "factions"
var team_faction: Array = ["", ""]  # chosen faction id per team ("" = generic roster)
var team_strategy: Array = ["", ""]
var _team_cache: Array = [{}, {}]


func _ready() -> void:
	reload()


func reload() -> void:
	var parsed: Variant = null
	if FileAccess.file_exists(USER_OVERRIDE):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(USER_OVERRIDE))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("user://units.json is not valid JSON - using bundled data")
			parsed = null
	if parsed == null:
		parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not parse " + DATA_PATH)
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
	country = parsed.get("country", [])
	factions = parsed.get("factions", {})
	_team_cache = [{}, {}]
	for group in [units, structures, national, strategic]:
		for key in group:
			group[key]["id"] = key


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
	var d: Dictionary = base_def.duplicate(true)
	var f := faction_def(team)
	var names: Dictionary = f.get("names", {})
	if names.has(id):
		d["name"] = str(names[id])
	var ban: Array = f.get("ban", [])
	if ban.has(id):
		d["banned"] = true
	var mods: Array = []
	mods.append_array(f.get("mods", []))
	mods.append_array(strategy_def(team).get("mods", []))
	for m in mods:
		if _matches(str(m.get("match", "all")), kind, d):
			_apply_mod(d, m)
	cache[key] = d
	return d


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
