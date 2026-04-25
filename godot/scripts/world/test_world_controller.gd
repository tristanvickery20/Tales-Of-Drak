extends Node3D

## Test World Controller — fail-safe Phase 1 startup.
##
## This keeps the real RPG HUD/inventory, but removes fragile typed startup
## dependencies so HP, XP, inventory, and portal interaction initialize on web.

const GATHER_INTERACT_RANGE = 3.0
const DUNGEON_INTERACT_RANGE = 3.4

@onready var player = get_node_or_null("Player")
@onready var gather_node_marker = get_node_or_null("GatherNode")
@onready var build_spawn_marker = get_node_or_null("BuildSpawnMarker")
@onready var placed_build_parent = get_node_or_null("PlacedBuildPieces")
@onready var dungeon_portal = get_node_or_null("DungeonPortal")
@onready var hud = get_node_or_null("DebugHud")

var gs = null


func _ready():
	gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("ensure_runtime_state"):
		gs.ensure_runtime_state()
	_connect_hud_signals()
	_update_hud()
	_hud_result("Entered world as %s." % _character_summary())
	print("[TestWorld] Fail-safe controller initialized.")


func _process(_delta):
	_update_prompt()
	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()
	if Input.is_action_just_pressed("craft"):
		_quick_craft_torch()
	if Input.is_action_just_pressed("place_build"):
		_on_place_pressed()


func _connect_hud_signals():
	if hud == null:
		return
	if hud.has_signal("craft_recipe_requested"):
		hud.connect("craft_recipe_requested", Callable(self, "_on_hud_craft_recipe_requested"))
	if hud.has_signal("use_item_requested"):
		hud.connect("use_item_requested", Callable(self, "_on_hud_use_item_requested"))
	if hud.has_signal("equip_item_requested"):
		hud.connect("equip_item_requested", Callable(self, "_on_hud_equip_item_requested"))


func _update_prompt():
	var prompt = "Move | USE near portal/node | Craft | Place | INV"
	if _is_near(dungeon_portal, DUNGEON_INTERACT_RANGE):
		prompt += " | USE: Enter Dungeon"
	elif _is_near(gather_node_marker, GATHER_INTERACT_RANGE):
		prompt += " | USE: Gather"
	_hud_prompt(prompt)


func _on_interact_pressed():
	if _is_near(dungeon_portal, DUNGEON_INTERACT_RANGE):
		_enter_dungeon()
		return
	if _is_near(gather_node_marker, GATHER_INTERACT_RANGE):
		_add_item("weathered_timber", 3)
		_hud_result("Gathered Weathered Timber x3")
		_update_hud()
		return
	_hud_result("Nothing nearby to use.")


func _enter_dungeon():
	_hud_result("Entering dungeon...")
	print("[TestWorld] Entering dungeon...")
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_shell.tscn")


func _quick_craft_torch():
	_craft_recipe({
		"id": "craft_torch_kit",
		"name": "Torch Kit",
		"requirements": {"weathered_timber": 1},
		"output_item_id": "torch_kit",
		"output_quantity": 2,
	})


func _on_hud_craft_recipe_requested(recipe):
	_craft_recipe(recipe)


func _craft_recipe(recipe):
	if gs != null and gs.has_method("craft_recipe"):
		var result = gs.craft_recipe(recipe)
		_hud_result(str(result.get("message", "Craft result.")))
	else:
		var requirements = recipe.get("requirements", {})
		var output_item_id = str(recipe.get("output_item_id", recipe.get("id", "crafted_item")))
		var output_quantity = max(1, int(recipe.get("output_quantity", 1)))
		var recipe_name = str(recipe.get("name", _item_name(output_item_id)))
		for item_id in requirements.keys():
			var required = int(requirements[item_id])
			var owned = _item_count(str(item_id))
			if owned < required:
				_hud_result("Missing %s: %d / %d" % [_item_name(str(item_id)), owned, required])
				_update_hud()
				return
		for item_id in requirements.keys():
			_remove_item(str(item_id), int(requirements[item_id]))
		_add_item(output_item_id, output_quantity)
		_hud_result("Crafted %s x%d" % [recipe_name, output_quantity])
	_update_hud()


func _on_hud_use_item_requested(item_id):
	if gs != null and gs.has_method("use_item"):
		var result = gs.use_item(str(item_id))
		_hud_result(str(result.get("message", "Used item.")))
	else:
		_hud_result("Use item unavailable.")
	_update_hud()


func _on_hud_equip_item_requested(item_id):
	if gs != null and gs.has_method("equip_item"):
		var result = gs.equip_item(str(item_id))
		_hud_result(str(result.get("message", "Equip result.")))
	else:
		_hud_result("Cannot equip %s." % _item_name(str(item_id)))
	_update_hud()


func _on_place_pressed():
	if _item_count("weathered_timber") < 8:
		_hud_result("Build failed: need Weathered Timber x8")
		return
	_remove_item("weathered_timber", 8)
	_spawn_build_placeholder()
	_hud_result("Placed Timber Foundation")
	_update_hud()


func _spawn_build_placeholder():
	if build_spawn_marker == null or placed_build_parent == null:
		return
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.scale = Vector3(2.0, 0.4, 2.0)
	mesh.global_position = build_spawn_marker.global_position + Vector3(0.2 * placed_build_parent.get_child_count(), 0.2, 0.2 * placed_build_parent.get_child_count())
	placed_build_parent.add_child(mesh)


func _update_hud():
	if hud == null:
		return
	_hud_call("set_player_health", [_current_hp(), _max_hp()])
	_hud_call("set_progression", [_level(), _xp(), _xp_to_next()])
	_hud_call("set_character_summary", [_character_name(), "%s %s" % [_species_name(), _class_name()]])
	_hud_call("set_inventory_tabs", [_inventory_lines(), PackedStringArray(["Select recipe -> inspect requirements -> CRAFT."]), _character_view_lines()])


func _is_near(target, range):
	if player == null or target == null:
		return false
	return player.global_position.distance_to(target.global_position) <= float(range)


func _hud_call(method_name, args):
	if hud != null and hud.has_method(method_name):
		hud.callv(method_name, args)


func _hud_prompt(text):
	if hud != null and hud.has_method("set_prompt"):
		hud.set_prompt(text)


func _hud_result(text):
	if hud != null and hud.has_method("set_last_result"):
		hud.set_last_result(text)


func _current_hp():
	return int(gs.current_hp) if gs != null and "current_hp" in gs else 24

func _max_hp():
	return int(gs.max_hp) if gs != null and "max_hp" in gs else 24

func _level():
	return int(gs.level) if gs != null and "level" in gs else 1

func _xp():
	return int(gs.xp) if gs != null and "xp" in gs else 0

func _xp_to_next():
	return int(gs.xp_to_next) if gs != null and "xp_to_next" in gs else 100

func _character_name():
	return str(gs.character_name) if gs != null and "character_name" in gs else "Adventurer"

func _species_name():
	return str(gs.species_name) if gs != null and "species_name" in gs else "Human"

func _class_name():
	return str(gs.class_name) if gs != null and "class_name" in gs else "Fighter"

func _character_summary():
	if gs != null and gs.has_method("get_character_summary"):
		return str(gs.get_character_summary())
	return "%s - Level %d %s %s" % [_character_name(), _level(), _species_name(), _class_name()]

func _inventory_lines():
	if gs != null and gs.has_method("get_inventory_lines"):
		return gs.get_inventory_lines()
	return PackedStringArray(["starter_hatchet x1", "torch_kit x1", "weathered_timber x10"])

func _character_view_lines():
	if gs != null and gs.has_method("get_character_view_lines"):
		return gs.get_character_view_lines()
	return PackedStringArray([_character_summary(), "HP: %d / %d" % [_current_hp(), _max_hp()], "XP: %d / %d" % [_xp(), _xp_to_next()], "Main hand: Starter Hatchet"])

func _item_count(item_id):
	if gs != null and gs.has_method("get_item_count"):
		return int(gs.get_item_count(str(item_id)))
	if str(item_id) == "weathered_timber": return 10
	if str(item_id) == "starter_hatchet": return 1
	if str(item_id) == "torch_kit": return 1
	return 0

func _item_name(item_id):
	if gs != null and gs.has_method("get_item_name"):
		return str(gs.get_item_name(str(item_id)))
	return str(item_id).replace("_", " ").capitalize()

func _add_item(item_id, qty):
	if gs != null and gs.has_method("add_item"):
		gs.add_item(str(item_id), int(qty))

func _remove_item(item_id, qty):
	if gs != null and gs.has_method("remove_item"):
		gs.remove_item(str(item_id), int(qty))
