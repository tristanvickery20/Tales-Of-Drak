extends Node

signal runtime_state_changed

var character_name = "Adventurer"
var species_id = "human"
var species_name = "Human"
var class_id = "fighter"
var class_name = "Fighter"
var subclass_id = "champion"
var subclass_name = "Champion"
var has_custom_character = false

var level = 1
var xp = 0
var xp_to_next = 100
var max_hp = 20
var current_hp = 20
var inventory = {}
var equipment = {
	"main_hand": "",
	"off_hand": "",
	"armor": "plain_clothes",
}

var action_log = PackedStringArray()
var last_action_result = {"ok": true, "message": "GameState initialized."}

# Resource tracking for the prototype
var resources = {
	"wood": 0,
	"stone": 0,
	"fiber": 0,
	"drak_essence": 0,
}

# Build cost definitions
const BUILD_COSTS = {
	"campfire": {"wood": 3, "stone": 2},
	"wooden_wall": {"wood": 5},
	"wooden_foundation": {"wood": 8, "stone": 2},
	"drak_totem": {"stone": 5, "drak_essence": 3},
}

# Objective tracking
var current_objective_index: int = 0
var objectives_completed: Array = []
const OBJECTIVES = [
	"Gather 5 Wood",
	"Gather 3 Stone",
	"Build a Campfire",
	"Defeat a Drakling",
	"Build a Drak Totem",
]

var placed_buildings: Array = []
var depleted_nodes: Array = []

var item_defs = {
	"starter_hatchet": {"name":"Starter Hatchet","icon":"H","type":"tool / weapon","slot":"main_hand","description":"A rough hatchet. Useful for gathering and basic fighting.","damage_dice":"1d4","damage_bonus":1,"usable":false,"equippable":true},
	"weathered_timber": {"name":"Weathered Timber","icon":"W","type":"resource","slot":"","description":"Old timber gathered from the world. Used for primitive crafting.","damage_bonus":0,"usable":false,"equippable":false},
	"torch_kit": {"name":"Torch Kit","icon":"T","type":"utility","slot":"","description":"A simple torch kit for light and survival crafting chains.","damage_bonus":0,"usable":false,"equippable":false},
	"timber_foundation": {"name":"Timber Foundation","icon":"F","type":"building","slot":"","description":"A primitive building foundation for the future housing/building system.","damage_bonus":0,"usable":false,"equippable":false},
	"starter_bandage": {"name":"Simple Bandage","icon":"+","type":"consumable","slot":"","description":"A crude bandage. Restores a small amount of HP in the prototype.","damage_bonus":0,"heal_amount":8,"usable":true,"equippable":false},
	"camp_marker": {"name":"Camp Marker","icon":"C","type":"utility","slot":"","description":"A placeholder camp object for future housing and rest systems.","damage_bonus":0,"usable":false,"equippable":false},
	"rusty_sword": {"name":"Rusty Sword","icon":"S","type":"weapon","slot":"main_hand","description":"A battered sword from a dungeon chest. Better than a hatchet in combat.","damage_dice":"1d8","damage_bonus":4,"usable":false,"equippable":true},
	"plain_clothes": {"name":"Plain Clothes","icon":"A","type":"armor","slot":"armor","description":"Basic starter clothing. No real protection yet.","armor_bonus":0,"usable":false,"equippable":true},
	"ancient_coin": {"name":"Ancient Coin","icon":"O","type":"currency","slot":"","description":"A small coin from the dungeon. Used later for vendors and markets.","damage_bonus":0,"usable":false,"equippable":false},
	"wood": {"name":"Wood","icon":"W","type":"resource","slot":"","description":"Basic wood gathered from trees.","usable":false,"equippable":false},
	"stone": {"name":"Stone","icon":"S","type":"resource","slot":"","description":"Rough stone gathered from rocks.","usable":false,"equippable":false},
	"fiber": {"name":"Fiber","icon":"F","type":"resource","slot":"","description":"Plant fiber used for basic crafting.","usable":false,"equippable":false},
	"drak_essence": {"name":"Drak Essence","icon":"D","type":"resource","slot":"","description":"Mystical essence from Drak crystals.","usable":false,"equippable":false},
}

func _ready():
	ensure_runtime_state()

func set_character(selection):
	character_name = str(selection.get("character_name", "Adventurer")).strip_edges()
	if character_name == "": character_name = "Adventurer"
	species_id = str(selection.get("species_id", "human"))
	species_name = str(selection.get("species_name", "Human"))
	class_id = str(selection.get("class_id", "fighter"))
	class_name = str(selection.get("class_name", "Fighter"))
	subclass_id = str(selection.get("subclass_id", "champion"))
	subclass_name = str(selection.get("subclass_name", "Champion"))
	has_custom_character = true
	action_log.clear()
	reset_runtime_state()
	log_action("Character created: %s" % get_character_summary())

func reset_runtime_state():
	level = 1
	xp = 0
	xp_to_next = 100
	max_hp = _starting_hp_for_class()
	current_hp = max_hp
	inventory = {"starter_hatchet":1,"weathered_timber":10,"torch_kit":1}
	equipment = {"main_hand":"starter_hatchet","off_hand":"","armor":"plain_clothes"}
	runtime_state_changed.emit()

func ensure_runtime_state():
	if inventory.is_empty(): reset_runtime_state()

func _starting_hp_for_class():
	if class_id == "fighter": return 24
	if class_id == "warlock": return 18
	if class_id == "wizard": return 14
	return 20

func get_character_summary():
	return "%s - Level %d %s %s / %s" % [character_name, level, species_name, class_name, subclass_name]

func get_selection():
	return {"character_name":character_name,"species_id":species_id,"species_name":species_name,"class_id":class_id,"class_name":class_name,"subclass_id":subclass_id,"subclass_name":subclass_name,"has_custom_character":has_custom_character}

func get_item_definition(item_id):
	item_id = str(item_id)
	if item_defs.has(item_id): return item_defs[item_id]
	return {"name":_display_item_name(item_id),"icon":"?","type":"unknown","slot":"","description":"No item details yet.","damage_bonus":0,"usable":false,"equippable":false}

func get_item_name(item_id): return str(get_item_definition(item_id).get("name", item_id))
func get_item_icon(item_id): return str(get_item_definition(item_id).get("icon", "?"))
func get_item_count(item_id): return int(inventory.get(str(item_id), 0))
func has_item(item_id, quantity = 1): return get_item_count(item_id) >= int(quantity)

func log_action(text):
	action_log.append(str(text))
	if action_log.size() > 50:
		action_log = action_log.slice(action_log.size() - 50)

func add_item(item_id, quantity = 1):
	item_id = str(item_id)
	quantity = int(quantity)
	if item_id == "" or quantity <= 0:
		var msg = "ADD_ITEM failed: invalid item_id or quantity"
		log_action(msg)
		return {"ok": false, "message": msg}
	var prev = get_item_count(item_id)
	inventory[item_id] = prev + quantity
	var msg = "ADD_ITEM: %s x%d (now %d)" % [get_item_name(item_id), quantity, get_item_count(item_id)]
	log_action(msg)
	last_action_result = {"ok": true, "message": msg}
	runtime_state_changed.emit()
	return last_action_result

func remove_item(item_id, quantity = 1):
	item_id = str(item_id)
	quantity = int(quantity)
	if quantity <= 0:
		var msg = "REMOVE_ITEM failed: quantity must be > 0"
		log_action(msg)
		return {"ok": false, "message": msg}
	if get_item_count(item_id) < quantity:
		var msg = "REMOVE_ITEM failed: need %s %d/%d" % [get_item_name(item_id), get_item_count(item_id), quantity]
		log_action(msg)
		return {"ok": false, "message": msg}
	var next_count = get_item_count(item_id) - quantity
	if next_count <= 0: inventory.erase(item_id)
	else: inventory[item_id] = next_count
	var msg = "REMOVE_ITEM: %s x%d (now %d)" % [get_item_name(item_id), quantity, get_item_count(item_id)]
	log_action(msg)
	last_action_result = {"ok": true, "message": msg}
	runtime_state_changed.emit()
	return last_action_result

func get_inventory_lines():
	var lines = PackedStringArray()
	var keys = inventory.keys()
	keys.sort()
	for item_id in keys:
		var qty = get_item_count(str(item_id))
		if qty > 0: lines.append("%s x%d" % [str(item_id), qty])
	return lines

func equip_item(item_id):
	item_id = str(item_id)
	if not has_item(item_id):
		var msg = "EQUIP failed: you do not have %s" % get_item_name(item_id)
		log_action(msg)
		return {"ok": false, "message": msg}
	var def = get_item_definition(item_id)
	if not bool(def.get("equippable", false)):
		var msg = "EQUIP failed: %s is not equippable" % get_item_name(item_id)
		log_action(msg)
		return {"ok": false, "message": msg}
	var slot = str(def.get("slot", ""))
	if slot == "":
		var msg = "EQUIP failed: %s has no valid equipment slot" % get_item_name(item_id)
		log_action(msg)
		return {"ok": false, "message": msg}
	equipment[slot] = item_id
	var msg = "EQUIP success: %s -> %s" % [get_item_name(item_id), slot]
	log_action(msg)
	last_action_result = {"ok": true, "message": msg}
	runtime_state_changed.emit()
	return last_action_result

func use_item(item_id):
	item_id = str(item_id)
	if not has_item(item_id):
		var msg = "USE failed: you do not have %s" % get_item_name(item_id)
		log_action(msg)
		last_action_result = {"ok": false, "message": msg}
		return last_action_result
	var def = get_item_definition(item_id)
	if not bool(def.get("usable", false)):
		var msg = "USE failed: %s is not usable" % get_item_name(item_id)
		log_action(msg)
		last_action_result = {"ok": false, "message": msg}
		return last_action_result
	var heal = int(def.get("heal_amount", 0))
	if heal > 0:
		current_hp = min(max_hp, current_hp + heal)
		remove_item(item_id, 1)
		var msg = "USE success: %s restored %d HP" % [get_item_name(item_id), heal]
		log_action(msg)
		last_action_result = {"ok": true, "message": msg}
		runtime_state_changed.emit()
		return last_action_result
	var msg = "USE failed: %s has no use behavior" % get_item_name(item_id)
	log_action(msg)
	last_action_result = {"ok": false, "message": msg}
	return last_action_result

func craft_recipe(recipe):
	var requirements = recipe.get("requirements", {})
	var recipe_id = str(recipe.get("id", "unknown"))
	var output_item_id = str(recipe.get("output_item_id", recipe_id))
	var output_qty = max(1, int(recipe.get("output_quantity", 1)))
	var recipe_name = str(recipe.get("name", get_item_name(output_item_id)))

	for item_id in requirements.keys():
		var required = int(requirements[item_id])
		var owned = get_item_count(str(item_id))
		if owned < required:
			var msg = "CRAFT failed: need %s %d/%d" % [get_item_name(str(item_id)), owned, required]
			log_action(msg)
			last_action_result = {"ok": false, "message": msg}
			return last_action_result

	for item_id in requirements.keys():
		remove_item(str(item_id), int(requirements[item_id]))

	add_item(output_item_id, output_qty)
	var msg = "CRAFT success: %s -> %s x%d" % [recipe_name, get_item_name(output_item_id), output_qty]
	log_action(msg)
	last_action_result = {"ok": true, "message": msg}
	runtime_state_changed.emit()
	return last_action_result

func damage_player(amount, source = "damage"):
	amount = int(amount)
	var prev_hp = current_hp
	current_hp = clamp(current_hp - amount, 0, max_hp)
	var actual = prev_hp - current_hp
	var msg = "DAMAGE %s: %d -> %d (-%d)" % [str(source), prev_hp, current_hp, actual]
	log_action(msg)
	last_action_result = {"ok": true, "message": msg, "damage": actual}
	runtime_state_changed.emit()
	return last_action_result

func get_equipped_item(slot): return str(equipment.get(str(slot), ""))

func get_weapon_damage_bonus():
	var weapon_id = get_equipped_item("main_hand")
	if weapon_id == "": return 0
	return int(get_item_definition(weapon_id).get("damage_bonus", 0))

func get_weapon_damage_dice():
	var weapon_id = get_equipped_item("main_hand")
	if weapon_id == "": return ""
	return str(get_item_definition(weapon_id).get("damage_dice", ""))

func get_armor_class():
	var armor_id = get_equipped_item("armor")
	return 10 + int(get_item_definition(armor_id).get("armor_bonus", 0))

func add_xp(amount):
	amount = int(amount)
	if amount <= 0:
		var msg = "No XP gained."
		log_action(msg)
		last_action_result = {"ok": true, "message": msg, "leveled_up": false}
		return {"leveled_up": false, "message": msg}
	xp += amount
	var leveled_up = false
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next += 50
		max_hp += _hp_gain_per_level()
		current_hp = max_hp
		leveled_up = true
	var msg
	if leveled_up:
		msg = "LEVEL UP! Now level %d." % level
	else:
		msg = "+%d XP. %d/%d XP" % [amount, xp, xp_to_next]
	log_action(msg)
	last_action_result = {"ok": true, "message": msg, "leveled_up": leveled_up}
	runtime_state_changed.emit()
	if leveled_up: return {"leveled_up": true, "message": msg}
	return {"leveled_up": false, "message": msg}

func _hp_gain_per_level():
	if class_id == "fighter": return 8
	if class_id == "warlock": return 6
	if class_id == "wizard": return 4
	return 6

func set_current_hp(value):
	current_hp = clamp(int(value), 0, max_hp)
	runtime_state_changed.emit()

func heal_full():
	current_hp = max_hp
	runtime_state_changed.emit()

func get_character_view_lines():
	var lines = PackedStringArray()
	lines.append(get_character_summary())
	lines.append("HP: %d / %d" % [current_hp, max_hp])
	lines.append("XP: %d / %d" % [xp, xp_to_next])
	lines.append("AC: %d" % get_armor_class())
	lines.append("Main hand: %s" % _equipped_label("main_hand"))
	lines.append("Off hand: %s" % _equipped_label("off_hand"))
	lines.append("Armor: %s" % _equipped_label("armor"))
	var weapon_dice = get_weapon_damage_dice()
	if weapon_dice != "":
		lines.append("Weapon damage: %s" % weapon_dice)
	lines.append("Weapon damage bonus: +%d" % get_weapon_damage_bonus())
	return lines

func _equipped_label(slot):
	var item_id = get_equipped_item(slot)
	if item_id == "": return "empty"
	return get_item_name(item_id)

func _display_item_name(item_id):
	var parts = str(item_id).split("_")
	var out = []
	for part in parts: out.append(str(part).capitalize())
	return " ".join(out)

func get_debug_lines():
	var lines = PackedStringArray()
	lines.append("GameState OK")
	var scene_path = ""
	if get_tree() != null and get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	lines.append("Scene: %s" % scene_path)
	lines.append("HP: %d / %d" % [current_hp, max_hp])
	lines.append("XP: %d / %d  LV: %d" % [xp, xp_to_next, level])
	lines.append("--- Resources ---")
	for r in resources.keys():
		lines.append("  %s: %d" % [r, resources[r]])
	lines.append("--- Inventory ---")
	for line in get_inventory_lines():
		lines.append("  %s" % line)
	lines.append("--- Equipment ---")
	for slot in equipment.keys():
		lines.append("  %s: %s" % [slot, _equipped_label(slot)])
	lines.append("--- Last Action ---")
	lines.append("  ok=%s  %s" % [last_action_result.get("ok", "?"), last_action_result.get("message", "")])
	lines.append("--- Action Log (last 10) ---")
	var start = max(0, action_log.size() - 10)
	for i in range(start, action_log.size()):
		lines.append("  %d: %s" % [i, action_log[i]])
	return lines


# ---- Resource helpers ----

func add_resource(resource_id: String, amount: int = 1) -> void:
	resource_id = resource_id.to_lower()
	if resources.has(resource_id):
		resources[resource_id] += amount
	else:
		resources[resource_id] = amount
	runtime_state_changed.emit()

func get_resource(resource_id: String) -> int:
	resource_id = resource_id.to_lower()
	return resources.get(resource_id, 0)

func has_resources(costs: Dictionary) -> bool:
	for rid in costs.keys():
		if get_resource(str(rid)) < int(costs[rid]):
			return false
	return true

func spend_resources(costs: Dictionary) -> bool:
	if not has_resources(costs):
		return false
	for rid in costs.keys():
		resources[str(rid).to_lower()] -= int(costs[rid])
	runtime_state_changed.emit()
	return true

func get_resource_lines() -> PackedStringArray:
	var lines = PackedStringArray()
	lines.append("Wood: %d" % resources.get("wood", 0))
	lines.append("Stone: %d" % resources.get("stone", 0))
	lines.append("Fiber: %d" % resources.get("fiber", 0))
	lines.append("Drak Essence: %d" % resources.get("drak_essence", 0))
	return lines


# ---- Objective helpers ----

func get_current_objective() -> String:
	if current_objective_index < OBJECTIVES.size():
		return OBJECTIVES[current_objective_index]
	return "All objectives complete!"

func check_objective_complete() -> bool:
	var idx = current_objective_index
	if idx == 0:  # Gather 5 Wood
		return get_resource("wood") >= 5
	if idx == 1:  # Gather 3 Stone
		return get_resource("stone") >= 3
	if idx == 2:  # Build a Campfire
		return "campfire" in objectives_completed
	if idx == 3:  # Defeat a Drakling
		return "drakling_defeated" in objectives_completed
	if idx == 4:  # Build a Drak Totem
		return "drak_totem" in objectives_completed
	return false

func advance_objective() -> String:
	if current_objective_index >= OBJECTIVES.size():
		return "All objectives complete!"
	var completed = OBJECTIVES[current_objective_index]
	current_objective_index += 1
	runtime_state_changed.emit()
	return completed

func mark_objective_complete(key: String) -> void:
	if key not in objectives_completed:
		objectives_completed.append(key)


# ---- Save / Load ----

func save_game() -> Dictionary:
	var data = {
		"character_name": character_name,
		"class_id": class_id,
		"class_name": class_name,
		"resources": resources.duplicate(),
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_objective_index": current_objective_index,
		"objectives_completed": objectives_completed.duplicate(),
		"placed_buildings": placed_buildings.duplicate(),
		"depleted_nodes": depleted_nodes.duplicate(),
		"inventory": inventory.duplicate(),
	}
	return data

func load_game(data: Dictionary) -> void:
	character_name = data.get("character_name", "Adventurer")
	class_id = data.get("class_id", "fighter")
	class_name = data.get("class_name", "Fighter")
	resources = data.get("resources", {"wood": 0, "stone": 0, "fiber": 0, "drak_essence": 0}).duplicate()
	current_hp = int(data.get("current_hp", max_hp))
	max_hp = int(data.get("max_hp", 20))
	current_objective_index = int(data.get("current_objective_index", 0))
	objectives_completed = data.get("objectives_completed", [])
	placed_buildings = data.get("placed_buildings", [])
	depleted_nodes = data.get("depleted_nodes", [])
	var saved_inv = data.get("inventory", {})
	if not saved_inv.is_empty():
		inventory = saved_inv.duplicate()
	runtime_state_changed.emit()
