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
func items_for_tab(tab: String) -> Array:
	var out: Array = []
	for id in units:
		if units[id].get("tab", "") == tab: out.append(["unit", id])
	for id in structures:
		if structures[id].get("tab", "") == tab: out.append(["structure", id])
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
