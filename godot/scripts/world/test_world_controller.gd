extends Node3D

## Stage 8 Test World Controller (Stage 14/15 HUD + inventory shell)
## Initializes framework systems and wires scene interactions.
##
## Character Creator -> Test World -> Dungeon Shell.

const GATHER_INTERACT_RANGE := 3.0
const DUNGEON_INTERACT_RANGE := 3.0

@onready var player: ThirdPersonController = $Player
@onready var gather_node_marker: Node3D = $GatherNode
@onready var build_spawn_marker: Node3D = $BuildSpawnMarker
@onready var placed_build_parent: Node3D = $PlacedBuildPieces
@onready var dungeon_portal: Node3D = $DungeonPortal
@onready var hud: DebugHud = $DebugHud

var registry: DataRegistry
var character: PlayerCharacter
var inventory: Inventory
var equipment: Equipment
var gathering_system: GatheringSystem
var crafting_system: CraftingSystem
var building_system: BuildingSystem
var gathering_node: GatheringNode

var web_preview_mode: bool = false
var web_inventory: Dictionary = {}


func _ready() -> void:
	_init_session()
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
	if OS.has_feature("web"):
		_init_web_preview_session()
		return

	registry = DataRegistry.new()
	var load_ok := registry.load_all_design_data()
	if not load_ok:
		hud.set_last_result("DataRegistry failed to load.")
		push_error("[TestWorld] DataRegistry init failed")
		return

	var factory := CharacterFactory.new()
	character = factory.create_level_one_character(
		registry,
		GameState.character_name,
		GameState.species_id,
		GameState.class_id,
		GameState.subclass_id
	)
	if character == null:
		character = factory.create_level_one_character(registry, "Adventurer", "human", "fighter", "champion")
	if character == null:
		hud.set_last_result("Character creation failed.")
		return

	inventory = Inventory.new()
	inventory.initialize(character.character_id, registry, 40)
	inventory.add_item("starter_hatchet", 1)
	inventory.add_item("weathered_timber", 10)
	inventory.add_item("torch_kit", 1)

	equipment = Equipment.new()
	equipment.initialize(character.character_id, registry)

	gathering_system = GatheringSystem.new()
	gathering_system.initialize(registry)

	crafting_system = CraftingSystem.new()
	crafting_system.initialize(registry)

	building_system = BuildingSystem.new()
	building_system.initialize(registry)

	gathering_node = GatheringNode.new()
	gathering_node.load_from_record("tw_node_01", registry.get_record("gathering_node", "weathered_tree_deadfall"))

	var max_hp := int(character.derived_stats.get("max_health", 11))
	hud.set_player_health(max_hp, max_hp)
	hud.set_character_summary(GameState.character_name, "%s %s" % [GameState.species_name, GameState.class_name])
	hud.set_last_result("Entered world as %s." % GameState.get_character_summary())
	print("[TestWorld] Game session initialized for %s" % GameState.get_character_summary())


func _init_web_preview_session() -> void:
	web_preview_mode = true

	character = PlayerCharacter.new()
	character.character_id = "web_" + GameState.character_name.to_lower().replace(" ", "_")
	character.display_name = GameState.character_name
	character.species_id = GameState.species_id
	character.class_id = GameState.class_id
	character.subclass_id = GameState.subclass_id
	character.level = 1
	character.xp = 0
	character.ability_scores = {
		"strength": 10,
		"dexterity": 10,
		"constitution": 10,
		"intelligence": 10,
		"wisdom": 10,
		"charisma": 10,
	}
	character.derived_stats = {
		"max_health": 11,
		"armor_class": 10,
		"initiative": 0,
		"movement_speed": 30,
	}

	web_inventory = {
		"starter_hatchet": 1,
		"weathered_timber": 10,
		"torch_kit": 1,
	}

	hud.set_player_health(11, 11)
	hud.set_character_summary(GameState.character_name, "%s %s" % [GameState.species_name, GameState.class_name])
	hud.set_last_result("Entered world as %s." % GameState.get_character_summary())
	print("[TestWorld] Web sandbox session initialized for %s" % GameState.get_character_summary())


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

	if character == null:
		return
	if player.global_position.distance_to(gather_node_marker.global_position) > GATHER_INTERACT_RANGE:
		hud.set_last_result("Too far from gathering node.")
		return

	if web_preview_mode:
		_add_web_item("weathered_timber", 3)
		hud.set_last_result("Gathered weathered_timber x3")
		_update_hud_inventory()
		return

	if gathering_node.is_depleted:
		gathering_system.reset_node(gathering_node)

	var result := gathering_system.gather(gathering_node, inventory)
	var text := "Gather failed"
	if result.get("ok", false):
		text = "Gathered %s x%s" % [result.get("item_id", "?"), result.get("quantity", 0)]
	else:
		text = "Gather failed: %s" % result.get("reason", "unknown")
	print("[TestWorld] %s" % text)
	hud.set_last_result(text)
	_update_hud_inventory()


func _enter_dungeon() -> void:
	print("[TestWorld] Entering dungeon...")
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_shell.tscn")


func _on_craft_pressed() -> void:
	if character == null:
		return

	if web_preview_mode:
		if _get_web_item_count("weathered_timber") < 1:
			hud.set_last_result("Craft failed: need weathered_timber x1")
			return
		_remove_web_item("weathered_timber", 1)
		_add_web_item("torch_kit", 2)
		hud.set_last_result("Crafted torch_kit")
		_update_hud_inventory()
		return

	var result := crafting_system.craft("craft_torch_kit", inventory)
	var text := "Craft failed"
	if result.get("ok", false):
		text = "Crafted torch_kit"
	else:
		text = "Craft failed: %s" % result.get("reason", "unknown")
	print("[TestWorld] %s" % text)
	hud.set_last_result(text)
	_update_hud_inventory()


func _on_place_pressed() -> void:
	if character == null:
		return

	if web_preview_mode:
		if _get_web_item_count("weathered_timber") < 8:
			hud.set_last_result("Build failed: need weathered_timber x8")
			return
		_remove_web_item("weathered_timber", 8)
		_spawn_build_placeholder(build_spawn_marker.global_position)
		hud.set_last_result("Placed timber_foundation")
		_update_hud_inventory()
		return

	var pos := {
		"x": build_spawn_marker.global_position.x,
		"y": build_spawn_marker.global_position.y,
		"z": build_spawn_marker.global_position.z,
	}
	var rot := {"x": 0.0, "y": 0.0, "z": 0.0}
	var result := building_system.place_piece("timber_foundation", inventory, pos, rot)
	var text := "Build failed"
	if result.get("ok", false):
		_spawn_build_placeholder(build_spawn_marker.global_position)
		text = "Placed timber_foundation"
	else:
		text = "Build failed: %s" % result.get("reason", "unknown")
	print("[TestWorld] %s" % text)
	hud.set_last_result(text)
	_update_hud_inventory()


func _spawn_build_placeholder(world_pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.scale = Vector3(2.0, 0.4, 2.0)
	mesh.global_position = world_pos + Vector3(0.2 * placed_build_parent.get_child_count(), 0.2, 0.2 * placed_build_parent.get_child_count())
	placed_build_parent.add_child(mesh)


func _update_hud_inventory() -> void:
	var backpack_lines: PackedStringArray = []
	if web_preview_mode:
		for item_id in web_inventory.keys():
			backpack_lines.append("%s x%d" % [item_id, int(web_inventory[item_id])])
	else:
		if inventory == null:
			return
		for stack in inventory.get_all_items():
			backpack_lines.append("%s x%d" % [stack.get("item_id", "?"), int(stack.get("quantity", 0))])

	var crafting_lines := PackedStringArray([
		"torch_kit: weathered_timber x1 -> torch_kit x2",
		"Build: timber_foundation costs weathered_timber x8",
		"More recipes come after the inventory shell is stable.",
	])
	var character_lines := PackedStringArray([
		GameState.get_character_summary(),
		"Main hand: empty",
		"Off hand: empty",
		"Armor: plain clothes",
		"Armor / weapons UI shell only for now.",
	])
	hud.set_inventory_tabs(backpack_lines, crafting_lines, character_lines)


func _get_web_item_count(item_id: String) -> int:
	return int(web_inventory.get(item_id, 0))


func _add_web_item(item_id: String, quantity: int) -> void:
	web_inventory[item_id] = _get_web_item_count(item_id) + quantity


func _remove_web_item(item_id: String, quantity: int) -> void:
	web_inventory[item_id] = max(0, _get_web_item_count(item_id) - quantity)
