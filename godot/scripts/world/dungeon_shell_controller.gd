extends Node3D

## Dungeon Shell Controller — Phase 1 vertical slice.
##
## Uses GameState for persistent HP, backpack, equipment, weapon damage,
## chest rewards, XP, and level progression.

const INTERACT_RANGE := 2.8
const ATTACK_RANGE := 3.0
const ENEMY_MAX_HP := 30
const ENEMY_AGGRO_RANGE := 8.0
const ENEMY_LEASH_RANGE := 11.0
const ENEMY_STOP_RANGE := 1.55
const ENEMY_RETURN_STOP_RANGE := 0.2
const ENEMY_MOVE_SPEED := 1.2
const ENEMY_RETURN_SPEED := 1.8
const ENEMY_TOUCH_DAMAGE := 5
const ENEMY_DAMAGE_COOLDOWN := 1.4
const HIT_FLASH_SECONDS := 0.18
const DAMAGE_FLASH_SECONDS := 0.22
const ENEMY_XP_REWARD := 80

const BASIC_DAMAGE := 8
const HEAVY_DAMAGE := 15
const CLASS_DAMAGE := 7
const HEAVY_COOLDOWN := 3.0
const CLASS_COOLDOWN := 6.0
const GUARD_SECONDS := 2.0
const CLASS_GUARD_SECONDS := 1.5
const GUARD_DAMAGE_MULTIPLIER := 0.5

const REWARD_ITEM_ID := "rusty_sword"
const REWARD_COIN_ID := "ancient_coin"


enum EnemyState { IDLE, CHASING, RETURNING, DEFEATED }

@onready var player: ThirdPersonController = $Player
@onready var player_mesh: MeshInstance3D = $Player/BodyMesh
@onready var enemy_placeholder: Node3D = $EnemyPlaceholder
@onready var enemy_mesh: MeshInstance3D = $EnemyPlaceholder/EnemyMesh
@onready var chest_placeholder: Node3D = $ChestPlaceholder
@onready var chest_mesh: MeshInstance3D = $ChestPlaceholder/ChestMesh
@onready var exit_portal: Node3D = $ExitPortal
@onready var hud: DebugHud = $DebugHud

var last_interaction_prompt: String = ""
var chest_opened: bool = false
var enemy_hp: int = ENEMY_MAX_HP
var enemy_defeated: bool = false
var player_defeated: bool = false
var hit_flash_timer: float = 0.0
var player_flash_timer: float = 0.0
var enemy_damage_cooldown_timer: float = 0.0
var heavy_attack_cooldown_timer: float = 0.0
var class_feature_cooldown_timer: float = 0.0
var guard_timer: float = 0.0
var enemy_state: EnemyState = EnemyState.IDLE
var enemy_spawn_position: Vector3 = Vector3.ZERO
var last_enemy_hit_message: String = ""
var enemy_hp_label: Label3D

var enemy_default_material: StandardMaterial3D
var enemy_hit_material: StandardMaterial3D
var chest_locked_material: StandardMaterial3D
var chest_unlocked_material: StandardMaterial3D
var chest_opened_material: StandardMaterial3D
var player_default_material: StandardMaterial3D
var player_damage_material: StandardMaterial3D
var player_guard_material: StandardMaterial3D


func _ready() -> void:
	print("[DungeonShell] Dungeon initialized.")
	GameState.ensure_runtime_state()
	player_defeated = GameState.current_hp <= 0
	enemy_hp = ENEMY_MAX_HP
	enemy_defeated = false
	enemy_spawn_position = enemy_placeholder.global_position

	hud.use_item_requested.connect(_on_hud_use_item_requested)
	hud.equip_item_requested.connect(_on_hud_equip_item_requested)
	hud.craft_recipe_requested.connect(_on_hud_craft_recipe_requested)
	GameState.runtime_state_changed.connect(_refresh_runtime_hud)

	_setup_feedback_materials()
	_build_enemy_health_label()
	_refresh_runtime_hud()
	_update_enemy_health_label()
	hud.set_prompt("ATTACK | HEAVY | GUARD | CLASS")
	hud.set_last_result("Dungeon entered as %s." % GameState.get_character_summary())


func _process(delta: float) -> void:
	_update_timers(delta)
	_update_enemy_ai(delta)
	_update_interaction_prompt()

	if Input.is_action_just_pressed("attack"):
		_on_attack_pressed()
	if Input.is_action_just_pressed("heavy_attack"):
		_on_heavy_attack_pressed()
	if Input.is_action_just_pressed("guard"):
		_on_guard_pressed()
	if Input.is_action_just_pressed("class_ability"):
		_on_class_ability_pressed()
	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()


func _setup_feedback_materials() -> void:
	enemy_default_material = _make_material(Color(0.9, 0.1, 0.12, 1), Color(0.4, 0.0, 0.0, 1), 0.6)
	enemy_hit_material = _make_material(Color(1.0, 1.0, 1.0, 1), Color(1.0, 0.35, 0.2, 1), 1.8)
	chest_locked_material = _make_material(Color(0.95, 0.62, 0.08, 1), Color(0.25, 0.1, 0.0, 1), 0.35)
	chest_unlocked_material = _make_material(Color(0.15, 1.0, 0.35, 1), Color(0.0, 0.8, 0.2, 1), 1.0)
	chest_opened_material = _make_material(Color(0.55, 0.55, 0.55, 1), Color(0.1, 0.1, 0.1, 1), 0.2)
	player_default_material = _make_material(Color(1.0, 1.0, 1.0, 1), Color(0.0, 0.0, 0.0, 1), 0.0)
	player_damage_material = _make_material(Color(1.0, 0.2, 0.2, 1), Color(1.0, 0.0, 0.0, 1), 1.3)
	player_guard_material = _make_material(Color(0.25, 0.65, 1.0, 1), Color(0.0, 0.45, 1.0, 1), 1.2)
	enemy_mesh.material_override = enemy_default_material
	chest_mesh.material_override = chest_locked_material
	player_mesh.material_override = player_default_material


func _make_material(albedo: Color, emission_color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	return material


func _build_enemy_health_label() -> void:
	enemy_hp_label = Label3D.new()
	enemy_hp_label.name = "EnemyHealthLabel"
	enemy_hp_label.position = Vector3(0.0, 2.15, 0.0)
	enemy_hp_label.font_size = 72
	enemy_hp_label.pixel_size = 0.01
	enemy_hp_label.modulate = Color(1.0, 0.06, 0.06, 1.0)
	enemy_hp_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	enemy_hp_label.outline_size = 14
	enemy_hp_label.fixed_size = true
	enemy_hp_label.no_depth_test = true
	enemy_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	enemy_placeholder.add_child(enemy_hp_label)


func _update_enemy_health_label() -> void:
	if enemy_hp_label == null:
		return
	if enemy_defeated:
		enemy_hp_label.visible = false
		return
	enemy_hp_label.visible = true
	var filled_count := int(round((float(enemy_hp) / float(ENEMY_MAX_HP)) * 10.0))
	filled_count = clamp(filled_count, 0, 10)
	var empty_count := 10 - filled_count
	enemy_hp_label.text = "Enemy HP %d/%d\n%s%s" % [enemy_hp, ENEMY_MAX_HP, "█".repeat(filled_count), "░".repeat(empty_count)]


func _refresh_runtime_hud() -> void:
	hud.set_player_health(GameState.current_hp, GameState.max_hp)
	hud.set_character_summary(GameState.character_name, "%s %s" % [GameState.species_name, GameState.class_name])
	hud.set_inventory_tabs(GameState.get_inventory_lines(), _crafting_help_lines(), GameState.get_character_view_lines())


func _crafting_help_lines() -> PackedStringArray:
	return PackedStringArray([
		"Crafting uses persistent backpack materials.",
		"Use the test world gathering node for timber.",
	])


func _update_timers(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer = max(0.0, hit_flash_timer - delta)
		if hit_flash_timer <= 0.0 and not enemy_defeated:
			enemy_mesh.material_override = enemy_default_material

	if player_flash_timer > 0.0:
		player_flash_timer = max(0.0, player_flash_timer - delta)
		if player_flash_timer <= 0.0 and guard_timer <= 0.0:
			player_mesh.material_override = player_default_material

	if guard_timer > 0.0:
		guard_timer = max(0.0, guard_timer - delta)
		player_mesh.material_override = player_guard_material
		if guard_timer <= 0.0 and player_flash_timer <= 0.0:
			player_mesh.material_override = player_default_material

	if enemy_damage_cooldown_timer > 0.0:
		enemy_damage_cooldown_timer = max(0.0, enemy_damage_cooldown_timer - delta)
	if heavy_attack_cooldown_timer > 0.0:
		heavy_attack_cooldown_timer = max(0.0, heavy_attack_cooldown_timer - delta)
	if class_feature_cooldown_timer > 0.0:
		class_feature_cooldown_timer = max(0.0, class_feature_cooldown_timer - delta)


func _update_enemy_ai(delta: float) -> void:
	if enemy_defeated:
		enemy_state = EnemyState.DEFEATED
		return
	if player_defeated:
		_set_enemy_state(EnemyState.RETURNING)
		_move_enemy_toward(enemy_spawn_position, ENEMY_RETURN_SPEED, delta, ENEMY_RETURN_STOP_RANGE)
		return

	var distance_to_player := _flat_distance(enemy_placeholder.global_position, player.global_position)
	var distance_from_spawn := _flat_distance(enemy_placeholder.global_position, enemy_spawn_position)

	if distance_to_player > ENEMY_LEASH_RANGE or distance_from_spawn > ENEMY_LEASH_RANGE:
		_set_enemy_state(EnemyState.RETURNING)
	elif distance_to_player <= ENEMY_AGGRO_RANGE and enemy_state != EnemyState.RETURNING:
		_set_enemy_state(EnemyState.CHASING)
	elif enemy_state == EnemyState.CHASING and distance_to_player > ENEMY_AGGRO_RANGE:
		_set_enemy_state(EnemyState.RETURNING)

	match enemy_state:
		EnemyState.CHASING:
			if distance_to_player > ENEMY_STOP_RANGE:
				_move_enemy_toward(player.global_position, ENEMY_MOVE_SPEED, delta, ENEMY_STOP_RANGE)
			else:
				_try_enemy_touch_damage()
		EnemyState.RETURNING:
			var reached_spawn := _move_enemy_toward(enemy_spawn_position, ENEMY_RETURN_SPEED, delta, ENEMY_RETURN_STOP_RANGE)
			if reached_spawn:
				_set_enemy_state(EnemyState.IDLE)


func _set_enemy_state(next_state: EnemyState) -> void:
	if enemy_state == next_state:
		return
	enemy_state = next_state
	_refresh_runtime_hud()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var delta := b - a
	delta.y = 0.0
	return delta.length()


func _move_enemy_toward(target: Vector3, speed: float, delta: float, stop_range: float) -> bool:
	var to_target := target - enemy_placeholder.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= stop_range:
		return true
	var step := min(speed * delta, max(0.0, distance - stop_range))
	if step <= 0.0:
		return true
	enemy_placeholder.global_position += to_target.normalized() * step
	return false


func _try_enemy_touch_damage() -> void:
	if enemy_damage_cooldown_timer > 0.0:
		last_enemy_hit_message = "Enemy attack cooling down: %.1fs" % snapped(enemy_damage_cooldown_timer, 0.1)
		return

	enemy_damage_cooldown_timer = ENEMY_DAMAGE_COOLDOWN
	var damage := ENEMY_TOUCH_DAMAGE
	if guard_timer > 0.0:
		damage = max(1, int(round(float(ENEMY_TOUCH_DAMAGE) * GUARD_DAMAGE_MULTIPLIER)))
		last_enemy_hit_message = "Guard reduced enemy hit: -%d HP" % damage
	else:
		last_enemy_hit_message = "Enemy hit you: -%d HP" % damage

	GameState.set_current_hp(GameState.current_hp - damage)
	player_flash_timer = DAMAGE_FLASH_SECONDS
	player_mesh.material_override = player_damage_material if guard_timer <= 0.0 else player_guard_material

	if GameState.current_hp <= 0:
		player_defeated = true
		hud.set_last_result("You were defeated. Use the cyan exit to leave/reset.")
	else:
		hud.set_last_result("%s. Player HP: %d/%d" % [last_enemy_hit_message, GameState.current_hp, GameState.max_hp])
	_refresh_runtime_hud()


func _update_interaction_prompt() -> void:
	var new_prompt := "ATTACK | HEAVY | GUARD | CLASS"
	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if player_defeated:
		new_prompt = "Defeated. USE cyan exit to reset."
	elif dist_to_exit < INTERACT_RANGE:
		new_prompt = "USE: Exit Dungeon"
	elif not enemy_defeated and dist_to_enemy < ATTACK_RANGE:
		new_prompt = "ATK/HVY/CLS: Enemy HP %d/%d" % [enemy_hp, ENEMY_MAX_HP]
	elif not enemy_defeated and enemy_state == EnemyState.RETURNING:
		new_prompt = "Enemy returning to spawn"
	elif not enemy_defeated and dist_to_enemy < ENEMY_AGGRO_RANGE:
		new_prompt = "Enemy sees you. Use ATK or GRD."
	elif enemy_defeated and dist_to_chest < INTERACT_RANGE and not chest_opened:
		new_prompt = "USE: Open chest"
	elif chest_opened:
		new_prompt = "Chest opened. Exit or inspect loot."

	if new_prompt != last_interaction_prompt:
		last_interaction_prompt = new_prompt
		hud.set_prompt(new_prompt)


func _on_attack_pressed() -> void:
	_try_damage_enemy(BASIC_DAMAGE + GameState.get_weapon_damage_bonus(), "Basic Attack")


func _on_heavy_attack_pressed() -> void:
	if heavy_attack_cooldown_timer > 0.0:
		hud.set_last_result("Heavy cooldown: %.1fs" % snapped(heavy_attack_cooldown_timer, 0.1))
		return
	if _try_damage_enemy(HEAVY_DAMAGE + GameState.get_weapon_damage_bonus(), "Heavy Attack"):
		heavy_attack_cooldown_timer = HEAVY_COOLDOWN


func _on_guard_pressed() -> void:
	if player_defeated:
		hud.set_last_result("You are defeated. Use cyan exit to leave/reset.")
		return
	guard_timer = GUARD_SECONDS
	player_mesh.material_override = player_guard_material
	hud.set_last_result("Guard active: incoming damage reduced.")
	_refresh_runtime_hud()


func _on_class_ability_pressed() -> void:
	if class_feature_cooldown_timer > 0.0:
		hud.set_last_result("Class cooldown: %.1fs" % snapped(class_feature_cooldown_timer, 0.1))
		return
	if player_defeated:
		hud.set_last_result("You are defeated. Use cyan exit to leave/reset.")
		return
	guard_timer = max(guard_timer, CLASS_GUARD_SECONDS)
	player_mesh.material_override = player_guard_material
	class_feature_cooldown_timer = CLASS_COOLDOWN
	_try_damage_enemy(CLASS_DAMAGE + GameState.get_weapon_damage_bonus(), "Class Feature")
	_refresh_runtime_hud()


func _try_damage_enemy(damage: int, source_label: String) -> bool:
	if player_defeated:
		hud.set_last_result("You are defeated. Use cyan exit to leave/reset.")
		return false
	if enemy_defeated:
		hud.set_last_result("Enemy already defeated. Open the chest.")
		return false
	if player.global_position.distance_to(enemy_placeholder.global_position) > ATTACK_RANGE:
		hud.set_last_result("Too far. Move closer to use %s." % source_label)
		return false

	enemy_hp = max(0, enemy_hp - damage)
	_update_enemy_health_label()
	_set_enemy_state(EnemyState.CHASING)
	hit_flash_timer = HIT_FLASH_SECONDS
	enemy_mesh.material_override = enemy_hit_material

	if enemy_hp <= 0:
		enemy_defeated = true
		_set_enemy_state(EnemyState.DEFEATED)
		_update_enemy_health_label()
		enemy_placeholder.visible = false
		chest_mesh.material_override = chest_unlocked_material
		var xp_result := GameState.add_xp(ENEMY_XP_REWARD)
		hud.set_last_result("%s defeated enemy! %s Chest unlocked." % [source_label, str(xp_result.get("message", "XP gained."))])
	else:
		hud.set_last_result("%s: -%d HP. Enemy HP: %d/%d" % [source_label, damage, enemy_hp, ENEMY_MAX_HP])

	_refresh_runtime_hud()
	_update_interaction_prompt()
	return true


func _on_interact_pressed() -> void:
	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if dist_to_exit < INTERACT_RANGE:
		_exit_to_test_world()
		return
	if player_defeated:
		hud.set_last_result("Player defeated. Use cyan exit to leave/reset.")
		return
	if dist_to_chest < INTERACT_RANGE:
		_on_chest_interact()
		return
	hud.set_last_result("No dungeon object nearby.")


func _on_chest_interact() -> void:
	if not enemy_defeated:
		hud.set_last_result("Chest locked. Defeat the enemy first.")
		return
	if chest_opened:
		hud.set_last_result("Chest already opened. Reward claimed.")
		return

	chest_opened = true
	chest_mesh.material_override = chest_opened_material
	chest_mesh.scale = Vector3(1.15, 0.55, 1.0)
	GameState.add_item(REWARD_ITEM_ID, 1)
	GameState.add_item(REWARD_COIN_ID, 5)
	hud.set_last_result("Chest opened: %s x1, %s x5." % [GameState.get_item_name(REWARD_ITEM_ID), GameState.get_item_name(REWARD_COIN_ID)])
	_refresh_runtime_hud()
	_update_interaction_prompt()


func _on_hud_use_item_requested(item_id: String) -> void:
	var result := GameState.use_item(item_id)
	hud.set_last_result(str(result.get("message", "Used item.")))
	player_defeated = GameState.current_hp <= 0
	_refresh_runtime_hud()


func _on_hud_equip_item_requested(item_id: String) -> void:
	if GameState.equip_item(item_id):
		hud.set_last_result("Equipped %s. Weapon bonus now +%d." % [GameState.get_item_name(item_id), GameState.get_weapon_damage_bonus()])
	else:
		hud.set_last_result("Cannot equip %s." % GameState.get_item_name(item_id))
	_refresh_runtime_hud()


func _on_hud_craft_recipe_requested(recipe: Dictionary) -> void:
	var requirements: Dictionary = recipe.get("requirements", {})
	for item_id in requirements.keys():
		var required := int(requirements[item_id])
		if GameState.get_item_count(str(item_id)) < required:
			hud.set_last_result("Missing %s." % GameState.get_item_name(str(item_id)))
			return
	for item_id in requirements.keys():
		GameState.remove_item(str(item_id), int(requirements[item_id]))
	var output_item_id := str(recipe.get("output_item_id", recipe.get("id", "crafted_item")))
	var output_quantity := int(recipe.get("output_quantity", 1))
	GameState.add_item(output_item_id, output_quantity)
	hud.set_last_result("Crafted %s x%d" % [GameState.get_item_name(output_item_id), output_quantity])
	_refresh_runtime_hud()


func _cooldown_label(timer: float) -> String:
	return "Ready" if timer <= 0.0 else "%.1fs" % snapped(timer, 0.1)


func _exit_to_test_world() -> void:
	print("[DungeonShell] Exiting dungeon...")
	get_tree().change_scene_to_file("res://scenes/test_world/test_world.tscn")
