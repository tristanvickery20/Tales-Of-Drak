extends RefCounted
class_name DataRegistry

## DataRegistry v0.1
##
## Loads modular JSON records from design data.
## Local development source of truth lives at repo root: ../design.
## Web preview currently bypasses this loader inside test_world_controller.gd
## because iPhone Safari/Godot Web packaging has been unreliable for loose JSON.

const REQUIRED_TOP_LEVEL_KEYS := ["schema_version", "record_type", "records"]
const DESIGN_DIR_EXPORT := "res://design"
const DESIGN_DIR_LOCAL := "res://../design"
const DESIGN_FILE_NAMES := PackedStringArray([
	"abilities.json",
	"armor.json",
	"build_pieces.json",
	"classes.json",
	"crafting_recipes.json",
	"dungeons.json",
	"enemies.json",
	"gathering_nodes.json",
	"items.json",
	"mounts.json",
	"pets.json",
	"quests.json",
	"species.json",
	"subclasses.json",
	"weapons.json",
])

var _records_by_type: Dictionary = {}
var _record_counts: Dictionary = {}
var _loaded_files: PackedStringArray = []


func load_all_design_data() -> bool:
	clear()

	var design_path := _resolve_design_path()
	if design_path.is_empty():
		push_error("[DataRegistry] Design directory not found. Tried %s and %s" % [DESIGN_DIR_EXPORT, DESIGN_DIR_LOCAL])
		return false

	var file_names := _list_json_files(design_path)
	if file_names.is_empty():
		push_error("[DataRegistry] No JSON files found in: %s" % design_path)
		return false

	var all_ok := true
	for file_name in file_names:
		var full_path := "%s/%s" % [design_path, file_name]
		if not _load_file(full_path):
			all_ok = false

	if all_ok:
		print("[DataRegistry] Loaded %d files from %s" % [_loaded_files.size(), design_path])
		for record_type in _record_counts.keys():
			print("[DataRegistry] %s: %d records" % [record_type, _record_counts[record_type]])

	return all_ok


func clear() -> void:
	_records_by_type.clear()
	_record_counts.clear()
	_loaded_files.clear()


func get_record(record_type: String, id: String) -> Dictionary:
	if not _records_by_type.has(record_type):
		return {}
	return _records_by_type[record_type].get(id, {})


func get_records(record_type: String) -> Array:
	if not _records_by_type.has(record_type):
		return []
	var values: Array = []
	for value in _records_by_type[record_type].values():
		values.append(value)
	return values


func has_record(record_type: String, id: String) -> bool:
	return _records_by_type.has(record_type) and _records_by_type[record_type].has(id)


func get_record_counts() -> Dictionary:
	return _record_counts.duplicate(true)


func get_loaded_files() -> PackedStringArray:
	return _loaded_files


func _resolve_design_path() -> String:
	if FileAccess.file_exists("%s/items.json" % DESIGN_DIR_EXPORT):
		return DESIGN_DIR_EXPORT
	if FileAccess.file_exists("%s/items.json" % DESIGN_DIR_LOCAL):
		return DESIGN_DIR_LOCAL
	return ""


func _list_json_files(design_path: String) -> PackedStringArray:
	if design_path == DESIGN_DIR_EXPORT:
		return DESIGN_FILE_NAMES.duplicate()

	var file_names: PackedStringArray = []
	var dir := DirAccess.open(design_path)
	if dir == null:
		push_error("[DataRegistry] Could not open design directory: %s" % design_path)
		return file_names

	dir.list_dir_begin()
	while true:
		var next_name := dir.get_next()
		if next_name == "":
			break
		if dir.current_is_dir():
			continue
		if next_name.get_extension().to_lower() == "json":
			file_names.append(next_name)
	dir.list_dir_end()

	file_names.sort()
	return file_names


func _load_file(full_path: String) -> bool:
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		push_error("[DataRegistry] Missing or unreadable file: %s" % full_path)
		return false

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[DataRegistry] Invalid JSON object in file: %s" % full_path)
		return false

	var root: Dictionary = parsed
	for key in REQUIRED_TOP_LEVEL_KEYS:
		if not root.has(key):
			push_error("[DataRegistry] Missing top-level key '%s' in file: %s" % [key, full_path])
			return false

	if typeof(root["records"]) != TYPE_ARRAY:
		push_error("[DataRegistry] Key 'records' must be an array in file: %s" % full_path)
		return false

	var record_type := str(root["record_type"]).strip_edges()
	if record_type.is_empty():
		push_error("[DataRegistry] Empty record_type in file: %s" % full_path)
		return false

	if not _records_by_type.has(record_type):
		_records_by_type[record_type] = {}

	var records: Array = root["records"]
	for i in range(records.size()):
		var entry: Variant = records[i]
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("[DataRegistry] Record at index %d is not an object in file: %s" % [i, full_path])
			return false

		var record: Dictionary = entry
		if not record.has("id"):
			push_error("[DataRegistry] Missing record id at index %d in file: %s" % [i, full_path])
			return false

		var record_id := str(record["id"]).strip_edges()
		if record_id.is_empty():
			push_error("[DataRegistry] Empty record id at index %d in file: %s" % [i, full_path])
			return false

		if _records_by_type[record_type].has(record_id):
			push_error("[DataRegistry] Duplicate id '%s' for record_type '%s' in file: %s" % [record_id, record_type, full_path])
			return false

		_records_by_type[record_type][record_id] = record

	_record_counts[record_type] = _records_by_type[record_type].size()
	_loaded_files.append(full_path)
	return true
