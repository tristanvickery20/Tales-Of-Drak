extends Node

## Lightweight global runtime state for the current prototype session.
##
## Phase 1 vertical-slice state:
## - selected character
## - persistent backpack inventory
## - equipment slots
## - HP / XP / level
## - simple item definitions for UI, equip, use, and combat damage

signal runtime_state_changed

var character_name: String = "Adventurer"
var species_id: String = "human"
var species_name: String = "Human"
var class_id: String = "fighter"
var class_name: String = "Fighter"
var subclass_id: String = "champion"
var subclass_name: String = "Champion"
var has_custom_character: bool = false

var level: int = 1
var xp: int = 0
var xp_to_next: int = 100
var max_hp: int = 20
var current_hp: int = 20
var inventory: Dictionary = {}
var equipment: Dictionary = {
	"main_hand": "",
	"off_hand": "",
	"armor": "plain_clothes",
}

const ITEM_DEFS := {
	"starter_hatchet": {
		"name": "Starter Hatchet",
		"icon": "🪓",
		"type": "tool",
		"slot": "main_hand",
		"description": "A rough hatchet. Useful for gathering and barely good enough as a weapon.",
		"damage_bonus": 1,
		"usable": false,
		"equippable": true,
	},
	"weathered_timber": {
		"name": "Weathered Timber",
		"icon": "▥",
		"type": "resource",
		"slot": "",
		"description": "Old timber gathered from the world. Used for primitive crafting.",
		"damage_bonus": 0,
		"usable": false,
		"equippable": false,
	},
	"torch_kit": {
		"name": "Torch Kit",
		"icon": "🔥",
		"type": "utility",
		"slot": "",
		"description": "A simple torch kit for light and survival crafting chains.",
		"damage_bonus": 0,
		"usable": false,
		"equippable": false,
	},
	"timber_foundation": {
		"name": "Timber Foundation",
		"icon": "▧",
		"type": "building",
		"slot": "",
		"description": "A primitive building foundation for the future housing/building system.",
		"damage_bonus": 0,
		"usable": false,
		"equippable": false,
	},
	"starter_bandage": {
		"name": "Simple Bandage",
		"icon": "+",
		"type": "consumable",
		"slot": "",
		"description": "A crude bandage. Restores a small amount of HP in the prototype.",
		"damage_bonus": 0,
		"heal_amount": 8,
		"usable": true,
		"equippable": false,
	},
	"camp_marker": {
		"name": "Camp Marker",
		"icon": "⌂",
		"type": "utility",
		"slot": "",
		"description": "A placeholder camp object for future housing and rest systems.",
		"damage_bonus": 0,
		"usable": false,
		"equippable": false,
	},
	"rusty_sword": {
		"name": "Rusty Sword",
		"icon": "⚔",
		"type": "weapon",
		"slot": "main_hand",
		"description": "A battered sword from a dungeon chest. Better than a hatchet in combat.",
		"damage_bonus": 4,
		"usable": false,
		"equippable": true,
	},
	"plain_clothes": {
		"name": "Plain Clothes",
		"icon": "▣",
		"type": "armor",
		"slot": "armor",
		"description": "Basic starter clothing. No real protection yet.",
		"armor_bonus": 0,
		"usable": false,
		"equippable": true,
	},
	"ancient_coin": {
		"name": "Ancient Coin",
		"icon": "●",
		"type": "currency",
		"slot": "",
		"description": "A small coin from the dungeon. Used later for vendors and markets.",
		"damage_bonus": 0,
		"usable": false,
		"equippable": false,
	},
}


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
	reset_runtime_state()


func reset_runtime_state() -> void:
	level = 1
	xp = 0
	xp_to_next = 100
	max_hp = _starting_hp_for_class()
	current_hp = max_hp
	inventory = {
		"starter_hatchet": 1,
		"weathered_timber": 10,
		"torch_kit": 1,
	}
	equipment = {
		"main_hand": "starter_hatchet",
		"off_hand": "",
		"armor": "plain_clothes",
	}
	runtime_state_changed.emit()


func ensure_runtime_state() -> void:
	if inventory.is_empty():
		reset_runtime_state()


func _starting_hp_for_class() -> int:
	match class_id:
		"fighter":
			return 24
		"warlock":
			return 18
		"wizard":
			return 14
	return 20


func get_character_summary() -> String:
	return "%s — Level %d %s %s / %s" % [character_name, level, species_name, class_name, subclass_name]


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


func get_item_definition(item_id: String) -> Dictionary:
	return ITEM_DEFS.get(item_id, {
		"name": _display_item_name(item_id),
		"icon": "?",
		"type": "unknown",
		"slot": "",
		"description": "No item details yet.",
		"damage_bonus": 0,
		"usable": false,
		"equippable": false,
	})


func get_item_name(item_id: String) -> String:
	return str(get_item_definition(item_id).get("name", item_id))


func get_item_icon(item_id: String) -> String:
	return str(get_item_definition(item_id).get("icon", "?"))


func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity


func add_item(item_id: String, quantity: int = 1) -> void:
	if item_id.is_empty() or quantity <= 0:
		return
	inventory[item_id] = get_item_count(item_id) + quantity
	runtime_state_changed.emit()


func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true
	if get_item_count(item_id) < quantity:
		return false
	var next_count := get_item_count(item_id) - quantity
	if next_count <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = next_count
	runtime_state_changed.emit()
	return true


func get_inventory_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var keys := inventory.keys()
	keys.sort()
	for item_id in keys:
		var qty := get_item_count(str(item_id))
		if qty > 0:
			lines.append("%s x%d" % [str(item_id), qty])
	return lines


func equip_item(item_id: String) -> bool:
	if not has_item(item_id):
		return false
	var def := get_item_definition(item_id)
	if not bool(def.get("equippable", false)):
		return false
	var slot := str(def.get("slot", ""))
	if slot.is_empty():
		return false
	equipment[slot] = item_id
	runtime_state_changed.emit()
	return true


func use_item(item_id: String) -> Dictionary:
	if not has_item(item_id):
		return {"ok": false, "message": "You do not have that item."}
	var def := get_item_definition(item_id)
	if not bool(def.get("usable", false)):
		return {"ok": false, "message": "%s is not usable yet." % get_item_name(item_id)}
	if int(def.get("heal_amount", 0)) > 0:
		var amount := int(def.get("heal_amount", 0))
		current_hp = min(max_hp, current_hp + amount)
		remove_item(item_id, 1)
		return {"ok": true, "message": "Used %s. Restored %d HP." % [get_item_name(item_id), amount]}
	return {"ok": false, "message": "No use behavior yet."}


func get_equipped_item(slot: String) -> String:
	return str(equipment.get(slot, ""))


func get_weapon_damage_bonus() -> int:
	var weapon_id := get_equipped_item("main_hand")
	if weapon_id.is_empty():
		return 0
	return int(get_item_definition(weapon_id).get("damage_bonus", 0))


func get_armor_class() -> int:
	var armor_id := get_equipped_item("armor")
	var armor_bonus := int(get_item_definition(armor_id).get("armor_bonus", 0))
	return 10 + armor_bonus


func add_xp(amount: int) -> Dictionary:
	if amount <= 0:
		return {"leveled_up": false, "message": "No XP gained."}
	xp += amount
	var leveled_up := false
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next += 50
		max_hp += _hp_gain_per_level()
		current_hp = max_hp
		leveled_up = true
	runtime_state_changed.emit()
	if leveled_up:
		return {"leveled_up": true, "message": "Level up! You are now level %d." % level}
	return {"leveled_up": false, "message": "+%d XP. %d/%d XP" % [amount, xp, xp_to_next]}


func _hp_gain_per_level() -> int:
	match class_id:
		"fighter":
			return 8
		"warlock":
			return 6
		"wizard":
			return 4
	return 6


func set_current_hp(value: int) -> void:
	current_hp = clamp(value, 0, max_hp)
	runtime_state_changed.emit()


func heal_full() -> void:
	current_hp = max_hp
	runtime_state_changed.emit()


func get_character_view_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(get_character_summary())
	lines.append("HP: %d / %d" % [current_hp, max_hp])
	lines.append("XP: %d / %d" % [xp, xp_to_next])
	lines.append("AC: %d" % get_armor_class())
	lines.append("Main hand: %s" % _equipped_label("main_hand"))
	lines.append("Off hand: %s" % _equipped_label("off_hand"))
	lines.append("Armor: %s" % _equipped_label("armor"))
	lines.append("Weapon damage bonus: +%d" % get_weapon_damage_bonus())
	return lines


func _equipped_label(slot: String) -> String:
	var item_id := get_equipped_item(slot)
	if item_id.is_empty():
		return "empty"
	return get_item_name(item_id)


func _display_item_name(item_id: String) -> String:
	var parts := item_id.split("_")
	var out := PackedStringArray()
	for part in parts:
		out.append(String(part).capitalize())
	return " ".join(out)
