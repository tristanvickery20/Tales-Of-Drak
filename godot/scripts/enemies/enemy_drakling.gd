extends CharacterBody3D
class_name EnemyDrakling

## Simple Drakling enemy — idle, patrol, chase, attack, die.
## Drops Drak Essence on death.

@export var patrol_speed: float = 1.5
@export var chase_speed: float = 3.0
@export var aggro_range: float = 8.0
@export var attack_range: float = 2.0
@export var max_health: int = 15
@export var damage: int = 5
@export var attack_cooldown: float = 1.5
@export var patrol_points: PackedVector3Array = PackedVector3Array()

var current_health: int = max_health
var is_dead: bool = false
var damage_timer: float = 0.0
var patrol_index: int = 0
var patrol_wait_timer: float = 0.0
var player_ref: Node3D = null

@onready var original_material: Material = $EnemyMesh.material_override


func _ready() -> void:
	current_health = max_health
	if patrol_points.is_empty():
		patrol_points = [global_position]


func _process(delta: float) -> void:
	if is_dead:
		return

	damage_timer = max(0.0, damage_timer - delta)

	if player_ref == null:
		_find_player()

	if player_ref != null:
		_update_ai(delta)


func _find_player() -> void:
	var tree = get_tree()
	if tree != null:
		var players = tree.get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as Node3D


func _update_ai(delta: float) -> void:
	var dist = global_position.distance_to(player_ref.global_position)

	if dist <= aggro_range:
		if dist <= attack_range:
			_attack_player()
		else:
			_chase_player(delta)
	else:
		_patrol(delta)


func _chase_player(delta: float) -> void:
	var dir = (player_ref.global_position - global_position).normalized()
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	move_and_slide()


func _patrol(delta: float) -> void:
	if patrol_points.size() <= 1:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if patrol_wait_timer > 0.0:
		patrol_wait_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var target = patrol_points[patrol_index]
	var dir = (target - global_position)
	dir.y = 0.0

	if dir.length() < 0.5:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		patrol_wait_timer = 2.0
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		dir = dir.normalized()
		velocity.x = dir.x * patrol_speed
		velocity.z = dir.z * patrol_speed

	move_and_slide()


func _attack_player() -> void:
	if damage_timer > 0.0:
		return
	damage_timer = attack_cooldown
	if player_ref != null and player_ref.has_method("take_damage"):
		player_ref.take_damage(damage)


func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_health = max(0, current_health - amount)
	_flash_hit()
	if current_health <= 0:
		die()


func _flash_hit() -> void:
	var hit_material = StandardMaterial3D.new()
	hit_material.albedo_color = Color(1, 1, 1, 1)
	hit_material.emission_enabled = true
	hit_material.emission = Color(1, 0.3, 0.2, 1)
	hit_material.emission_energy_multiplier = 1.5
	$EnemyMesh.material_override = hit_material
	get_tree().create_timer(0.15).timeout.connect(_restore_material)


func _restore_material() -> void:
	if is_dead:
		return
	$EnemyMesh.material_override = original_material


func die() -> void:
	is_dead = true
	$CollisionShape3D.disabled = true
	visible = false

	if GameState != null:
		GameState.add_resource("drak_essence", 1)
		GameState.mark_objective_complete("drakling_defeated")
