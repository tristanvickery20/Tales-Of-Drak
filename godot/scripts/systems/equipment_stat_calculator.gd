extends RefCounted
class_name EquipmentStatCalculator

## EquipmentStatCalculator v0.1
##
## Applies equipment bonus values to a PlayerCharacter's derived stat outputs
## without mutating core character data.


static func calculate_with_equipment(character: PlayerCharacter, equipment: Equipment) -> Dictionary:
	var base_stats := character.derived_stats.duplicate(true)
	if equipment == null:
		return base_stats

	var bonuses := equipment.get_total_bonuses()
	base_stats["max_health"] = int(base_stats.get("max_health", 0)) + int(bonuses.get("max_health_bonus", 0))
	base_stats["armor_class"] = int(base_stats.get("armor_class", 0)) + int(bonuses.get("armor_class_bonus", 0))
	base_stats["movement_speed"] = int(base_stats.get("movement_speed", 0)) + int(bonuses.get("movement_speed_bonus", 0))

	# Initiative can be affected by dexterity from equipment bonuses.
	var dex_with_bonus := int(character.ability_scores.get("dexterity", 10)) + int(bonuses.get("ability_bonuses", {}).get("dexterity", 0))
	base_stats["initiative"] = StatCalculator.calculate_initiative(dex_with_bonus)

	# Keep all derived stats at least 1.
	for key in ["max_health", "armor_class", "movement_speed"]:
		base_stats[key] = max(1, int(base_stats[key]))

	return base_stats
