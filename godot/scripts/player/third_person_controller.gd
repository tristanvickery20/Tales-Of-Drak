extends CharacterBody3D
class_name ThirdPersonController

## Third-person movement controller for the Stage 8 test world.
##
## Reads movement / jump / sprint via the Godot InputMap actions:
##   move_forward, move_back, move_left, move_right, jump, sprint
##
## Both desktop keyboard input (mapped in project.godot) and the Stage 8.6
## mobile touch controls (which call Input.action_press / action_release)
## drive these same actions, so the controller does not need to know which
## input device is active.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 14.0

@onready var spring_arm: SpringArm3D = $SpringArm3D


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _jump_pressed() and is_on_floor():
		velocity.y = jump_velocity

	var move_dir := _movement_input()
	var current_speed := sprint_speed if _sprint_pressed() else walk_speed
	velocity.x = move_dir.x * current_speed
	velocity.z = move_dir.z * current_speed

	move_and_slide()


func _movement_input() -> Vector3:
	var x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var z := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var v := Vector3(x, 0.0, z)
	if v.length() > 1.0:
		v = v.normalized()
	return v


func _jump_pressed() -> bool:
	return Input.is_action_pressed("jump")


func _sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint")
