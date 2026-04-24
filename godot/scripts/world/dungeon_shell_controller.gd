extends Node3D

## Stage 9 Dungeon Shell Controller
## Manages the graybox dungeon scene and handles player interactions.
##
## Features:
## - Player spawning
## - Exit portal interaction back to test world
## - Enemy placeholder interaction
## - Chest placeholder interaction
## - Proximity-based interaction hints
##
## Touch controls reuse the existing mobile_controls.gd overlay
## attached to this scene for iPhone compatibility.

const INTERACT_RANGE := 2.8

@onready var player: ThirdPersonController = $Player
@onready var enemy_placeholder: Node3D = $EnemyPlaceholder
@onready var chest_placeholder: Node3D = $ChestPlaceholder
@onready var exit_portal: Node3D = $ExitPortal
@onready var hud: DebugHud = $DebugHud

var last_interaction_prompt: String = ""
var chest_opened: bool = false


func _ready() -> void:
	print("[DungeonShell] Dungeon initialized.")
	hud.set_character_summary("Dungeon Shell", "Graybox")
	hud.set_inventory_summary(PackedStringArray([
		"Red block = Enemy Placeholder",
		"Gold block = Chest Placeholder",
		"Cyan arch = Exit Dungeon"
	]))
	hud.set_prompt("Move: joystick/WASD | Interact near objects")
	hud.set_last_result("Dungeon loaded. Find the chest or exit.")


func _process(_delta: float) -> void:
	_update_interaction_prompt()

	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()


func _update_interaction_prompt() -> void:
	var new_prompt := "Move: joystick/WASD | Interact near objects"

	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if dist_to_exit < INTERACT_RANGE:
		new_prompt = "Interact: Exit Dungeon"
	elif dist_to_enemy < INTERACT_RANGE:
		new_prompt = "Interact: Enemy Placeholder"
	elif dist_to_chest < INTERACT_RANGE:
		new_prompt = "Interact: Chest Placeholder"

	if new_prompt != last_interaction_prompt:
		last_interaction_prompt = new_prompt
		hud.set_prompt(new_prompt)


func _on_interact_pressed() -> void:
	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if dist_to_exit < INTERACT_RANGE:
		_exit_to_test_world()
		return

	if dist_to_enemy < INTERACT_RANGE:
		hud.set_last_result("Enemy placeholder — combat later.")
		return

	if dist_to_chest < INTERACT_RANGE:
		if chest_opened:
			hud.set_last_result("Chest already opened.")
		else:
			chest_opened = true
			hud.set_last_result("Chest opened: reward placeholder.")
		return

	hud.set_last_result("No dungeon object nearby.")


func _exit_to_test_world() -> void:
	print("[DungeonShell] Exiting dungeon...")
	get_tree().change_scene_to_file("res://scenes/test_world/test_world.tscn")
