extends RefCounted
class_name PlayerCharacter

## PlayerCharacter v0.1
##
## Lightweight runtime model used by Stage 4 (Character + Stats Framework).
## This is intentionally data-only and gameplay-agnostic.

const ABILITY_KEYS := [
	"strength",
	"dexterity",
	"constitution",
	"intelligence",
	"wisdom",
	"charisma"
]

var character_id: String = ""
var display_name: String = ""
var species_id: String = ""
var class_id: String = ""
var subclass_id: String = ""

var level: int = 1
var xp: int = 0

var ability_scores: Dictionary = {
	"strength": 10,
	"dexterity": 10,
	"constitution": 10,
	"intelligence": 10,
	"wisdom": 10,
	"charisma": 10
}

var derived_stats: Dictionary = {
	"max_health": 10,
	"armor_class": 10,
	"initiative": 0,
	"movement_speed": 30
}


func to_summary_dict() -> Dictionary:
	"""Returns a single dictionary for debug printing/logging."""
	return {
		"character_id": character_id,
		"display_name": display_name,
		"species_id": species_id,
		"class_id": class_id,
		"subclass_id": subclass_id,
		"level": level,
		"xp": xp,
		"ability_scores": ability_scores.duplicate(true),
		"derived_stats": derived_stats.duplicate(true)
	}
