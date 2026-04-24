extends RefCounted
class_name DataRegistry

## DataRegistry v0.1
##
## Loads modular JSON records from design data.
## Local development source of truth lives at repo root: ../design.
## Web exports can use bundled files, but the Web Preview pipeline also
## generates DesignDataEmbedded for maximum reliability on GitHub Pages.
## If both file-based and embedded loading fail, this registry falls back to a
## minimum Stage 8 sandbox dataset so the web preview remains playable.

const REQUIRED_TOP_LEVEL_KEYS := ["schema_version", "record_type", "records"]
const DESIGN_DIR_EXPORT := "res://design"
const DESIGN_DIR_LOCAL := "res://../design"
const EMBEDDED_DATA_SCRIPT := "res://scripts/generated/design_data_embedded.gd"
const DESIGN_FILE_NAMES := PackedStringArray([
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

	if _load_embedded_design_data():
		print("[DataRegistry] Loaded %d embedded design files" % _loaded_files.size())
		return true

	var design_path := _resolve_design_path()
	if not design_path.is_empty():
		var file_names := _list_json_files(design_path)
		var all_ok := not file_names.is_empty()
		for file_name in file_names:
			var full_path := "%s/%s" % [design_path, file_name]
			if not _load_file(full_path):
				all_ok = false

		if all_ok:
			print("[DataRegistry] Loaded %d files from %s" % [_loaded_files.size(), design_path])
			for record_type in _record_counts.keys():
				print("[DataRegistry] %s: %d records" % [record_type, _record_counts[record_type]])
			return true

	clear()
	push_warning("[DataRegistry] Design data file loading failed. Using minimum Stage 8 sandbox fallback data.")
	return _load_minimum_sandbox_data()


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


func _load_embedded_design_data() -> bool:
	var embedded_script: Resource = load(EMBEDDED_DATA_SCRIPT)
	if embedded_script == null:
		return false

	var embedded_instance: Variant = embedded_script.new()
	if embedded_instance == null:
		return false

	var embedded_files: Dictionary = embedded_instance.FILES
	if embedded_files.is_empty():
		return false

	var all_ok := true
	var file_names := embedded_files.keys()
	file_names.sort()
	for file_name in file_names:
		var raw_text := str(embedded_files[file_name])
		if not _load_raw_json(raw_text, "embedded://%s" % file_name):
			all_ok = false
	return all_ok


func _load_minimum_sandbox_data() -> bool:
	_add_record("species", {
		"id": "human",
		"name": "Human",
		"ability_bonuses": {"wisdom": 1},
		"movement_speed_bonus": 0,
	})
	_add_record("class", {
		"id": "warden",
		"name": "Warden",
		"role": "frontline_defender",
		"resource_type": "stamina",
		"starter_ability_bonuses": {"strength": 1, "constitution": 1},
	})
	_add_record("subclass", {
		"id": "ashen_guard",
		"class_id": "warden",
		"name": "Ashen Guard",
		"starter_ability_bonuses": {"constitution": 1},
	})

	_add_record("item", {"id": "starter_hatchet", "name": "Starter Hatchet", "item_type": "tool", "stack_size": 1, "rarity": "common", "value": 6, "tag_ids": ["tool", "hatchet", "starter"]})
	_add_record("item", {"id": "weathered_timber", "name": "Weathered Timber", "item_type": "material", "stack_size": 99, "rarity": "common", "value": 2, "tag_ids": ["wood", "gathered", "building"]})
	_add_record("item", {"id": "torch_kit", "name": "Torch Kit", "item_type": "utility", "stack_size": 20, "rarity": "common", "value": 8, "tag_ids": ["light", "dungeon", "starter"]})

	_add_record("gathering_node", {
		"id": "weathered_tree_deadfall",
		"display_name": "Weathered Deadfall",
		"required_tool_item_id": "starter_hatchet",
		"output_item_id": "weathered_timber",
		"output_quantity_min": 2,
		"output_quantity_max": 4,
		"respawn_seconds": 240,
	})
	_add_record("crafting_recipe", {
		"id": "craft_torch_kit",
		"recipe_id": "craft_torch_kit",
		"display_name": "Craft Torch Kit",
		"input_item_counts": {"weathered_timber": 1},
		"output_item_counts": {"torch_kit": 2},
		"required_station_id": "campfire",
		"crafting_seconds": 3,
	})
	_add_record("build_piece", {
		"id": "timber_foundation",
		"display_name": "Timber Foundation",
		"category": "foundation",
		"placement_type": "ground_snap",
		"required_item_counts": {"weathered_timber": 8},
		"max_health": 200,
		"tags": ["starter", "timber"],
	})

	_loaded_files.append("fallback://minimum_stage_8_sandbox_data")
	print("[DataRegistry] Loaded minimum Stage 8 sandbox fallback data")
	return true


func _add_record(record_type: String, record: Dictionary) -> void:
	if not _records_by_type.has(record_type):
		_records_by_type[record_type] = {}
	_records_by_type[record_type][str(record.get("id", ""))] = record
	_record_counts[record_type] = _records_by_type[record_type].size()


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
	return _load_raw_json(raw_text, full_path)


func _load_raw_json(raw_text: String, source_label: String) -> bool:
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[DataRegistry] Invalid JSON object in file: %s" % source_label)
		return false

	var root: Dictionary = parsed
	for key in REQUIRED_TOP_LEVEL_KEYS:
		if not root.has(key):
			push_error("[DataRegistry] Missing top-level key '%s' in file: %s" % [key, source_label])
			return false

	if typeof(root["records"]) != TYPE_ARRAY:
		push_error("[DataRegistry] Key 'records' must be an array in file: %s" % source_label)
		return false

	var record_type := str(root["record_type"]).strip_edges()
	if record_type.is_empty():
		push_error("[DataRegistry] Empty record_type in file: %s" % source_label)
		return false

	if not _records_by_type.has(record_type):
		_records_by_type[record_type] = {}

	var records: Array = root["records"]
	for i in range(records.size()):
		var entry: Variant = records[i]
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("[DataRegistry] Record at index %d is not an object in file: %s" % [i, source_label])
			return false

		var record: Dictionary = entry
		if not record.has("id"):
			push_error("[DataRegistry] Missing record id at index %d in file: %s" % [i, source_label])
			return false

		var record_id := str(record["id"]).strip_edges()
		if record_id.is_empty():
			push_error("[DataRegistry] Empty record id at index %d in file: %s" % [i, source_label])
			return false

		if _records_by_type[record_type].has(record_id):
			push_error("[DataRegistry] Duplicate id '%s' for record_type '%s' in file: %s" % [record_id, record_type, source_label])
			return false

		_records_by_type[record_type][record_id] = record

	_record_counts[record_type] = _records_by_type[record_type].size()
	_loaded_files.append(source_label)
	return true
