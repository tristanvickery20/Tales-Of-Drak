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


func _ready():
	GameState.ensure_runtime_state()
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
	var result = GameState.craft_recipe(recipe)
	_hud_result(str(result.get("message", "Craft result.")))
	_update_hud()


func _on_hud_use_item_requested(item_id):
	var result = GameState.use_item(str(item_id))
	_hud_result(str(result.get("message", "Used item.")))
	_update_hud()


func _on_hud_equip_item_requested(item_id):
	var result = GameState.equip_item(str(item_id))
	_hud_result(str(result.get("message", "Equip result.")))
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
	return int(GameState.current_hp)

func _max_hp():
	return int(GameState.max_hp)

func _level():
	return int(GameState.level)

func _xp():
	return int(GameState.xp)

func _xp_to_next():
	return int(GameState.xp_to_next)

func _character_name():
	return str(GameState.character_name)

func _species_name():
	return str(GameState.species_name)

func _class_name():
	return str(GameState.class_name)

func _character_summary():
	return str(GameState.get_character_summary())

func _inventory_lines():
	return GameState.get_inventory_lines()

func _character_view_lines():
	return GameState.get_character_view_lines()

func _item_count(item_id):
	return int(GameState.get_item_count(str(item_id)))

func _item_name(item_id):
	return str(GameState.get_item_name(str(item_id)))

func _add_item(item_id, qty):
	GameState.add_item(str(item_id), int(qty))

func _remove_item(item_id, qty):
	GameState.remove_item(str(item_id), int(qty))
