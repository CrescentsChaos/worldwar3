extends Node
## JSON save files in user://saves/. Slots: slot1..slot3 (manual) and auto.

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 3
const SLOTS := ["slot1", "slot2", "slot3", "auto"]

## Set by the main menu before switching to the battle scene.
var pending_load: String = ""
var pending_map: String = ""         # battlefield id chosen in the pre-match screen ("" = default map)
var pending_difficulty: String = "normal"
## Armies chosen on the prematch screen ("" = generic roster, e.g. when a tool starts a battle directly).
var pending_p_faction: String = ""
var pending_p_strategy: String = ""
var pending_e_faction: String = ""
var pending_e_strategy: String = ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"


func slot_label(slot: String) -> String:
	if slot == "auto":
		return "Autosave"
	return "Slot " + slot.trim_prefix("slot")


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_game(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func delete_save(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


func slot_summary(slot: String) -> String:
	if not has_save(slot):
		return "%s  -  empty" % slot_label(slot)
	var d := load_game(slot)
	if d.is_empty():
		return "%s  -  corrupted" % slot_label(slot)
	var t := int(d.get("elapsed", 0))
	var money: Array = d.get("money", [0, 0])
	return "%s  -  %s  -  %02d:%02d  -  %s  -  $%d" % [
		slot_label(slot), str(d.get("saved_at", "?")).replace("T", " "),
		t / 60, t % 60, str(d.get("difficulty", "normal")).capitalize(), int(money[0])]
