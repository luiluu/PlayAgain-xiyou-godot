extends Node
## 【Codex·未经Claude检验】 Mode routing only; no player saves are read or written.

const MODE_FILE := "res://content/modes.json"
var modes: Array = []
var current_mode: String = ""

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(MODE_FILE))
	if not data is Dictionary or not data.get("modes") is Array:
		push_error("Invalid mode registry")
		return
	modes = data["modes"]

func get_mode(mode_id: String) -> Dictionary:
	for mode in modes:
		if mode is Dictionary and mode.get("id", "") == mode_id:
			return mode
	return {}

func enter_mode(mode_id: String) -> bool:
	var mode := get_mode(mode_id)
	if mode.is_empty() or not mode.get("enabled", false):
		return false
	var scene = mode.get("entryScene")
	if not scene is String or not ResourceLoader.exists(scene):
		return false
	var previous := current_mode
	current_mode = mode_id
	var result := get_tree().change_scene_to_file(scene)
	if result != OK:
		current_mode = previous
		return false
	return true

func return_to_menu() -> void:
	current_mode = ""
	get_tree().change_scene_to_file("res://scenes/entry_menu.tscn")

func save_directory() -> String:
	var mode := get_mode(current_mode)
	if mode.is_empty():
		return ""
	return "user://modes/" + str(mode["saveNamespace"])
