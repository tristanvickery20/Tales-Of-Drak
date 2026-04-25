extends Node3D

## Dungeon Shell Controller — stable Phase 1 dungeon loop.
## Uses the GameState autoload directly so damage, loot, XP, and equipment all
## mutate the same runtime state the HUD reads.

const INTERACT_RANGE = 3.0
const ATTACK_RANGE = 3.2
const ENEMY_MAX_HP = 30
const ENEMY_AGGRO_RANGE = 8.0
const ENEMY_STOP_RANGE = 2.35
const ENEMY_MOVE_SPEED = 1.25
const ENEMY_TOUCH_DAMAGE = 5
const ENEMY_DAMAGE_COOLDOWN = 1.35
const ENEMY_XP_REWARD = 80
const BASIC_DAMAGE = 8
const HEAVY_DAMAGE = 15
const CLASS_DAMAGE = 7
const HEAVY_COOLDOWN = 3.0
const CLASS_COOLDOWN = 6.0
const GUARD_SECONDS = 2.0
const GUARD_DAMAGE_MULTIPLIER = 0.5
const FLASH_DURATION = 0.25
const REWARD_ITEM_ID = "rusty_sword"
const REWARD_COIN_ID = "ancient_coin"

@onready var player = get_node_or_null("Player")
@onready var player_mesh = get_node_or_null("Player/BodyMesh")
@onready var enemy_node = get_node_or_null("EnemyPlaceholder")
@onready var enemy_mesh = get_node_or_null("EnemyPlaceholder/EnemyMesh")
@onready var chest_node = get_node_or_null("ChestPlaceholder")
@onready var chest_mesh = get_node_or_null("ChestPlaceholder/ChestMesh")
@onready var exit_portal = get_node_or_null("ExitPortal")
@onready var hud = get_node_or_null("DebugHud")

var enemy_hp = ENEMY_MAX_HP
var enemy_defeated = false
var chest_opened = false
var player_defeated = false
var enemy_damage_timer = 0.0
var heavy_timer = 0.0
var class_timer = 0.0
var guard_timer = 0.0
var enemy_flash_timer = 0.0
var player_flash_timer = 0.0
var enemy_hp_label = null
var last_prompt = ""

var enemy_mat_default = null
var enemy_mat_hit = null
var chest_mat_locked = null
var chest_mat_open = null
var player_mat_default = null
var player_mat_hit = null
var player_mat_guard = null

func _ready():
	if GameState != null:
		GameState.ensure_runtime_state()
	enemy_hp = ENEMY_MAX_HP
	enemy_defeated = false
	chest_opened = false
	player_defeated = GameState != null and GameState.current_hp <= 0
	_setup_materials()
	_build_enemy_hp_label()
	_connect_hud_signals()
	_update_hud()
	_update_enemy_hp_label()
	_hud_prompt("ATK | HVY | GRD | CLS | USE")
	_hud_result("Dungeon entered as %s." % GameState.get_character_summary())
	print("[DungeonShell] GameState-backed dungeon initialized.")

func _process(delta):
	_tick_timers(delta)
	_update_enemy_ai(delta)
	_update_prompt()
	if Input.is_action_just_pressed("attack"):
		_attack_enemy(BASIC_DAMAGE + GameState.get_weapon_damage_bonus(), "Basic Attack")
	if Input.is_action_just_pressed("heavy_attack"):
		_heavy_attack()
	if Input.is_action_just_pressed("guard"):
		_guard()
	if Input.is_action_just_pressed("class_ability"):
		_class_ability()
	if Input.is_action_just_pressed("interact"):
		_interact()

func _connect_hud_signals():
	if hud == null:
		return
	if hud.has_signal("use_item_requested"):
		hud.connect("use_item_requested", Callable(self, "_on_hud_use_item_requested"))
	if hud.has_signal("equip_item_requested"):
		hud.connect("equip_item_requested", Callable(self, "_on_hud_equip_item_requested"))
	if hud.has_signal("craft_recipe_requested"):
		hud.connect("craft_recipe_requested", Callable(self, "_on_hud_craft_recipe_requested"))

func _setup_materials():
	enemy_mat_default = _mat(Color(0.9, 0.1, 0.12, 1), Color(0.4, 0.0, 0.0, 1), 0.6)
	enemy_mat_hit = _mat(Color(1.0, 1.0, 1.0, 1), Color(1.0, 0.35, 0.2, 1), 1.8)
	chest_mat_locked = _mat(Color(0.95, 0.62, 0.08, 1), Color(0.25, 0.1, 0.0, 1), 0.35)
	chest_mat_open = _mat(Color(0.55, 0.55, 0.55, 1), Color(0.1, 0.1, 0.1, 1), 0.2)
	player_mat_default = _mat(Color(1, 1, 1, 1), Color(0, 0, 0, 1), 0.0)
	player_mat_hit = _mat(Color(1, 0.2, 0.2, 1), Color(1, 0, 0, 1), 1.2)
	player_mat_guard = _mat(Color(0.25, 0.65, 1, 1), Color(0, 0.45, 1, 1), 1.2)
	if enemy_mesh != null:
		enemy_mesh.material_override = enemy_mat_default
	if chest_mesh != null:
		chest_mesh.material_override = chest_mat_locked
	if player_mesh != null:
		player_mesh.material_override = player_mat_default

func _mat(albedo, emission, energy):
	var m = StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m

func _build_enemy_hp_label():
	if enemy_node == null:
		return
	enemy_hp_label = Label3D.new()
	enemy_hp_label.name = "EnemyHealthLabel"
	enemy_hp_label.position = Vector3(0, 1.45, 0)
	enemy_hp_label.font_size = 16
	enemy_hp_label.pixel_size = 0.002
	enemy_hp_label.modulate = Color(1, 0.06, 0.06, 1)
	enemy_hp_label.outline_modulate = Color(0, 0, 0, 1)
	enemy_hp_label.outline_size = 6
	enemy_hp_label.fixed_size = false
	enemy_hp_label.no_depth_test = true
	enemy_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	enemy_node.add_child(enemy_hp_label)

func _tick_timers(delta):
	enemy_damage_timer = max(0.0, enemy_damage_timer - delta)
	heavy_timer = max(0.0, heavy_timer - delta)
	class_timer = max(0.0, class_timer - delta)
	guard_timer = max(0.0, guard_timer - delta)
	enemy_flash_timer = max(0.0, enemy_flash_timer - delta)
	player_flash_timer = max(0.0, player_flash_timer - delta)
	if enemy_flash_timer <= 0.0 and enemy_mesh != null and not enemy_defeated:
		enemy_mesh.material_override = enemy_mat_default
	if player_flash_timer <= 0.0 and player_mesh != null and not player_defeated and guard_timer <= 0.0:
		player_mesh.material_override = player_mat_default

func _update_enemy_ai(delta):
	if enemy_defeated or player_defeated or player == null or enemy_node == null:
		return
	var distance = _flat_distance(enemy_node.global_position, player.global_position)
	if distance <= ENEMY_AGGRO_RANGE:
		if distance > ENEMY_STOP_RANGE:
			_move_enemy_toward(player.global_position, delta)
		else:
			_enemy_touch_damage()

func _flat_distance(a, b):
	var d = b - a
	d.y = 0
	return d.length()

func _move_enemy_toward(target, delta):
	var to_target = target - enemy_node.global_position
	to_target.y = 0
	if to_target.length() <= 0.01:
		return
	enemy_node.global_position += to_target.normalized() * ENEMY_MOVE_SPEED * delta

func _enemy_touch_damage():
	if enemy_damage_timer > 0.0:
		return
	enemy_damage_timer = ENEMY_DAMAGE_COOLDOWN
	var damage = ENEMY_TOUCH_DAMAGE
	if guard_timer > 0.0:
		damage = max(1, int(round(float(damage) * GUARD_DAMAGE_MULTIPLIER)))
	GameState.damage_player(damage, "enemy")
	if player_mesh != null:
		player_mesh.material_override = player_mat_guard if guard_timer > 0.0 else player_mat_hit
		player_flash_timer = FLASH_DURATION
	player_defeated = GameState.current_hp <= 0
	if player_defeated:
		_hud_result("You were defeated. Use the exit portal to leave.")
	else:
		_hud_result("Enemy hit you: -%d HP. %d/%d HP." % [damage, GameState.current_hp, GameState.max_hp])
	_update_hud()

func _update_prompt():
	var prompt = "ATK | HVY | GRD | CLS | USE"
	if _near(exit_portal, INTERACT_RANGE):
		prompt = "USE: Exit Dungeon"
	elif not enemy_defeated and _near(enemy_node, ATTACK_RANGE):
		prompt = "ATK/HVY/CLS: %d/%d" % [enemy_hp, ENEMY_MAX_HP]
	elif enemy_defeated and not chest_opened and _near(chest_node, INTERACT_RANGE):
		prompt = "USE: Open Chest"
	elif not enemy_defeated and _near(chest_node, INTERACT_RANGE):
		prompt = "Chest locked. Defeat enemy."
	if prompt != last_prompt:
		last_prompt = prompt
		_hud_prompt(prompt)

func _attack_enemy(damage, label):
	if player_defeated:
		_hud_result("You are defeated. Use exit portal.")
		return false
	if enemy_defeated:
		_hud_result("Enemy defeated. Open the chest.")
		return false
	if not _near(enemy_node, ATTACK_RANGE):
		_hud_result("Too far for %s." % label)
		return false
	enemy_hp = max(0, enemy_hp - int(damage))
	if enemy_mesh != null:
		enemy_mesh.material_override = enemy_mat_hit
		enemy_flash_timer = FLASH_DURATION
	_update_enemy_hp_label()
	if enemy_hp <= 0:
		_enemy_defeated(label)
	else:
		_hud_result("%s: -%d HP. Enemy %d/%d." % [label, int(damage), enemy_hp, ENEMY_MAX_HP])
	_update_hud()
	return true

func _heavy_attack():
	if heavy_timer > 0.0:
		_hud_result("Heavy cooldown: %.1fs" % heavy_timer)
		return
	if _attack_enemy(HEAVY_DAMAGE + GameState.get_weapon_damage_bonus(), "Heavy Attack"):
		heavy_timer = HEAVY_COOLDOWN

func _guard():
	guard_timer = GUARD_SECONDS
	if player_mesh != null:
		player_mesh.material_override = player_mat_guard
	_hud_result("Guard active: damage reduced.")

func _class_ability():
	if class_timer > 0.0:
		_hud_result("Class cooldown: %.1fs" % class_timer)
		return
	class_timer = CLASS_COOLDOWN
	guard_timer = max(guard_timer, 1.5)
	_attack_enemy(CLASS_DAMAGE + GameState.get_weapon_damage_bonus(), "Class Feature")

func _enemy_defeated(label):
	enemy_defeated = true
	if enemy_node != null:
		enemy_node.visible = false
	if enemy_hp_label != null:
		enemy_hp_label.visible = false
	if chest_mesh != null:
		chest_mesh.material_override = _mat(Color(0.15, 1.0, 0.35, 1), Color(0, 0.8, 0.2, 1), 1.0)
	var result = GameState.add_xp(ENEMY_XP_REWARD)
	_hud_result("%s defeated enemy! %s Chest unlocked." % [label, str(result.get("message", "+XP."))])
	_update_hud()

func _update_enemy_hp_label():
	if enemy_hp_label == null:
		return
	if enemy_defeated:
		enemy_hp_label.visible = false
		return
	enemy_hp_label.visible = true
	enemy_hp_label.text = "%d/%d" % [enemy_hp, ENEMY_MAX_HP]

func _interact():
	if _near(exit_portal, INTERACT_RANGE):
		_exit_to_world()
		return
	if _near(chest_node, INTERACT_RANGE):
		_open_chest()
		return
	_hud_result("No dungeon object nearby.")

func _open_chest():
	if not enemy_defeated:
		_hud_result("Chest locked. Defeat the enemy first.")
		return
	if chest_opened:
		_hud_result("Chest already opened.")
		return
	chest_opened = true
	if chest_mesh != null:
		chest_mesh.material_override = chest_mat_open
	GameState.add_item(REWARD_ITEM_ID, 1)
	GameState.add_item(REWARD_COIN_ID, 5)
	_hud_result("Chest opened: Rusty Sword x1, Ancient Coin x5.")
	_update_hud()

func _on_hud_use_item_requested(item_id):
	var result = GameState.use_item(str(item_id))
	_hud_result(str(result.get("message", "Used item.")))
	_update_hud()

func _on_hud_equip_item_requested(item_id):
	var result = GameState.equip_item(str(item_id))
	_hud_result(str(result.get("message", "Equip result.")))
	_update_hud()

func _on_hud_craft_recipe_requested(recipe):
	var result = GameState.craft_recipe(recipe)
	_hud_result(str(result.get("message", "Craft result.")))
	_update_hud()

func _exit_to_world():
	_hud_result("Exiting dungeon...")
	get_tree().change_scene_to_file("res://scenes/test_world/test_world.tscn")

func _near(target, range):
	if player == null or target == null:
		return false
	return player.global_position.distance_to(target.global_position) <= float(range)

func _update_hud():
	if GameState == null:
		return
	_hud_call("set_player_health", [GameState.current_hp, GameState.max_hp])
	_hud_call("set_progression", [GameState.level, GameState.xp, GameState.xp_to_next])
	_hud_call("set_character_summary", [GameState.character_name, "%s %s" % [GameState.species_name, GameState.class_name]])
	_hud_call("set_inventory_tabs", [GameState.get_inventory_lines(), PackedStringArray(["Dungeon crafting uses backpack materials."],), GameState.get_character_view_lines()])

func _hud_call(method_name, args):
	if hud != null and hud.has_method(method_name):
		hud.callv(method_name, args)

func _hud_prompt(text):
	if hud != null and hud.has_method("set_prompt"):
		hud.set_prompt(text)

func _hud_result(text):
	if hud != null and hud.has_method("set_last_result"):
		hud.set_last_result(text)
