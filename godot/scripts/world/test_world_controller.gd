extends Node3D

## Stage 8 Test World Controller
## Initializes framework systems and wires scene interactions.

const GATHER_INTERACT_RANGE := 3.0

@onready var player: ThirdPersonController = $Player
@onready var gather_node_marker: Node3D = $GatherNode
@onready var build_spawn_marker: Node3D = $BuildSpawnMarker
@onready var placed_build_parent: Node3D = $PlacedBuildPieces
@onready var hud: DebugHud = $DebugHud

var registry: DataRegistry
var character: PlayerCharacter
var inventory: Inventory
var equipment: Equipment
var gathering_system: GatheringSystem
var crafting_system: CraftingSystem
var building_system: BuildingSystem
var gathering_node: GatheringNode


func _ready() -> void:
	_init_session()
	_update_hud_inventory()


func _process(_delta: float) -> void:
	_update_prompt()

	if Input.is_key_pressed(KEY_E):
		_on_interact_pressed()
	if Input.is_key_pressed(KEY_C):
		_on_craft_pressed()
	if Input.is_key_pressed(KEY_B):
		_on_place_pressed()


func _init_session() -> void:
	registry = DataRegistry.new()
	var load_ok := registry.load_all_design_data()
	if not load_ok:
		hud.set_last_result("DataRegistry failed to load.")
		push_error("[TestWorld] DataRegistry init failed")
		return

	var factory := CharacterFactory.new()
	character = factory.create_level_one_character(registry, "Sandbox Runner", "human", "warden", "ashen_guard")
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

	hud.set_character_summary(character.display_name, character.class_id)
	hud.set_last_result("Game session initialized.")
	print("[TestWorld] Game session initialized.")


func _update_prompt() -> void:
	var prompt := "Move: WASD | Jump: Space | Sprint: Shift | Craft: C | Place: B"
	if player.global_position.distance_to(gather_node_marker.global_position) <= GATHER_INTERACT_RANGE:
		prompt += " | Interact Gather: E"
	hud.set_prompt(prompt)


func _on_interact_pressed() -> void:
	if character == null:
		return
	if player.global_position.distance_to(gather_node_marker.global_position) > GATHER_INTERACT_RANGE:
		hud.set_last_result("Too far from gathering node.")
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


func _on_craft_pressed() -> void:
	if character == null:
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
	var pos := {
		"x": build_spawn_marker.global_position.x,
		"y": build_spawn_marker.global_position.y,
		"z": build_spawn_marker.global_position.z
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
	if inventory == null:
		return
	var lines: PackedStringArray = []
	for stack in inventory.get_all_items():
		lines.append("%s x%d" % [stack.get("item_id", "?"), int(stack.get("quantity", 0))])
	hud.set_inventory_summary(lines)
