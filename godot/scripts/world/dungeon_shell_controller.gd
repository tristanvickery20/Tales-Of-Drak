extends Node3D

## Stage 13 Data-Driven Combat Abilities
##
## Same playable loop as Stage 12, but core ability values now come from
## design/abilities.json when available:
## - basic_attack
## - heavy_attack
## - guard
## - warden_bulwark
##
## Safe fallbacks are kept so local/web preview stays playable even if design
## loading fails.

const INTERACT_RANGE := 2.8
const ATTACK_RANGE := 3.0
const ENEMY_MAX_HP := 30
const PLAYER_MAX_HP := 50
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

const ABILITY_BASIC_ATTACK := "basic_attack"
const ABILITY_HEAVY_ATTACK := "heavy_attack"
const ABILITY_GUARD := "guard"
const ABILITY_WARDEN_BULWARK := "warden_bulwark"

const FALLBACK_ABILITIES := {
	ABILITY_BASIC_ATTACK: {
		"display_name": "Basic Attack",
		"damage": 10,
		"cooldown_seconds": 0.0,
		"duration_seconds": 0.0,
		"guard_damage_reduction": 0.0,
	},
	ABILITY_HEAVY_ATTACK: {
		"display_name": "Heavy Attack",
		"damage": 18,
		"cooldown_seconds": 3.0,
		"duration_seconds": 0.0,
		"guard_damage_reduction": 0.0,
	},
	ABILITY_GUARD: {
		"display_name": "Guard",
		"damage": 0,
		"cooldown_seconds": 0.0,
		"duration_seconds": 2.0,
		"guard_damage_reduction": 0.5,
	},
	ABILITY_WARDEN_BULWARK: {
		"display_name": "Warden Bulwark",
		"damage": 8,
		"cooldown_seconds": 6.0,
		"duration_seconds": 1.5,
		"guard_damage_reduction": 0.5,
	},
}

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
var player_hp: int = PLAYER_MAX_HP
var player_defeated: bool = false
var hit_flash_timer: float = 0.0
var player_flash_timer: float = 0.0
var enemy_damage_cooldown_timer: float = 0.0
var heavy_attack_cooldown_timer: float = 0.0
var warden_ability_cooldown_timer: float = 0.0
var guard_timer: float = 0.0
var guard_damage_reduction: float = 0.5
var enemy_state: EnemyState = EnemyState.IDLE
var enemy_spawn_position: Vector3 = Vector3.ZERO
var last_enemy_hit_message: String = ""
var last_ability_message: String = "Abilities ready: Attack / Heavy / Guard / Warden"
var ability_records: Dictionary = {}
var ability_source_label: String = "fallback"

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
	enemy_spawn_position = enemy_placeholder.global_position
	_load_ability_data()
	_setup_feedback_materials()
	hud.set_character_summary("Dungeon Shell", "Stage 13")
	_update_status_lines()
	hud.set_prompt("ATTACK | HEAVY | GUARD | WARDEN")
	hud.set_last_result("Stage 13: abilities loaded from %s." % ability_source_label)


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


func _load_ability_data() -> void:
	ability_records.clear()
	for ability_id in FALLBACK_ABILITIES.keys():
		ability_records[ability_id] = FALLBACK_ABILITIES[ability_id].duplicate(true)
	ability_source_label = "fallback"

	var raw_json := _get_abilities_json_text()
	if raw_json.is_empty():
		print("[DungeonShell] abilities.json not found; using fallback ability values.")
		return

	var parsed: Variant = JSON.parse_string(raw_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[DungeonShell] abilities.json invalid; using fallback ability values.")
		return

	var root: Dictionary = parsed
	if root.get("record_type", "") != "ability" or typeof(root.get("records", [])) != TYPE_ARRAY:
		push_warning("[DungeonShell] abilities.json has wrong contract; using fallback ability values.")
		return

	for entry in root["records"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = entry
		var ability_id := str(record.get("id", ""))
		if ability_id.is_empty():
			continue
		ability_records[ability_id] = record.duplicate(true)

	ability_source_label = "design/abilities.json"
	print("[DungeonShell] Loaded %d ability records from %s" % [ability_records.size(), ability_source_label])


func _get_abilities_json_text() -> String:
	if DesignDataEmbedded.FILES.has("abilities.json"):
		return str(DesignDataEmbedded.FILES["abilities.json"])

	for path in ["res://design/abilities.json", "res://../design/abilities.json"]:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var text := file.get_as_text()
				file.close()
				return text
	return ""


func _ability_record(ability_id: String) -> Dictionary:
	return ability_records.get(ability_id, FALLBACK_ABILITIES.get(ability_id, {}))


func _ability_name(ability_id: String) -> String:
	return str(_ability_record(ability_id).get("display_name", ability_id))


func _ability_damage(ability_id: String) -> int:
	return int(round(float(_ability_record(ability_id).get("damage", 0))))


func _ability_cooldown(ability_id: String) -> float:
	return float(_ability_record(ability_id).get("cooldown_seconds", 0.0))


func _ability_duration(ability_id: String) -> float:
	return float(_ability_record(ability_id).get("duration_seconds", 0.0))


func _ability_guard_reduction(ability_id: String) -> float:
	return clamp(float(_ability_record(ability_id).get("guard_damage_reduction", 0.0)), 0.0, 1.0)


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
	if warden_ability_cooldown_timer > 0.0:
		warden_ability_cooldown_timer = max(0.0, warden_ability_cooldown_timer - delta)


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
	_update_status_lines()


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
		var remaining := snapped(enemy_damage_cooldown_timer, 0.1)
		last_enemy_hit_message = "Enemy attack cooling down: %.1fs" % remaining
		return

	enemy_damage_cooldown_timer = ENEMY_DAMAGE_COOLDOWN
	var damage := ENEMY_TOUCH_DAMAGE
	if guard_timer > 0.0:
		damage = max(1, int(round(float(ENEMY_TOUCH_DAMAGE) * guard_damage_reduction)))
		last_enemy_hit_message = "Guard reduced enemy hit: -%d HP" % damage
	else:
		last_enemy_hit_message = "Enemy hit you: -%d HP" % damage

	player_hp = max(0, player_hp - damage)
	player_flash_timer = DAMAGE_FLASH_SECONDS
	player_mesh.material_override = player_damage_material if guard_timer <= 0.0 else player_guard_material

	if player_hp <= 0:
		player_defeated = true
		hud.set_last_result("You were defeated. Use the cyan exit to leave/reset.")
	else:
		hud.set_last_result("%s. Player HP: %d/%d" % [last_enemy_hit_message, player_hp, PLAYER_MAX_HP])

	_update_status_lines()


func _update_interaction_prompt() -> void:
	var new_prompt := "ATTACK | HEAVY | GUARD | WARDEN"

	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if player_defeated:
		new_prompt = "Defeated. INTERACT with cyan exit to reset."
	elif dist_to_exit < INTERACT_RANGE:
		new_prompt = "INTERACT: Exit Dungeon"
	elif not enemy_defeated and dist_to_enemy < ATTACK_RANGE:
		new_prompt = "ATTACK/HEAVY/WARDEN: Enemy HP %d/%d" % [enemy_hp, ENEMY_MAX_HP]
	elif not enemy_defeated and enemy_state == EnemyState.RETURNING:
		new_prompt = "Enemy returning to spawn"
	elif not enemy_defeated and dist_to_enemy < ENEMY_AGGRO_RANGE:
		new_prompt = "Enemy sees you. Use ATTACK or GUARD."
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
	_try_damage_enemy(_ability_damage(ABILITY_BASIC_ATTACK), _ability_name(ABILITY_BASIC_ATTACK))


func _on_heavy_attack_pressed() -> void:
	if heavy_attack_cooldown_timer > 0.0:
		hud.set_last_result("%s cooldown: %.1fs" % [_ability_name(ABILITY_HEAVY_ATTACK), snapped(heavy_attack_cooldown_timer, 0.1)])
		return
	if _try_damage_enemy(_ability_damage(ABILITY_HEAVY_ATTACK), _ability_name(ABILITY_HEAVY_ATTACK)):
		heavy_attack_cooldown_timer = _ability_cooldown(ABILITY_HEAVY_ATTACK)


func _on_guard_pressed() -> void:
	if player_defeated:
		hud.set_last_result("You are defeated. Use cyan exit to leave/reset.")
		return
	guard_timer = _ability_duration(ABILITY_GUARD)
	guard_damage_reduction = _ability_guard_reduction(ABILITY_GUARD)
	player_mesh.material_override = player_guard_material
	last_ability_message = "%s active: incoming damage reduced." % _ability_name(ABILITY_GUARD)
	hud.set_last_result(last_ability_message)
	_update_status_lines()


func _on_class_ability_pressed() -> void:
	if warden_ability_cooldown_timer > 0.0:
		hud.set_last_result("%s cooldown: %.1fs" % [_ability_name(ABILITY_WARDEN_BULWARK), snapped(warden_ability_cooldown_timer, 0.1)])
		return
	if player_defeated:
		hud.set_last_result("You are defeated. Use cyan exit to leave/reset.")
		return
	guard_timer = max(guard_timer, _ability_duration(ABILITY_WARDEN_BULWARK))
	guard_damage_reduction = _ability_guard_reduction(ABILITY_WARDEN_BULWARK)
	player_mesh.material_override = player_guard_material
	warden_ability_cooldown_timer = _ability_cooldown(ABILITY_WARDEN_BULWARK)
	last_ability_message = "%s: guard up + enemy takes %d." % [_ability_name(ABILITY_WARDEN_BULWARK), _ability_damage(ABILITY_WARDEN_BULWARK)]
	_try_damage_enemy(_ability_damage(ABILITY_WARDEN_BULWARK), _ability_name(ABILITY_WARDEN_BULWARK))
	_update_status_lines()


func _try_damage_enemy(damage: int, source_label: String) -> bool:
	if player_defeated:
		hud.set_last_result("You are defeated. Use cyan exit to leave/reset.")
		return false
	if enemy_defeated:
		hud.set_last_result("Enemy already defeated. Open the chest.")
		return false

	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	if dist_to_enemy > ATTACK_RANGE:
		hud.set_last_result("Too far. Move closer to use %s." % source_label)
		return false

	enemy_hp = max(0, enemy_hp - damage)
	_set_enemy_state(EnemyState.CHASING)
	hit_flash_timer = HIT_FLASH_SECONDS
	enemy_mesh.material_override = enemy_hit_material

	if enemy_hp <= 0:
		enemy_defeated = true
		_set_enemy_state(EnemyState.DEFEATED)
		enemy_placeholder.visible = false
		chest_mesh.material_override = chest_unlocked_material
		hud.set_last_result("%s defeated enemy! Chest unlocked." % source_label)
	else:
		hud.set_last_result("%s: -%d HP. Enemy HP: %d/%d" % [source_label, damage, enemy_hp, ENEMY_MAX_HP])

	_update_status_lines()
	_update_interaction_prompt()
	return true


func _on_interact_pressed() -> void:
	var dist_to_exit := player.global_position.distance_to(exit_portal.global_position)
	var dist_to_enemy := player.global_position.distance_to(enemy_placeholder.global_position)
	var dist_to_chest := player.global_position.distance_to(chest_placeholder.global_position)

	if dist_to_exit < INTERACT_RANGE:
		_exit_to_test_world()
		return

	if player_defeated:
		hud.set_last_result("Player defeated. Use cyan exit to leave/reset.")
		return

	if dist_to_enemy < INTERACT_RANGE:
		if enemy_defeated:
			hud.set_last_result("Enemy defeated. Chest is unlocked.")
		else:
			hud.set_last_result("Enemy blocks the reward. Use ATTACK/HEAVY/WARDEN.")
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
	var player_status := "Player: Defeated" if player_defeated else "Player HP: %d/%d%s" % [player_hp, PLAYER_MAX_HP, " (Guard)" if guard_timer > 0.0 else ""]
	var enemy_status := "Enemy: Defeated" if enemy_defeated else "Enemy HP: %d/%d (%s)" % [enemy_hp, ENEMY_MAX_HP, _enemy_state_label()]
	var chest_status := "Chest: Opened" if chest_opened else ("Chest: Unlocked" if enemy_defeated else "Chest: Locked")
	var ability_status := "Heavy: %s | Warden: %s | Guard: %s" % [_cooldown_label(heavy_attack_cooldown_timer), _cooldown_label(warden_ability_cooldown_timer), _cooldown_label(guard_timer)]
	var enemy_status_line := last_enemy_hit_message if last_enemy_hit_message != "" else "Ability source: %s" % ability_source_label
	hud.set_inventory_summary(PackedStringArray([
		player_status,
		enemy_status,
		chest_status,
		ability_status,
		enemy_status_line,
	]))


func _cooldown_label(timer: float) -> String:
	return "Ready" if timer <= 0.0 else "%.1fs" % snapped(timer, 0.1)


func _enemy_state_label() -> String:
	match enemy_state:
		EnemyState.IDLE:
			return "Idle"
		EnemyState.CHASING:
			return "Chasing"
		EnemyState.RETURNING:
			return "Returning"
		EnemyState.DEFEATED:
			return "Defeated"
	return "Unknown"


func _exit_to_test_world() -> void:
	print("[DungeonShell] Exiting dungeon...")
	get_tree().change_scene_to_file("res://scenes/test_world/test_world.tscn")
