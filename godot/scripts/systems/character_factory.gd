extends RefCounted
class_name CharacterFactory

## CharacterFactory v0.1
##
## Builds a PlayerCharacter from DataRegistry records.
## Validation and defaults are intentionally strict and explicit.

const BASE_ABILITY_SCORE := 10
const BASE_MOVEMENT_SPEED := 30

const ABILITY_KEYS := [
	"strength",
	"dexterity",
	"constitution",
	"intelligence",
	"wisdom",
	"charisma"
]


func create_level_one_character(
	registry: DataRegistry,
	display_name: String,
	species_id: String,
	class_id: String,
	subclass_id: String
) -> PlayerCharacter:
	if registry == null:
		push_error("[CharacterFactory] DataRegistry is null.")
		return null

	if not _validate_ids(registry, species_id, class_id, subclass_id):
		return null

	var subclass_record := registry.get_record("subclass", subclass_id)
	if subclass_record.get("class_id", "") != class_id:
		push_error("[CharacterFactory] Subclass '%s' does not belong to class '%s'." % [subclass_id, class_id])
		return null

	var character := PlayerCharacter.new()
	character.character_id = _build_character_id(display_name, class_id)
	character.display_name = display_name.strip_edges()
	character.species_id = species_id
	character.class_id = class_id
	character.subclass_id = subclass_id
	character.level = 1
	character.xp = 0

	_apply_default_abilities(character)

	# Apply optional data-driven bonuses from species/class/subclass.
	_apply_ability_bonuses(character, registry.get_record("species", species_id).get("ability_bonuses", {}))
	_apply_ability_bonuses(character, registry.get_record("class", class_id).get("starter_ability_bonuses", {}))
	_apply_ability_bonuses(character, subclass_record.get("starter_ability_bonuses", {}))

	var species_movement_bonus := int(registry.get_record("species", species_id).get("movement_speed_bonus", 0))
	character.derived_stats["max_health"] = StatCalculator.calculate_max_health(character.level, character.ability_scores["constitution"])
	character.derived_stats["armor_class"] = StatCalculator.calculate_armor_class(character.ability_scores["dexterity"])
	character.derived_stats["initiative"] = StatCalculator.calculate_initiative(character.ability_scores["dexterity"])
	character.derived_stats["movement_speed"] = StatCalculator.calculate_movement_speed(BASE_MOVEMENT_SPEED, species_movement_bonus)

	return character


func _validate_ids(registry: DataRegistry, species_id: String, class_id: String, subclass_id: String) -> bool:
	if not registry.has_record("species", species_id):
		push_error("[CharacterFactory] Unknown species_id: %s" % species_id)
		return false
	if not registry.has_record("class", class_id):
		push_error("[CharacterFactory] Unknown class_id: %s" % class_id)
		return false
	if not registry.has_record("subclass", subclass_id):
		push_error("[CharacterFactory] Unknown subclass_id: %s" % subclass_id)
		return false
	return true


func _apply_default_abilities(character: PlayerCharacter) -> void:
	for ability_key in ABILITY_KEYS:
		character.ability_scores[ability_key] = BASE_ABILITY_SCORE


func _apply_ability_bonuses(character: PlayerCharacter, bonuses: Dictionary) -> void:
	for ability_key in ABILITY_KEYS:
		if bonuses.has(ability_key):
			character.ability_scores[ability_key] = int(character.ability_scores[ability_key]) + int(bonuses[ability_key])


func _build_character_id(display_name: String, class_id: String) -> String:
	var cleaned := display_name.strip_edges().to_lower().replace(" ", "_")
	if cleaned.is_empty():
		cleaned = "character"
	return "%s_%s" % [cleaned, class_id]
