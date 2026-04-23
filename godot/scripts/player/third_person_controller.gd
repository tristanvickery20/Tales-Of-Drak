extends CharacterBody3D
class_name ThirdPersonController

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
	var x := 0.0
	var z := 0.0

	if Input.is_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_key_pressed(KEY_D):
		x += 1.0
	if Input.is_key_pressed(KEY_W):
		z -= 1.0
	if Input.is_key_pressed(KEY_S):
		z += 1.0

	var v := Vector3(x, 0.0, z)
	return v.normalized()


func _jump_pressed() -> bool:
	return Input.is_key_pressed(KEY_SPACE)


func _sprint_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)
