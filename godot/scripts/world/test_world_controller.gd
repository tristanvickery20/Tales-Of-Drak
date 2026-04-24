extends Node3D

## Test World Controller — Phase 1 emergency-stable vertical slice.
##
## This controller intentionally does NOT depend on DebugHud compiling.
## It directly drives the visible fallback HUD scene nodes:
## - FallbackHpLabel
## - FallbackXpLabel
## - FallbackInvButton
##
## That keeps HP / XP / INV working while the richer HUD is stabilized.

const GATHER_INTERACT_RANGE := 3.0
const DUNGEON_INTERACT_RANGE := 3.0

@onready var player = $Player
@onready var gather_node_marker = $GatherNode
@onready var build_spawn_marker = $BuildSpawnMarker
@onready var placed_build_parent = $PlacedBuildPieces
@onready var dungeon_portal = $DungeonPortal
@onready var hud = $DebugHud

var fallback_hp_label = null
var fallback_xp_label = null
var fallback_inv_button = null
var title_label = null
var inventory_label = null
var prompt_label = null
var result_label = null
var fallback_panel = null
var fallback_panel_label = null
var fallback_panel_mode = "backpack"


func _ready() -> void:
	GameState.ensure_runtime_state()
	_cache_hud_nodes()
	_connect_visible_inv_button()
	_connect_debug_hud_if_available()
	GameState.runtime_state_changed.connect(_update_hud_inventory)
	_update_hud_inventory()
	_set_result("Entered world as %s." % GameState.get_character_summary())
	print("[TestWorld] Emergency-stable runtime initialized.")


func _process(_delta: float) -> void:
	_update_prompt()

	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()
	if Input.is_action_just_pressed("craft"):
		_on_craft_pressed()
	if Input.is_action_just_pressed("place_build"):
		_on_place_pressed()


func _cache_hud_nodes() -> void:
	fallback_hp_label = hud.get_node_or_null("FallbackHpLabel")
	fallback_xp_label = hud.get_node_or_null("FallbackXpLabel")
	fallback_inv_button = hud.get_node_or_null("FallbackInvButton")
	title_label = hud.get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
	inventory_label = hud.get_node_or_null("MarginContainer/VBoxContainer/InventoryLabel")
	prompt_label = hud.get_node_or_null("MarginContainer/VBoxContainer/PromptLabel")
	result_label = hud.get_node_or_null("MarginContainer/VBoxContainer/ResultLabel")


func _connect_visible_inv_button() -> void:
	if fallback_inv_button == null:
		return
	if not fallback_inv_button.pressed.is_connected(_toggle_fallback_inventory):
		fallback_inv_button.pressed.connect(_toggle_fallback_inventory)


func _connect_debug_hud_if_available() -> void:
	if hud == null:
		return
	if hud.has_signal("craft_recipe_requested"):
		hud.connect("craft_recipe_requested", Callable(self, "_on_hud_craft_recipe_requested"))
	if hud.has_signal("use_item_requested"):
		hud.connect("use_item_requested", Callable(self, "_on_hud_use_item_requested"))
	if hud.has_signal("equip_item_requested"):
		hud.connect("equip_item_requested", Callable(self, "_on_hud_equip_item_requested"))


func _update_prompt() -> void:
	var prompt = "Move | USE near portal/node | Craft | Place | INV"
	if player.global_position.distance_to(dungeon_portal.global_position) <= DUNGEON_INTERACT_RANGE:
		prompt += " | USE: Enter Dungeon"
	elif player.global_position.distance_to(gather_node_marker.global_position) <= GATHER_INTERACT_RANGE:
		prompt += " | USE: Gather"
	_set_prompt(prompt)


func _on_interact_pressed() -> void:
	if player.global_position.distance_to(dungeon_portal.global_position) <= DUNGEON_INTERACT_RANGE:
		_enter_dungeon()
		return

	if player.global_position.distance_to(gather_node_marker.global_position) > GATHER_INTERACT_RANGE:
		_set_result("Too far from gathering node.")
		return

	GameState.add_item("weathered_timber", 3)
	_set_result("Gathered Weathered Timber x3")
	_update_hud_inventory()


func _enter_dungeon() -> void:
	print("[TestWorld] Entering dungeon...")
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_shell.tscn")


func _on_craft_pressed() -> void:
	var quick_recipe = {
		"id": "craft_torch_kit",
		"name": "Torch Kit",
		"requirements": {"weathered_timber": 1},
		"output_item_id": "torch_kit",
		"output_quantity": 2,
	}
	_craft_recipe_from_dictionary(quick_recipe)


func _on_hud_craft_recipe_requested(recipe) -> void:
	_craft_recipe_from_dictionary(recipe)


func _craft_recipe_from_dictionary(recipe) -> void:
	var recipe_name = str(recipe.get("name", "recipe"))
	var requirements = recipe.get("requirements", {})
	var output_item_id = str(recipe.get("output_item_id", recipe.get("id", "crafted_item")))
	var output_quantity = int(recipe.get("output_quantity", 1))
	if output_quantity <= 0:
		output_quantity = 1

	for item_id in requirements.keys():
		var required = int(requirements[item_id])
		var owned = GameState.get_item_count(str(item_id))
		if owned < required:
			_set_result("Missing %s: %d / %d" % [GameState.get_item_name(str(item_id)), owned, required])
			_update_hud_inventory()
			return

	for item_id in requirements.keys():
		GameState.remove_item(str(item_id), int(requirements[item_id]))
	GameState.add_item(output_item_id, output_quantity)
	_set_result("Crafted %s x%d" % [recipe_name, output_quantity])
	_update_hud_inventory()


func _on_hud_use_item_requested(item_id) -> void:
	var result = GameState.use_item(str(item_id))
	_set_result(str(result.get("message", "Used item.")))
	_update_hud_inventory()


func _on_hud_equip_item_requested(item_id) -> void:
	if GameState.equip_item(str(item_id)):
		_set_result("Equipped %s." % GameState.get_item_name(str(item_id)))
	else:
		_set_result("Cannot equip %s." % GameState.get_item_name(str(item_id)))
	_update_hud_inventory()


func _on_place_pressed() -> void:
	if GameState.get_item_count("weathered_timber") < 8:
		_set_result("Build failed: need Weathered Timber x8")
		return
	GameState.remove_item("weathered_timber", 8)
	_spawn_build_placeholder(build_spawn_marker.global_position)
	_set_result("Placed Timber Foundation")
	_update_hud_inventory()


func _spawn_build_placeholder(world_pos: Vector3) -> void:
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.scale = Vector3(2.0, 0.4, 2.0)
	mesh.global_position = world_pos + Vector3(0.2 * placed_build_parent.get_child_count(), 0.2, 0.2 * placed_build_parent.get_child_count())
	placed_build_parent.add_child(mesh)


func _update_hud_inventory() -> void:
	GameState.ensure_runtime_state()
	_set_hp_xp_labels()
	_set_title("Character: %s" % GameState.get_character_summary())
	_set_inventory_label("Inventory: %d item type(s)" % GameState.get_inventory_lines().size())

	if hud != null and hud.has_method("set_player_health"):
		hud.call("set_player_health", GameState.current_hp, GameState.max_hp)
	if hud != null and hud.has_method("set_progression"):
		hud.call("set_progression", GameState.level, GameState.xp, GameState.xp_to_next)
	if hud != null and hud.has_method("set_inventory_tabs"):
		hud.call("set_inventory_tabs", GameState.get_inventory_lines(), PackedStringArray(["Crafting uses persistent inventory."]), GameState.get_character_view_lines())

	_refresh_fallback_panel()


func _set_hp_xp_labels() -> void:
	if fallback_hp_label != null:
		fallback_hp_label.text = "HP %d / %d" % [GameState.current_hp, GameState.max_hp]
	if fallback_xp_label != null:
		fallback_xp_label.text = "LV %d  XP %d/%d" % [GameState.level, GameState.xp, GameState.xp_to_next]


func _set_title(text: String) -> void:
	if title_label != null:
		title_label.text = text


func _set_inventory_label(text: String) -> void:
	if inventory_label != null:
		inventory_label.text = text


func _set_prompt(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = "Prompt: %s" % text
	if hud != null and hud.has_method("set_prompt"):
		hud.call("set_prompt", text)


func _set_result(text: String) -> void:
	if result_label != null:
		result_label.text = "Last: %s" % text
	if hud != null and hud.has_method("set_last_result"):
		hud.call("set_last_result", text)


func _toggle_fallback_inventory() -> void:
	if fallback_panel == null:
		_build_fallback_panel()
	fallback_panel.visible = not fallback_panel.visible
	_refresh_fallback_panel()


func _build_fallback_panel() -> void:
	fallback_panel = PanelContainer.new()
	fallback_panel.name = "ControllerFallbackInventoryPanel"
	fallback_panel.visible = false
	fallback_panel.anchor_left = 0.08
	fallback_panel.anchor_top = 0.12
	fallback_panel.anchor_right = 0.92
	fallback_panel.anchor_bottom = 0.88
	hud.add_child(fallback_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	fallback_panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	buttons.add_child(_fallback_tab_button("Character", "character"))
	buttons.add_child(_fallback_tab_button("Backpack", "backpack"))
	buttons.add_child(_fallback_tab_button("Crafting", "crafting"))
	var close = Button.new()
	close.text = "Close"
	close.pressed.connect(_toggle_fallback_inventory)
	buttons.add_child(close)

	fallback_panel_label = Label.new()
	fallback_panel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_panel_label.add_theme_font_size_override("font_size", 16)
	box.add_child(fallback_panel_label)


func _fallback_tab_button(text: String, mode: String) -> Button:
	var button = Button.new()
	button.text = text
	button.pressed.connect(func():
		fallback_panel_mode = mode
		_refresh_fallback_panel()
	)
	return button


func _refresh_fallback_panel() -> void:
	if fallback_panel_label == null:
		return
	if fallback_panel_mode == "character":
		fallback_panel_label.text = "CHARACTER\n\n" + "\n".join(GameState.get_character_view_lines())
		return
	if fallback_panel_mode == "crafting":
		fallback_panel_label.text = _fallback_crafting_text()
		return
	fallback_panel_label.text = "BACKPACK\n\n" + "\n".join(GameState.get_inventory_lines())


func _fallback_crafting_text() -> String:
	return "CRAFTING\n\nPress C to quick craft Torch Kit.\n\nCurrent backpack:\n" + "\n".join(GameState.get_inventory_lines())
