extends Node3D

## Test World Controller — Phase 1 vertical slice.
##
## Uses GameState as the persistent runtime source for:
## inventory, equipment, HP, XP, and level.

const GATHER_INTERACT_RANGE := 3.0
const DUNGEON_INTERACT_RANGE := 3.0

@onready var player: ThirdPersonController = $Player
@onready var gather_node_marker: Node3D = $GatherNode
@onready var build_spawn_marker: Node3D = $BuildSpawnMarker
@onready var placed_build_parent: Node3D = $PlacedBuildPieces
@onready var dungeon_portal: Node3D = $DungeonPortal
@onready var hud: DebugHud = $DebugHud

var character: PlayerCharacter


func _ready() -> void:
	GameState.ensure_runtime_state()
	_init_session()
	hud.craft_recipe_requested.connect(_on_hud_craft_recipe_requested)
	hud.use_item_requested.connect(_on_hud_use_item_requested)
	hud.equip_item_requested.connect(_on_hud_equip_item_requested)
	GameState.runtime_state_changed.connect(_update_hud_inventory)
	_update_hud_inventory()


func _process(_delta: float) -> void:
	_update_prompt()

	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()
	if Input.is_action_just_pressed("craft"):
		_on_craft_pressed()
	if Input.is_action_just_pressed("place_build"):
		_on_place_pressed()


func _init_session() -> void:
	character = PlayerCharacter.new()
	character.character_id = "runtime_" + GameState.character_name.to_lower().replace(" ", "_")
	character.display_name = GameState.character_name
	character.species_id = GameState.species_id
	character.class_id = GameState.class_id
	character.subclass_id = GameState.subclass_id
	character.level = GameState.level
	character.xp = GameState.xp
	character.derived_stats = {
		"max_health": GameState.max_hp,
		"armor_class": GameState.get_armor_class(),
		"initiative": 0,
		"movement_speed": 30,
	}

	hud.set_player_health(GameState.current_hp, GameState.max_hp)
	hud.set_character_summary(GameState.character_name, "%s %s" % [GameState.species_name, GameState.class_name])
	hud.set_last_result("Entered world as %s." % GameState.get_character_summary())
	print("[TestWorld] Runtime session initialized for %s" % GameState.get_character_summary())


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

	if player.global_position.distance_to(gather_node_marker.global_position) > GATHER_INTERACT_RANGE:
		hud.set_last_result("Too far from gathering node.")
		return

	GameState.add_item("weathered_timber", 3)
	hud.set_last_result("Gathered Weathered Timber x3")
	_update_hud_inventory()


func _enter_dungeon() -> void:
	print("[TestWorld] Entering dungeon...")
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_shell.tscn")


func _on_craft_pressed() -> void:
	var quick_recipe := {
		"id": "craft_torch_kit",
		"name": "Torch Kit",
		"requirements": {"weathered_timber": 1},
		"output_item_id": "torch_kit",
		"output_quantity": 2,
	}
	_craft_recipe_from_dictionary(quick_recipe)


func _on_hud_craft_recipe_requested(recipe: Dictionary) -> void:
	_craft_recipe_from_dictionary(recipe)


func _craft_recipe_from_dictionary(recipe: Dictionary) -> void:
	var recipe_name := str(recipe.get("name", "recipe"))
	var requirements: Dictionary = recipe.get("requirements", {})
	var output_item_id := str(recipe.get("output_item_id", recipe.get("id", "crafted_item")))
	var output_quantity := int(recipe.get("output_quantity", 1))

	if output_item_id.is_empty():
		hud.set_last_result("Craft failed: recipe has no output item.")
		return
	if output_quantity <= 0:
		output_quantity = 1

	for item_id in requirements.keys():
		var required := int(requirements[item_id])
		var owned := GameState.get_item_count(str(item_id))
		if owned < required:
			hud.set_last_result("Missing %s: %d / %d" % [GameState.get_item_name(str(item_id)), owned, required])
			_update_hud_inventory()
			return

	for item_id in requirements.keys():
		GameState.remove_item(str(item_id), int(requirements[item_id]))
	GameState.add_item(output_item_id, output_quantity)
	hud.set_last_result("Crafted %s x%d" % [recipe_name, output_quantity])
	_update_hud_inventory()


func _on_hud_use_item_requested(item_id: String) -> void:
	var result := GameState.use_item(item_id)
	hud.set_player_health(GameState.current_hp, GameState.max_hp)
	hud.set_last_result(str(result.get("message", "Used item.")))
	_update_hud_inventory()


func _on_hud_equip_item_requested(item_id: String) -> void:
	if GameState.equip_item(item_id):
		hud.set_last_result("Equipped %s." % GameState.get_item_name(item_id))
	else:
		hud.set_last_result("Cannot equip %s." % GameState.get_item_name(item_id))
	_update_hud_inventory()


func _on_place_pressed() -> void:
	if GameState.get_item_count("weathered_timber") < 8:
		hud.set_last_result("Build failed: need Weathered Timber x8")
		return
	GameState.remove_item("weathered_timber", 8)
	_spawn_build_placeholder(build_spawn_marker.global_position)
	hud.set_last_result("Placed Timber Foundation")
	_update_hud_inventory()


func _spawn_build_placeholder(world_pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.scale = Vector3(2.0, 0.4, 2.0)
	mesh.global_position = world_pos + Vector3(0.2 * placed_build_parent.get_child_count(), 0.2, 0.2 * placed_build_parent.get_child_count())
	placed_build_parent.add_child(mesh)


func _update_hud_inventory() -> void:
	GameState.ensure_runtime_state()
	hud.set_player_health(GameState.current_hp, GameState.max_hp)
	var crafting_lines := PackedStringArray([
		"Select recipe -> inspect requirements -> CRAFT.",
		"Crafting uses persistent GameState inventory.",
	])
	hud.set_inventory_tabs(GameState.get_inventory_lines(), crafting_lines, GameState.get_character_view_lines())
