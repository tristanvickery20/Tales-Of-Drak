extends Node3D

## Test World Controller — drives the full gameplay loop:
## gathering, building, combat, objectives, save/load, pause.

const INTERACT_RANGE := 3.0
const BUILD_PLACEMENT_DISTANCE := 3.0

@onready var player: CharacterBody3D = $Player
@onready var placed_build_parent: Node3D = $PlacedBuildPieces
@onready var hud: CanvasLayer = $DebugHud

# Gather nodes (set from scene)
var gather_nodes: Dictionary = {}  # node_name -> {node, resource, depleted}
var enemies: Array = []
var build_mode_active: bool = false
var build_selection: int = 0
var placed_count: int = 0
var status_message: String = ""
var status_timer: float = 0.0

const BUILD_OPTIONS = [
	{"name": "Campfire", "key": "campfire", "color": Color(1, 0.5, 0.1, 1), "size": Vector3(1, 0.5, 1)},
	{"name": "Wooden Wall", "key": "wooden_wall", "color": Color(0.6, 0.35, 0.15, 1), "size": Vector3(2, 2, 0.3)},
	{"name": "Wooden Foundation", "key": "wooden_foundation", "color": Color(0.5, 0.3, 0.1, 1), "size": Vector3(3, 0.3, 3)},
	{"name": "Drak Totem", "key": "drak_totem", "color": Color(0.5, 0.1, 0.8, 1), "size": Vector3(1, 2.5, 1)},
]


func _ready() -> void:
	# Ensure GameState is initialized
	if GameState != null:
		GameState.ensure_runtime_state()
	else:
		print("[TestWorld] ERROR: GameState not found!")

	# Register the player in the "player" group (enemies use it)
	player.add_to_group("player")

	# Discover gather nodes in the scene
	_discover_gather_nodes()

	# Mark depleted nodes from loaded save
	if GameState != null:
		for node_name in GameState.depleted_nodes:
			if gather_nodes.has(node_name):
				gather_nodes[node_name]["depleted"] = true
				gather_nodes[node_name]["node"].visible = false

	# Restore placed buildings from save
	if GameState != null:
		for build_data in GameState.placed_buildings:
			_spawn_building(build_data)

	# Connect to GameState changes
	if GameState != null and GameState.has_signal("runtime_state_changed"):
		GameState.runtime_state_changed.connect(_on_gamestate_changed)

	_update_hud()
	print("[TestWorld] Controller initialized.")


func _discover_gather_nodes() -> void:
	# Look for nodes in the "GatherNodes" group or by naming convention
	var nodes = get_tree().get_nodes_in_group("gather_node")
	for node in nodes:
		_register_gather_node(node)

	# Also check direct children for backward compat
	for child in get_children():
		if "Gather" in child.name or "gather" in child.name.to_lower():
			if child not in nodes:
				_register_gather_node(child)


func _register_gather_node(node: Node) -> void:
	var resource_type = "wood"  # default
	var nl = node.name.to_lower()
	if "tree" in nl or "wood" in nl or "log" in nl:
		resource_type = "wood"
	elif "rock" in nl or "stone" in nl:
		resource_type = "stone"
	elif "plant" in nl or "fiber" in nl or "bush" in nl:
		resource_type = "fiber"
	elif "crystal" in nl or "drak" in nl or "essence" in nl:
		resource_type = "drak_essence"

	gather_nodes[node.name] = {
		"node": node,
		"resource": resource_type,
		"depleted": false,
	}


func _process(delta: float) -> void:
	_check_player_death()
	_update_status(delta)
	_update_prompt()

	# Save/Load hotkeys
	if Input.is_action_just_pressed("save_game"):
		_save()
	if Input.is_action_just_pressed("load_game"):
		_load()

	# Build mode toggle
	if Input.is_action_just_pressed("build_mode"):
		build_mode_active = not build_mode_active
		if build_mode_active:
			_status("Build mode ON — 1-4 select, Left Click place")
		else:
			_status("Build mode OFF")

	if build_mode_active:
		_handle_build_mode()
	else:
		# Attack
		if Input.is_action_just_pressed("attack"):
			_attack_nearby_enemy()
		# Interact
		if Input.is_action_just_pressed("interact"):
			_gather_nearby_node()
		# Inventory toggle
		if Input.is_action_just_pressed("inventory"):
			_toggle_inventory_hud()


func _check_player_death() -> void:
	if player == null:
		return
	if player.is_dead:
		if hud != null and hud.has_method("set_prompt"):
			hud.set_prompt("You died. Respawning...")


func _update_status(delta: float) -> void:
	if status_timer > 0.0:
		status_timer -= delta
		if status_timer <= 0.0:
			status_message = ""
	if hud != null and hud.has_method("set_last_result"):
		hud.set_last_result(status_message)


func _update_prompt() -> void:
	if player == null:
		return
	var prompt = "[WASD] Move  [Shift] Sprint  [Space] Jump  [B] Build  [I] Inventory  [F5] Save  [F9] Load"

	if build_mode_active:
		var opt = BUILD_OPTIONS[build_selection]
		prompt = "BUILD MODE — [1-4] Select  [Left Click] Place %s  [B] Exit" % opt["name"]
	elif _get_nearest_gather_node() != null:
		var gn = _get_nearest_gather_node()
		prompt = "[E] Gather %s  |  %s" % [gn["resource"].capitalize(), prompt]
	elif _has_enemy_nearby():
		prompt = "[Left Click] Attack  |  %s" % prompt

	if hud != null and hud.has_method("set_prompt"):
		hud.set_prompt(prompt)


func _handle_build_mode() -> void:
	# Select build piece with number keys
	for i in range(4):
		if Input.is_key_pressed(KEY_1 + i):
			build_selection = i

	# Place with left click (already handled by attack action)
	if Input.is_action_just_pressed("attack"):
		_place_build()


func _place_build() -> void:
	if player == null:
		return

	var opt = BUILD_OPTIONS[build_selection]
	var costs = GameState.BUILD_COSTS.get(opt["key"], {})

	if not GameState.has_resources(costs):
		_status("Not enough resources for %s" % opt["name"])
		return

	if not GameState.spend_resources(costs):
		_status("Failed to build %s" % opt["name"])
		return

	# Place in front of player
	var forward = -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var pos = player.global_position + forward * BUILD_PLACEMENT_DISTANCE
	pos.y = 0.2

	var build_data = {
		"type": opt["key"],
		"name": opt["name"],
		"position": {"x": pos.x, "y": pos.y, "z": pos.z},
		"color": {"r": opt["color"].r, "g": opt["color"].g, "b": opt["color"].b},
		"size": {"x": opt["size"].x, "y": opt["size"].y, "z": opt["size"].z},
	}
	_spawn_building(build_data)

	if GameState != null:
		GameState.placed_buildings.append(build_data)

	# Mark objectives
	if opt["key"] == "campfire":
		GameState.mark_objective_complete("campfire")
	if opt["key"] == "drak_totem":
		GameState.mark_objective_complete("drak_totem")

	_status("Placed %s" % opt["name"])
	_check_objectives()
	_update_hud()


func _spawn_building(build_data: Dictionary) -> void:
	var body = StaticBody3D.new()
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()

	var size_data = build_data.get("size", {"x": 2, "y": 0.3, "z": 2})
	mesh.scale = Vector3(
		float(size_data.get("x", 2)),
		float(size_data.get("y", 0.3)),
		float(size_data.get("z", 2))
	)

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	col.shape = box

	var mat = StandardMaterial3D.new()
	var color_data = build_data.get("color", {"r": 1, "g": 0.5, "b": 0.1})
	mat.albedo_color = Color(
		float(color_data.get("r", 1)),
		float(color_data.get("g", 0.5)),
		float(color_data.get("b", 0.1)),
		1
	)
	mat.roughness = 0.8
	mesh.material_override = mat

	var pos_data = build_data.get("position", {"x": 0, "y": 0.2, "z": 0})
	body.global_position = Vector3(
		float(pos_data.get("x", 0)),
		float(pos_data.get("y", 0.2)),
		float(pos_data.get("z", 0))
	)

	body.add_child(mesh)
	body.add_child(col)
	placed_build_parent.add_child(body)
	placed_count += 1


func _gather_nearby_node() -> void:
	var gn = _get_nearest_gather_node()
	if gn == null:
		_status("Nothing nearby to gather.")
		return

	if gn["depleted"]:
		_status("Already depleted.")
		return

	var resource = gn["resource"]
	var amount = randi_range(1, 3)

	GameState.add_resource(resource, amount)
	gn["depleted"] = true
	gn["node"].visible = false

	if GameState != null:
		GameState.depleted_nodes.append(gn["node"].name)

	_status("Gathered %s x%d" % [resource.capitalize(), amount])
	_check_objectives()
	_update_hud()


func _get_nearest_gather_node() -> Dictionary:
	if player == null:
		return {}

	var nearest = null
	var nearest_dist = INTERACT_RANGE
	var nearest_name = ""

	for node_name in gather_nodes.keys():
		var gn = gather_nodes[node_name]
		if gn["depleted"]:
			continue
		var dist = player.global_position.distance_to(gn["node"].global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = gn
			nearest_name = node_name

	if nearest != null:
		var result = nearest.duplicate()
		result["node_name"] = nearest_name
		return result
	return {}


func _attack_nearby_enemy() -> void:
	if player == null:
		return
	var controller = player as ThirdPersonController
	if controller == null:
		return
	if controller.attack_timer > 0.0:
		return

	var nearest_enemy = null
	var nearest_dist = controller.attack_range

	for child in get_children():
		if child is EnemyDrakling and not child.is_dead:
			var dist = player.global_position.distance_to(child.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = child

	if nearest_enemy != null:
		controller.attack_timer = controller.attack_cooldown
		nearest_enemy.take_damage(controller.attack_damage)
		_status("Hit enemy for %d damage!" % controller.attack_damage)
	else:
		_status("No enemy in range.")


func _has_enemy_nearby() -> bool:
	if player == null:
		return false
	var controller = player as ThirdPersonController
	var check_range = controller.attack_range if controller != null else 2.5
	for child in get_children():
		if child is EnemyDrakling and not child.is_dead:
			if player.global_position.distance_to(child.global_position) < check_range:
				return true
	return false


func _on_gamestate_changed() -> void:
	_update_hud()


func _check_objectives() -> void:
	if GameState == null:
		return
	while GameState.check_objective_complete():
		var completed = GameState.advance_objective()
		_status("Objective complete: %s" % completed)

func _update_hud() -> void:
	if hud == null or GameState == null:
		return
	# Update HP
	var hp_current = int(player.current_health) if player != null else int(GameState.current_hp)
	var hp_max = int(player.max_health) if player != null else int(GameState.max_hp)
	_hud_call("set_player_health", [hp_current, hp_max])

	# Update resources
	_hud_call("set_resources", [GameState.resources.duplicate()])

	# Update objective
	_hud_call("set_objective", [GameState.get_current_objective()])

	# Show build mode
	_hud_call("set_build_mode", [build_mode_active, BUILD_OPTIONS[build_selection]["name"] if build_mode_active else ""])


func _toggle_inventory_hud() -> void:
	if hud != null and hud.has_method("toggle_inventory"):
		hud.toggle_inventory()


func _hud_call(method_name: String, args: Array) -> void:
	if hud != null and hud.has_method(method_name):
		hud.callv(method_name, args)


func _status(msg: String) -> void:
	status_message = msg
	status_timer = 3.0


func _save() -> void:
	if GameState == null:
		return
	var data = GameState.save_game()
	data["player_position"] = {
		"x": player.global_position.x,
		"y": player.global_position.y,
		"z": player.global_position.z,
	}
	SaveManager.save_data(data)
	_status("Game saved.")
	print("[TestWorld] Game saved.")


func _load() -> void:
	var data = SaveManager.load_data()
	if data.is_empty():
		_status("No save file found.")
		return
	if GameState != null:
		GameState.load_game(data)

	# Restore player position
	if player != null and data.has("player_position"):
		var pos = data["player_position"]
		player.global_position = Vector3(
			float(pos.get("x", 0)),
			float(pos.get("y", 1)),
			float(pos.get("z", 3))
		)
		player.spawn_point = player.global_position
		player.current_health = player.max_health

	# Clear and restore buildings
	for child in placed_build_parent.get_children():
		child.queue_free()
	placed_count = 0
	if GameState != null:
		for build_data in GameState.placed_buildings:
			_spawn_building(build_data)

	# Update gather nodes
	if GameState != null:
		for node_name in GameState.depleted_nodes:
			if gather_nodes.has(node_name):
				gather_nodes[node_name]["depleted"] = true
				gather_nodes[node_name]["node"].visible = false

	_status("Game loaded.")
	_update_hud()
	print("[TestWorld] Game loaded.")
