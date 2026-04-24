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

var item_defs = {
	"starter_hatchet": {"name":"Starter Hatchet","icon":"H","type":"tool","slot":"main_hand","description":"A rough hatchet. Useful for gathering and barely good enough as a weapon.","damage_bonus":1,"usable":false,"equippable":true},
	"weathered_timber": {"name":"Weathered Timber","icon":"W","type":"resource","slot":"","description":"Old timber gathered from the world. Used for primitive crafting.","damage_bonus":0,"usable":false,"equippable":false},
	"torch_kit": {"name":"Torch Kit","icon":"T","type":"utility","slot":"","description":"A simple torch kit for light and survival crafting chains.","damage_bonus":0,"usable":false,"equippable":false},
	"timber_foundation": {"name":"Timber Foundation","icon":"F","type":"building","slot":"","description":"A primitive building foundation for the future housing/building system.","damage_bonus":0,"usable":false,"equippable":false},
	"starter_bandage": {"name":"Simple Bandage","icon":"+","type":"consumable","slot":"","description":"A crude bandage. Restores a small amount of HP in the prototype.","damage_bonus":0,"heal_amount":8,"usable":true,"equippable":false},
	"camp_marker": {"name":"Camp Marker","icon":"C","type":"utility","slot":"","description":"A placeholder camp object for future housing and rest systems.","damage_bonus":0,"usable":false,"equippable":false},
	"rusty_sword": {"name":"Rusty Sword","icon":"S","type":"weapon","slot":"main_hand","description":"A battered sword from a dungeon chest. Better than a hatchet in combat.","damage_bonus":4,"usable":false,"equippable":true},
	"plain_clothes": {"name":"Plain Clothes","icon":"A","type":"armor","slot":"armor","description":"Basic starter clothing. No real protection yet.","armor_bonus":0,"usable":false,"equippable":true},
	"ancient_coin": {"name":"Ancient Coin","icon":"O","type":"currency","slot":"","description":"A small coin from the dungeon. Used later for vendors and markets.","damage_bonus":0,"usable":false,"equippable":false},
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
	reset_runtime_state()

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

func add_item(item_id, quantity = 1):
	item_id = str(item_id)
	quantity = int(quantity)
	if item_id == "" or quantity <= 0: return
	inventory[item_id] = get_item_count(item_id) + quantity
	runtime_state_changed.emit()

func remove_item(item_id, quantity = 1):
	item_id = str(item_id)
	quantity = int(quantity)
	if quantity <= 0: return true
	if get_item_count(item_id) < quantity: return false
	var next_count = get_item_count(item_id) - quantity
	if next_count <= 0: inventory.erase(item_id)
	else: inventory[item_id] = next_count
	runtime_state_changed.emit()
	return true

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
	if not has_item(item_id): return false
	var def = get_item_definition(item_id)
	if not bool(def.get("equippable", false)): return false
	var slot = str(def.get("slot", ""))
	if slot == "": return false
	equipment[slot] = item_id
	runtime_state_changed.emit()
	return true

func use_item(item_id):
	item_id = str(item_id)
	if not has_item(item_id): return {"ok":false,"message":"You do not have that item."}
	var def = get_item_definition(item_id)
	if not bool(def.get("usable", false)): return {"ok":false,"message":"%s is not usable yet." % get_item_name(item_id)}
	var heal = int(def.get("heal_amount", 0))
	if heal > 0:
		current_hp = min(max_hp, current_hp + heal)
		remove_item(item_id, 1)
		return {"ok":true,"message":"Used %s. Restored %d HP." % [get_item_name(item_id), heal]}
	return {"ok":false,"message":"No use behavior yet."}

func get_equipped_item(slot): return str(equipment.get(str(slot), ""))

func get_weapon_damage_bonus():
	var weapon_id = get_equipped_item("main_hand")
	if weapon_id == "": return 0
	return int(get_item_definition(weapon_id).get("damage_bonus", 0))

func get_armor_class():
	var armor_id = get_equipped_item("armor")
	return 10 + int(get_item_definition(armor_id).get("armor_bonus", 0))

func add_xp(amount):
	amount = int(amount)
	if amount <= 0: return {"leveled_up":false,"message":"No XP gained."}
	xp += amount
	var leveled_up = false
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next += 50
		max_hp += _hp_gain_per_level()
		current_hp = max_hp
		leveled_up = true
	runtime_state_changed.emit()
	if leveled_up: return {"leveled_up":true,"message":"Level up! You are now level %d." % level}
	return {"leveled_up":false,"message":"+%d XP. %d/%d XP" % [amount, xp, xp_to_next]}

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
