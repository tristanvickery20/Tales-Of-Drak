extends Node3D

## Stage 11 Basic Enemy AI
##
## Keeps AI intentionally tiny:
## - enemy detects player nearby
## - enemy moves slowly toward player
## - enemy deals touch damage on cooldown
## - HUD shows player HP
## - player can still defeat enemy and unlock chest

const INTERACT_RANGE := 2.8
const ATTACK_RANGE := 3.0
const ENEMY_MAX_HP := 30
const PLAYER_MAX_HP := 50
const PLAYER_ATTACK_DAMAGE := 10
const ENEMY_AGGRO_RANGE := 8.0
const ENEMY_STOP_RANGE := 1.45
const ENEMY_MOVE_SPEED := 1.4
const ENEMY_TOUCH_DAMAGE := 5
const ENEMY_DAMAGE_COOLDOWN := 1.2
const HIT_FLASH_SECONDS := 0.18
const DAMAGE_FLASH_SECONDS := 0.22

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
var player_hp: int = PLAYER_MAX_HP
var player_defeated: bool = false
var hit_flash_timer: float = 0.0
var player_flash_timer: float = 0.0
var enemy_damage_cooldown_timer: float = 0.0

var enemy_default_material: StandardMaterial3D
var enemy_hit_material: StandardMaterial3D
var chest_locked_material: StandardMaterial3D
var chest_unlocked_material: StandardMaterial3D
var chest_opened_material: StandardMaterial3D
var player_default_material: StandardMaterial3D
var player_damage_material: StandardMaterial3D


func _ready() -> void:
	print("[DungeonShell] Dungeon initialized.")
	_setup_feedback_materials()
	hud.set_character_summary("Dungeon Shell", "Stage 11")
	_update_status_lines()
	hud.set_prompt("Move | ATTACK enemy | INTERACT objects")
	hud.set_last_result("Enemy will chase if you get close. Defeat it to unlock the chest.")


func _process(delta: float) -> void:
	_update_timers(delta)
	_update_enemy_ai(delta)
	_update_interaction_prompt()

	if Input.is_action_just_pressed("attack"):
		_on_attack_pressed()
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


func _update_timers(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer = max(0.0, hit_flash_timer - delta)
		if hit_flash_timer <= 0.0 and not enemy_defeated:
			enemy_mesh.material_override = enemy_default_material

	if player_flash_timer > 0.0:
		player_flash_timer = max(0.0, player_flash_timer - delta)
		if player_flash_timer <= 0.0:
			player_mesh.material_override = player_default_material

	if enemy_damage_cooldown_timer > 0.0:
		enemy_damage_cooldown_timer = max(0.0, enemy_damage_cooldown_timer - delta)


func _update_enemy_ai(delta: float) -> void:
	if enemy_defeated or player_defeated:
		return

	var to_player := player.global_position - enemy_placeholder.global_position
	to_player.y = 0.0
	var distance := to_player.length()

	if distance > ENEMY_AGGRO_RANGE:
		return

	if distance > ENEMY_STOP_RANGE:
		var direction := to_player.normalized()
		enemy_placeholder.global_position += direction * ENEMY_MOVE_SPEED * delta
		return

	_try_enemy_touch_damage()


func _try_enemy_touch_damage() -> void:
	if enemy_damage_cooldown_timer > 0.0:
		return

	enemy_damage_cooldown_timer = ENEMY_DAMAGE_COOLDOWN
	player_hp = max(0, player_hp - ENEMY_TOUCH_DAMAGE)
	player_flash_timer = DAMAGE_FLASH_SECONDS
	player_mesh.material_override = player_damage_material

	if player_hp <= 0:
		player_defeated = true
		hud.set_last_result("You were defeated. Prototype reset later.")
	else:
		hud.set_last_result("Enemy hit you: -%d HP. Player HP: %d/%d" % [ENEMY_TOUCH_DAMAGE, player_hp, PLAYER_MAX_HP])

	_update_status_lines()


func _update_interaction_prompt() -> void:
	var new_prompt := "Move | ATTACK enemy | INTERACT objects"

	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if player_defeated:
		new_prompt = "Player defeated. Exit/retry later."
	elif dist_to_exit < INTERACT_RANGE:
		new_prompt = "INTERACT: Exit Dungeon"
	elif not enemy_defeated and dist_to_enemy < ATTACK_RANGE:
		new_prompt = "ATTACK: Enemy HP %d/%d" % [enemy_hp, ENEMY_MAX_HP]
	elif not enemy_defeated and dist_to_enemy < ENEMY_AGGRO_RANGE:
		new_prompt = "Enemy sees you. Move or ATTACK."
	elif enemy_defeated and dist_to_enemy < INTERACT_RANGE:
		new_prompt = "Enemy defeated. Chest unlocked."
	elif dist_to_chest < INTERACT_RANGE:
		if chest_opened:
			new_prompt = "Chest opened"
		elif enemy_defeated:
			new_prompt = "INTERACT: Open unlocked chest"
		else:
			new_prompt = "Chest locked: defeat enemy"

	if new_prompt != last_interaction_prompt:
		last_interaction_prompt = new_prompt
		hud.set_prompt(new_prompt)


func _on_attack_pressed() -> void:
	if player_defeated:
		hud.set_last_result("You are defeated. Exit/retry later.")
		return
	if enemy_defeated:
		hud.set_last_result("Enemy already defeated. Open the chest.")
		return

	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	if dist_to_enemy > ATTACK_RANGE:
		hud.set_last_result("Too far to attack. Move closer to the red enemy.")
		return

	enemy_hp = max(0, enemy_hp - PLAYER_ATTACK_DAMAGE)
	hit_flash_timer = HIT_FLASH_SECONDS
	enemy_mesh.material_override = enemy_hit_material

	if enemy_hp <= 0:
		enemy_defeated = true
		enemy_placeholder.visible = false
		chest_mesh.material_override = chest_unlocked_material
		hud.set_last_result("Enemy defeated! Chest unlocked.")
	else:
		hud.set_last_result("Hit enemy: -%d HP. Enemy HP: %d/%d" % [PLAYER_ATTACK_DAMAGE, enemy_hp, ENEMY_MAX_HP])

	_update_status_lines()
	_update_interaction_prompt()


func _on_interact_pressed() -> void:
	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if dist_to_exit < INTERACT_RANGE:
		_exit_to_test_world()
		return

	if player_defeated:
		hud.set_last_result("Player defeated. Use exit portal to leave.")
		return

	if dist_to_enemy < INTERACT_RANGE:
		if enemy_defeated:
			hud.set_last_result("Enemy defeated. Chest is unlocked.")
		else:
			hud.set_last_result("Enemy blocks the reward. Use ATTACK.")
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
	hud.set_last_result("Chest opened: +1 placeholder reward.")
	_update_status_lines()
	_update_interaction_prompt()


func _update_status_lines() -> void:
	var player_status := "Player: Defeated" if player_defeated else "Player HP: %d/%d" % [player_hp, PLAYER_MAX_HP]
	var enemy_status := "Enemy: Defeated" if enemy_defeated else "Enemy HP: %d/%d" % [enemy_hp, ENEMY_MAX_HP]
	var chest_status := "Chest: Opened" if chest_opened else ("Chest: Unlocked" if enemy_defeated else "Chest: Locked")
	hud.set_inventory_summary(PackedStringArray([
		player_status,
		enemy_status,
		chest_status,
		"Red = Enemy | Gold/Green = Chest | Cyan = Exit",
	]))


func _exit_to_test_world() -> void:
	print("[DungeonShell] Exiting dungeon...")
	get_tree().change_scene_to_file("res://scenes/test_world/test_world.tscn")
