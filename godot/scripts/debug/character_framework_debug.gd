extends Node

## Stage 4 debug entry point.
## Loads DataRegistry, builds one sample character, and prints a compact summary.

func _ready() -> void:
	var registry := DataRegistry.new()
	var loaded := registry.load_all_design_data()
	print("[CharacterFrameworkDebug] load_all_design_data() => %s" % loaded)
	if not loaded:
		print("[CharacterFrameworkDebug] Failed to load design data.")
		return

	var species_records := registry.get_records("species")
	var class_records := registry.get_records("class")
	var subclass_records := registry.get_records("subclass")

	print("[CharacterFrameworkDebug] available species: %d" % species_records.size())
	print("[CharacterFrameworkDebug] available classes: %d" % class_records.size())
	print("[CharacterFrameworkDebug] available subclasses: %d" % subclass_records.size())

	if species_records.is_empty() or class_records.is_empty() or subclass_records.is_empty():
		print("[CharacterFrameworkDebug] Missing required character records.")
		return

	var sample_species_id := str(species_records[0]["id"])
	var sample_class_id := str(class_records[0]["id"])

	# Pick a subclass that belongs to the selected class if possible.
	var sample_subclass_id := ""
	for subclass_record in subclass_records:
		if str(subclass_record.get("class_id", "")) == sample_class_id:
			sample_subclass_id = str(subclass_record["id"])
			break
	if sample_subclass_id.is_empty():
		sample_subclass_id = str(subclass_records[0]["id"])

	var factory := CharacterFactory.new()
	var character := factory.create_level_one_character(
		registry,
		"Debug Hero",
		sample_species_id,
		sample_class_id,
		sample_subclass_id
	)

	if character == null:
		print("[CharacterFrameworkDebug] CharacterFactory returned null.")
		return

	print("[CharacterFrameworkDebug] Sample character summary:")
	print(JSON.stringify(character.to_summary_dict(), "  "))
