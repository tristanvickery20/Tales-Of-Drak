extends Node

## Lightweight global runtime state for the current prototype session.
## Stage 14 uses this to carry the character creator selection into the test world.

var character_name: String = "Adventurer"
var species_id: String = "human"
var species_name: String = "Human"
var class_id: String = "fighter"
var class_name: String = "Fighter"
var subclass_id: String = "champion"
var subclass_name: String = "Champion"
var has_custom_character: bool = false


func set_character(selection: Dictionary) -> void:
	character_name = str(selection.get("character_name", "Adventurer")).strip_edges()
	if character_name.is_empty():
		character_name = "Adventurer"
	species_id = str(selection.get("species_id", "human"))
	species_name = str(selection.get("species_name", "Human"))
	class_id = str(selection.get("class_id", "fighter"))
	class_name = str(selection.get("class_name", "Fighter"))
	subclass_id = str(selection.get("subclass_id", "champion"))
	subclass_name = str(selection.get("subclass_name", "Champion"))
	has_custom_character = true


func get_character_summary() -> String:
	return "%s — %s %s / %s" % [character_name, species_name, class_name, subclass_name]


func get_selection() -> Dictionary:
	return {
		"character_name": character_name,
		"species_id": species_id,
		"species_name": species_name,
		"class_id": class_id,
		"class_name": class_name,
		"subclass_id": subclass_id,
		"subclass_name": subclass_name,
		"has_custom_character": has_custom_character,
	}
