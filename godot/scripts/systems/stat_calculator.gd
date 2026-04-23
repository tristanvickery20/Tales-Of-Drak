extends RefCounted
class_name StatCalculator

## StatCalculator v0.1
##
## Small, explicit helper methods for D20-style character math.
## These formulas are intentionally simple placeholders for framework stage 4.


static func ability_modifier(score: int) -> int:
	return int(floor((score - 10) / 2.0))


static func calculate_max_health(level: int, constitution_score: int) -> int:
	# Simple baseline: level 1 starts at 10, additional levels add 6.
	# Constitution modifier applies each level.
	var con_mod := ability_modifier(constitution_score)
	var max_health := 10 + con_mod + max(0, level - 1) * (6 + con_mod)
	return max(1, max_health)


static func calculate_armor_class(dexterity_score: int) -> int:
	return 10 + ability_modifier(dexterity_score)


static func calculate_initiative(dexterity_score: int) -> int:
	return ability_modifier(dexterity_score)


static func calculate_movement_speed(base_movement_speed: int, species_movement_bonus: int = 0) -> int:
	return max(1, base_movement_speed + species_movement_bonus)
