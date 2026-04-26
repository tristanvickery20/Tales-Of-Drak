extends CharacterBody3D
class_name ThirdPersonController

## Third-person controller with mouse camera, WASD movement, jump, sprint,
## attack, health, and death/respawn.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 14.0
@export var mouse_sensitivity: float = 0.002
@export var max_health: int = 20
@export var attack_range: float = 2.5
@export var attack_damage: int = 8
@export var attack_cooldown: float = 0.6

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var spawn_point: Vector3 = global_position

var current_health: int = max_health
var is_dead: bool = false
var attack_timer: float = 0.0


func _ready() -> void:
	spawn_point = global_position
	current_health = max_health
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion:
		_handle_mouse(event)


func _physics_process(delta: float) -> void:
	if is_dead:
		move_and_slide()
		return

	attack_timer = max(0.0, attack_timer - delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var move_dir := _movement_input()
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var forward := _camera_forward()
	var right := _camera_right()
	var world_dir := forward * move_dir.z + right * move_dir.x
	world_dir = world_dir.normalized()

	velocity.x = world_dir.x * current_speed
	velocity.z = world_dir.z * current_speed

	move_and_slide()


func _movement_input() -> Vector3:
	var x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var z := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var v := Vector3(x, 0.0, z)
	if v.length() > 1.0:
		v = v.normalized()
	return v


func _handle_mouse(event: InputEventMouseMotion) -> void:
	# Horizontal rotation: rotate the player body (Y axis)
	rotate_y(-event.relative.x * mouse_sensitivity)
	# Vertical rotation: rotate the spring arm (X axis), clamped
	spring_arm.rotation.x = clamp(
		spring_arm.rotation.x - event.relative.y * mouse_sensitivity,
		deg_to_rad(-80.0),
		deg_to_rad(60.0)
	)


func _camera_forward() -> Vector3:
	var f := global_transform.basis.z
	f.y = 0.0
	return -f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _camera_right() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0.0
	return r.normalized() if r.length() > 0.01 else Vector3.RIGHT


func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_health = max(0, current_health - amount)
	if current_health <= 0:
		die()


func die() -> void:
	is_dead = true
	# Respawn after a brief delay
	get_tree().create_timer(2.0).timeout.connect(_respawn)


func _respawn() -> void:
	is_dead = false
	current_health = max_health
	global_position = spawn_point
	velocity = Vector3.ZERO


func get_health_percent() -> float:
	return float(current_health) / float(max_health)
