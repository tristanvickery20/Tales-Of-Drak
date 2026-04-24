extends Node3D

## Test World Controller — Phase 1 vertical slice.
## GameState is the source of truth for character, HP, XP, inventory, and equipment.

const GATHER_INTERACT_RANGE := 3.0
const DUNGEON_INTERACT_RANGE := 3.0

@onready var player: ThirdPersonController = $Player
@onready var gather_node_marker: Node3D = $GatherNode
@onready var build_spawn_marker: Node3D = $BuildSpawnMarker
@onready var placed_build_parent: Node3D = $PlacedBuildPieces
@onready var dungeon_portal: Node3D = $DungeonPortal
@onready var hud: DebugHud = $DebugHud


func _ready() -> void:
	GameState.ensure_runtime_state()
	_connect_hud_signals()
	if not GameState.runtime_state_changed.is_connected(_update_hud):
		GameState.runtime_state_changed.connect(_update_hud)
	_update_hud()
	hud.set_last_result("Entered world as %s." % GameState.get_character_summary())
	print("[TestWorld] Runtime initialized for %s" % GameState.get_character_summary())


func _process(_delta: float) -> void:
	_update_prompt()
	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()
	if Input.is_action_just_pressed("craft"):
		_quick_craft_torch()
	if Input.is_action_just_pressed("place_build"):
		_on_place_pressed()


func _connect_hud_signals() -> void:
	if not hud.craft_recipe_requested.is_connected(_on_hud_craft_recipe_requested):
		hud.craft_recipe_requested.connect(_on_hud_craft_recipe_requested)
	if not hud.use_item_requested.is_connected(_on_hud_use_item_requested):
		hud.use_item_requested.connect(_on_hud_use_item_requested)
	if not hud.equip_item_requested.is_connected(_on_hud_equip_item_requested):
		hud.equip_item_requested.connect(_on_hud_equip_item_requested)


func _update_prompt() -> void:
	var prompt := "Move | USE near portal/node | Craft | Place | INV"
	if player.global_position.distance_to(dungeon_portal.global_position) <= DUNGEON_INTERACT_RANGE:
		prompt += " | USE: Enter Dungeon"
	elif player.global_position.distance_to(gather_node_marker.global_position) <= GATHER_INTERACT_RANGE:
		prompt += " | USE: Gather"
	hud.set_prompt(prompt)


func _on_interact_pressed() -> void:
	if player.global_position.distance_to(dungeon_portal.global_position) <= DUNGEON_INTERACT_RANGE:
		_enter_dungeon()
		return
	if player.global_position.distance_to(gather_node_marker.global_position) <= GATHER_INTERACT_RANGE:
		GameState.add_item("weathered_timber", 3)
		hud.set_last_result("Gathered Weathered Timber x3")
		_update_hud()
		return
	hud.set_last_result("Nothing nearby to use.")


func _enter_dungeon() -> void:
	hud.set_last_result("Entering dungeon...")
	print("[TestWorld] Entering dungeon...")
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_shell.tscn")


func _quick_craft_torch() -> void:
	_craft_recipe({
		"id": "craft_torch_kit",
		"name": "Torch Kit",
		"requirements": {"weathered_timber": 1},
		"output_item_id": "torch_kit",
		"output_quantity": 2,
	})


func _on_hud_craft_recipe_requested(recipe) -> void:
	_craft_recipe(recipe)


func _craft_recipe(recipe: Dictionary) -> void:
	var requirements: Dictionary = recipe.get("requirements", {})
	var output_item_id := str(recipe.get("output_item_id", recipe.get("id", "crafted_item")))
	var output_quantity := max(1, int(recipe.get("output_quantity", 1)))
	var recipe_name := str(recipe.get("name", GameState.get_item_name(output_item_id)))
	for item_id in requirements.keys():
		var required := int(requirements[item_id])
		var owned := GameState.get_item_count(str(item_id))
		if owned < required:
			hud.set_last_result("Missing %s: %d / %d" % [GameState.get_item_name(str(item_id)), owned, required])
			_update_hud()
			return
	for item_id in requirements.keys():
		GameState.remove_item(str(item_id), int(requirements[item_id]))
	GameState.add_item(output_item_id, output_quantity)
	hud.set_last_result("Crafted %s x%d" % [recipe_name, output_quantity])
	_update_hud()


func _on_hud_use_item_requested(item_id) -> void:
	var result := GameState.use_item(str(item_id))
	hud.set_last_result(str(result.get("message", "Used item.")))
	_update_hud()


func _on_hud_equip_item_requested(item_id) -> void:
	if GameState.equip_item(str(item_id)):
		hud.set_last_result("Equipped %s." % GameState.get_item_name(str(item_id)))
	else:
		hud.set_last_result("Cannot equip %s." % GameState.get_item_name(str(item_id)))
	_update_hud()


func _on_place_pressed() -> void:
	if GameState.get_item_count("weathered_timber") < 8:
		hud.set_last_result("Build failed: need Weathered Timber x8")
		return
	GameState.remove_item("weathered_timber", 8)
	_spawn_build_placeholder(build_spawn_marker.global_position)
	hud.set_last_result("Placed Timber Foundation")
	_update_hud()


func _spawn_build_placeholder(world_pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.scale = Vector3(2.0, 0.4, 2.0)
	mesh.global_position = world_pos + Vector3(0.2 * placed_build_parent.get_child_count(), 0.2, 0.2 * placed_build_parent.get_child_count())
	placed_build_parent.add_child(mesh)


func _update_hud() -> void:
	GameState.ensure_runtime_state()
	hud.set_player_health(GameState.current_hp, GameState.max_hp)
	hud.set_progression(GameState.level, GameState.xp, GameState.xp_to_next)
	hud.set_character_summary(GameState.character_name, "%s %s" % [GameState.species_name, GameState.class_name])
	hud.set_inventory_tabs(
		GameState.get_inventory_lines(),
		PackedStringArray(["Select recipe -> inspect requirements -> CRAFT."]),
		GameState.get_character_view_lines()
	)
