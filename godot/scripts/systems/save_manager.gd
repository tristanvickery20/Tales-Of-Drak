extends Node

## Save/Load manager using Godot user:// save path with JSON format.

const SAVE_PATH := "user://tales_of_drak_save.json"


func save_data(data: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Cannot open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No save file found.")
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Cannot open save file for reading.")
		return {}
	var text = file.get_as_text()
	if text.is_empty():
		return {}
	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		push_error("[SaveManager] JSON parse error: ", json.get_error_message())
		return {}
	var data = json.get_data()
	if data == null or not data is Dictionary:
		return {}
	return data as Dictionary
