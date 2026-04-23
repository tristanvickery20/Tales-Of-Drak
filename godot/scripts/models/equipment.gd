extends RefCounted
class_name Equipment

## Equipment v0.1
##
## Holds equipped item IDs by slot and validates equipment using DataRegistry
## records from design/items.json + design/weapons.json + design/armor.json.

const SLOT_IDS := [
	"head",
	"chest",
	"legs",
	"feet",
	"main_hand",
	"off_hand",
	"ring",
	"amulet"
]

var owner_character_id: String = ""
var equipped_by_slot: Dictionary = {
	"head": "",
	"chest": "",
	"legs": "",
	"feet": "",
	"main_hand": "",
	"off_hand": "",
	"ring": "",
	"amulet": ""
}

var _registry: DataRegistry = null


func initialize(character_id: String, registry: DataRegistry) -> void:
	owner_character_id = character_id
	_registry = registry
	for slot_id in SLOT_IDS:
		equipped_by_slot[slot_id] = ""


func equip_item(slot_id: String, item_id: String) -> bool:
	if _registry == null:
		push_error("[Equipment] DataRegistry is null.")
		return false
	if not _is_valid_slot(slot_id):
		push_error("[Equipment] Invalid slot_id: %s" % slot_id)
		return false
	if not _registry.has_record("item", item_id):
		push_error("[Equipment] Unknown item_id in items.json: %s" % item_id)
		return false

	var weapon_record := _registry.get_record("weapon", item_id)
	var armor_record := _registry.get_record("armor", item_id)
	if weapon_record.is_empty() and armor_record.is_empty():
		push_error("[Equipment] Item '%s' is not equippable (not found in weapon/armor records)." % item_id)
		return false

	if not _slot_matches_item(slot_id, weapon_record, armor_record):
		push_error("[Equipment] Item '%s' cannot be equipped in slot '%s'." % [item_id, slot_id])
		return false

	# Two-handed weapons in main_hand clear off_hand.
	if slot_id == "main_hand" and not weapon_record.is_empty() and str(weapon_record.get("slot", "")) == "two_hand":
		equipped_by_slot["off_hand"] = ""

	# Off-hand cannot be used when two-handed weapon is already in main_hand.
	if slot_id == "off_hand":
		var main_hand_item := str(equipped_by_slot.get("main_hand", ""))
		if not main_hand_item.is_empty():
			var main_weapon := _registry.get_record("weapon", main_hand_item)
			if str(main_weapon.get("slot", "")) == "two_hand":
				push_error("[Equipment] Cannot equip off_hand while two-handed main_hand weapon is equipped.")
				return false

	equipped_by_slot[slot_id] = item_id
	return true


func unequip_item(slot_id: String) -> String:
	if not _is_valid_slot(slot_id):
		push_error("[Equipment] Invalid slot_id: %s" % slot_id)
		return ""
	var previous := str(equipped_by_slot.get(slot_id, ""))
	equipped_by_slot[slot_id] = ""
	return previous


func get_equipped_item(slot_id: String) -> String:
	if not _is_valid_slot(slot_id):
		return ""
	return str(equipped_by_slot.get(slot_id, ""))


func get_all_equipped() -> Dictionary:
	return equipped_by_slot.duplicate(true)


func get_total_bonuses() -> Dictionary:
	var total := {
		"armor_class_bonus": 0,
		"max_health_bonus": 0,
		"movement_speed_bonus": 0,
		"ability_bonuses": {
			"strength": 0,
			"dexterity": 0,
			"constitution": 0,
			"intelligence": 0,
			"wisdom": 0,
			"charisma": 0
		}
	}

	for slot_id in SLOT_IDS:
		var item_id := str(equipped_by_slot.get(slot_id, ""))
		if item_id.is_empty():
			continue
		_apply_item_bonuses(total, item_id)

	return total


func _apply_item_bonuses(total: Dictionary, item_id: String) -> void:
	var source := _registry.get_record("weapon", item_id)
	if source.is_empty():
		source = _registry.get_record("armor", item_id)
	if source.is_empty():
		return

	var bonuses := source.get("equipment_bonuses", {})
	if typeof(bonuses) != TYPE_DICTIONARY:
		return

	total["armor_class_bonus"] = int(total["armor_class_bonus"]) + int(bonuses.get("armor_class_bonus", 0))
	total["max_health_bonus"] = int(total["max_health_bonus"]) + int(bonuses.get("max_health_bonus", 0))
	total["movement_speed_bonus"] = int(total["movement_speed_bonus"]) + int(bonuses.get("movement_speed_bonus", 0))

	var total_ability_bonuses: Dictionary = total["ability_bonuses"]
	var ability_bonuses := bonuses.get("ability_bonuses", {})
	if typeof(ability_bonuses) == TYPE_DICTIONARY:
		for ability_key in total_ability_bonuses.keys():
			total_ability_bonuses[ability_key] = int(total_ability_bonuses[ability_key]) + int(ability_bonuses.get(ability_key, 0))


func _slot_matches_item(slot_id: String, weapon_record: Dictionary, armor_record: Dictionary) -> bool:
	if not weapon_record.is_empty():
		var weapon_slot := str(weapon_record.get("slot", ""))
		if slot_id == "main_hand":
			return weapon_slot == "main_hand" or weapon_slot == "two_hand"
		if slot_id == "off_hand":
			return weapon_slot == "off_hand"
		return false

	if not armor_record.is_empty():
		return str(armor_record.get("slot", "")) == slot_id

	return false


func _is_valid_slot(slot_id: String) -> bool:
	return SLOT_IDS.has(slot_id)
