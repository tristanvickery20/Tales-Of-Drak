extends Node3D

## Stage 10 Placeholder Combat Loop
##
## Keeps combat intentionally tiny:
## - approach enemy
## - tap ATTACK / press F
## - enemy HP drops
## - enemy is defeated and hidden
## - chest unlocks
## - chest gives placeholder reward

const INTERACT_RANGE := 2.8
const ATTACK_RANGE := 3.0
const ENEMY_MAX_HP := 30
const PLAYER_ATTACK_DAMAGE := 10

@onready var player: ThirdPersonController = $Player
@onready var enemy_placeholder: Node3D = $EnemyPlaceholder
@onready var chest_placeholder: Node3D = $ChestPlaceholder
@onready var exit_portal: Node3D = $ExitPortal
@onready var hud: DebugHud = $DebugHud

var last_interaction_prompt: String = ""
var chest_opened: bool = false
var enemy_hp: int = ENEMY_MAX_HP
var enemy_defeated: bool = false


func _ready() -> void:
	print("[DungeonShell] Dungeon initialized.")
	hud.set_character_summary("Dungeon Shell", "Stage 10")
	_update_status_lines()
	hud.set_prompt("Move | ATTACK enemy | INTERACT objects")
	hud.set_last_result("Dungeon loaded. Defeat the red enemy to unlock the chest.")


func _process(_delta: float) -> void:
	_update_interaction_prompt()

	if Input.is_action_just_pressed("attack"):
		_on_attack_pressed()
	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()


func _update_interaction_prompt() -> void:
	var new_prompt := "Move | ATTACK enemy | INTERACT objects"

	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if dist_to_exit < INTERACT_RANGE:
		new_prompt = "INTERACT: Exit Dungeon"
	elif not enemy_defeated and dist_to_enemy < ATTACK_RANGE:
		new_prompt = "ATTACK: Enemy HP %d/%d" % [enemy_hp, ENEMY_MAX_HP]
	elif enemy_defeated and dist_to_enemy < INTERACT_RANGE:
		new_prompt = "Enemy defeated"
	elif dist_to_chest < INTERACT_RANGE:
		new_prompt = "INTERACT: Chest %s" % ["Unlocked" if enemy_defeated else "Locked"]

	if new_prompt != last_interaction_prompt:
		last_interaction_prompt = new_prompt
		hud.set_prompt(new_prompt)


func _on_attack_pressed() -> void:
	if enemy_defeated:
		hud.set_last_result("Enemy already defeated.")
		return

	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	if dist_to_enemy > ATTACK_RANGE:
		hud.set_last_result("Too far to attack.")
		return

	enemy_hp = max(0, enemy_hp - PLAYER_ATTACK_DAMAGE)
	if enemy_hp <= 0:
		enemy_defeated = true
		enemy_placeholder.visible = false
		hud.set_last_result("Enemy defeated. Chest unlocked.")
	else:
		hud.set_last_result("Hit enemy for %d. HP: %d/%d" % [PLAYER_ATTACK_DAMAGE, enemy_hp, ENEMY_MAX_HP])

	_update_status_lines()
	_update_interaction_prompt()


func _on_interact_pressed() -> void:
	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if dist_to_exit < INTERACT_RANGE:
		_exit_to_test_world()
		return

	if dist_to_enemy < INTERACT_RANGE:
		if enemy_defeated:
			hud.set_last_result("Enemy defeated. Chest is unlocked.")
		else:
			hud.set_last_result("Enemy placeholder. Use ATTACK.")
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
		hud.set_last_result("Chest already opened.")
		return

	chest_opened = true
	hud.set_last_result("Chest opened: +1 placeholder reward.")
	_update_status_lines()


func _update_status_lines() -> void:
	var enemy_status := "Enemy: Defeated" if enemy_defeated else "Enemy HP: %d/%d" % [enemy_hp, ENEMY_MAX_HP]
	var chest_status := "Chest: Opened" if chest_opened else ("Chest: Unlocked" if enemy_defeated else "Chest: Locked")
	hud.set_inventory_summary(PackedStringArray([
		enemy_status,
		chest_status,
		"Cyan arch = Exit Dungeon",
	]))


func _exit_to_test_world() -> void:
	print("[DungeonShell] Exiting dungeon...")
	get_tree().change_scene_to_file("res://scenes/test_world/test_world.tscn")
